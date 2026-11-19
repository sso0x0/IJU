# 담당: 개발자1. 아이디·이메일·비밀번호 가입 + 구글 로그인. 화면 연동 방법은 server/AUTH.md
import re
from datetime import datetime, timedelta, timezone
from typing import Any

import httpx
from fastapi import APIRouter, Depends

from ..auth import AuthError, check_password, current_user, find_user, hash_password, make_token
from ..config import settings
from ..db import table
from ..schemas import (
    AuthUser,
    CheckEmailIn,
    CheckIdIn,
    LoginIn,
    MessageOut,
    ProfileUpdateIn,
    SessionOut,
    SignupIn,
    SocialLoginIn,
    SocialLoginOut,
    SocialSignupIn,
    TermsOut,
)
from ..terms import PRIVACY_TEXT, TERMS_TEXT, TERMS_VERSION

router = APIRouter(prefix="/auth", tags=["auth"])

KST = timezone(timedelta(hours=9))
LOGIN_ID = re.compile(r"[a-zA-Z0-9_]{4,20}")
NICKNAME = re.compile(r"[가-힣a-zA-Z0-9_]{2,20}")
EMAIL = re.compile(r"[^@\s]+@[^@\s]+\.[^@\s]+")
GOOGLE_TOKENINFO = "https://oauth2.googleapis.com/tokeninfo"
GOOGLE_ISSUERS = {"accounts.google.com", "https://accounts.google.com"}


def _now() -> str:
    return datetime.now(KST).isoformat()


def _user_out(row: dict[str, Any]) -> AuthUser:
    return AuthUser(
        id=str(row["id"]),
        login_id=row.get("login_id"),
        email=row.get("email"),
        nickname=row.get("nickname"),
        language=row.get("language"),
        residence_type=row.get("residence_type"),
        level=row.get("level") or 1,
        points=row.get("points") or 0,
        auth_provider=row.get("auth_provider") or "local",
    )


def _session(row: dict[str, Any]) -> SessionOut:
    return SessionOut(access_token=make_token(str(row["id"])), user=_user_out(row))


def _check_terms(terms_agreed: bool, privacy_agreed: bool, version: str) -> None:
    if not (terms_agreed and privacy_agreed):
        raise AuthError(400, "TERMS_REQUIRED", "이용약관과 개인정보 수집·이용에 모두 동의해 주세요.")
    if version != TERMS_VERSION:
        raise AuthError(409, "TERMS_CHANGED", "약관이 바뀌었어요. 다시 확인하고 동의해 주세요.")


def _check_login_id(login_id: str) -> None:
    if not LOGIN_ID.fullmatch(login_id):
        raise AuthError(422, "INVALID_ID", "아이디는 영문, 숫자, 밑줄 4~20자로 입력해 주세요.")
    if find_user("login_id", login_id.lower()):
        raise AuthError(409, "ID_TAKEN", "이미 사용 중인 아이디예요.")


def _check_email(email: str) -> None:
    if not EMAIL.fullmatch(email):
        raise AuthError(422, "INVALID_EMAIL", "이메일 형식이 올바르지 않아요.")
    if find_user("email", email.lower()):
        raise AuthError(409, "EMAIL_TAKEN", "이미 사용 중인 이메일이에요.")


def _check_nickname(nickname: str) -> None:
    if not NICKNAME.fullmatch(nickname):
        raise AuthError(422, "INVALID_NICKNAME", "닉네임은 한글, 영문, 숫자, 밑줄 2~20자로 입력해 주세요.")
    if find_user("nickname", nickname):
        raise AuthError(409, "NICKNAME_TAKEN", "이미 사용 중인 닉네임이에요.")


async def _verify_google(id_token: str) -> dict[str, Any]:
    """구글 ID 토큰을 구글 서버에 확인받습니다. 우리 앱(클라이언트 ID)에 발급된 토큰만 받습니다."""
    client_ids = {c.strip() for c in settings.google_client_ids.split(",") if c.strip()}
    if not client_ids:
        raise AuthError(503, "GOOGLE_NOT_CONFIGURED", "서버에 GOOGLE_CLIENT_IDS가 설정되지 않았어요.")
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            res = await client.get(GOOGLE_TOKENINFO, params={"id_token": id_token})
    except httpx.HTTPError:
        raise AuthError(502, "GOOGLE_UNREACHABLE", "구글 인증 서버에 연결하지 못했어요.")
    info = res.json() if res.status_code == 200 else {}
    if (
        info.get("aud") not in client_ids
        or info.get("iss") not in GOOGLE_ISSUERS
        or str(info.get("email_verified")).lower() != "true"
        or not info.get("sub")
    ):
        raise AuthError(401, "INVALID_GOOGLE_TOKEN", "구글 인증 정보가 올바르지 않아요. 다시 로그인해 주세요.")
    return info


@router.get("/terms", response_model=TermsOut)
def get_terms():
    return TermsOut(terms_version=TERMS_VERSION, terms_text=TERMS_TEXT, privacy_text=PRIVACY_TEXT)


@router.post("/check-id", response_model=MessageOut)
def check_id(body: CheckIdIn):
    _check_login_id(body.login_id.strip())
    return MessageOut(message="사용할 수 있는 아이디예요.")


@router.post("/check-email", response_model=MessageOut)
def check_email(body: CheckEmailIn):
    _check_email(body.email.strip())
    return MessageOut(message="사용할 수 있는 이메일이에요.")


@router.post("/signup", response_model=SessionOut)
def signup(body: SignupIn):
    login_id, email = body.login_id.strip(), body.email.strip()
    _check_terms(body.terms_agreed, body.privacy_agreed, body.terms_version)
    _check_login_id(login_id)
    _check_email(email)
    if len(body.password) < 8:
        raise AuthError(422, "WEAK_PASSWORD", "비밀번호는 8자 이상으로 입력해 주세요.")
    nickname = (body.nickname or login_id).strip()
    if body.nickname:
        _check_nickname(nickname)

    now = _now()
    row = table("users").insert(
        {
            "login_id": login_id.lower(),
            "email": email.lower(),
            "password_hash": hash_password(body.password),
            "auth_provider": "local",
            "nickname": nickname,
            "language": body.language,
            "residence_type": body.residence_type,
            "level": 1,
            "points": 0,
            "terms_version": body.terms_version,
            "terms_agreed_at": now,
            "privacy_agreed_at": now,
            "created_at": now,
        }
    )
    return _session(row)


@router.post("/login", response_model=SessionOut)
def login(body: LoginIn):
    user = find_user("login_id", body.login_id.strip().lower())
    # 아이디가 없는지 비밀번호가 틀린지 구분해서 알려 주지 않습니다 (아이디 추측 방지).
    if not user or not check_password(body.password, user.get("password_hash")):
        raise AuthError(401, "WRONG_CREDENTIALS", "아이디 또는 비밀번호가 올바르지 않아요.")
    return _session(user)


@router.post("/social", response_model=SocialLoginOut)
async def social_login(body: SocialLoginIn):
    """구글 로그인. 가입한 적이 있으면 바로 세션, 처음이면 signup_required=true (→ /auth/social/signup)."""
    info = await _verify_google(body.id_token)
    user = find_user("google_sub", info["sub"])
    if user:
        session = _session(user)
        return SocialLoginOut(access_token=session.access_token, user=session.user)
    return SocialLoginOut(signup_required=True, email=info.get("email"))


@router.post("/social/signup", response_model=SessionOut)
async def social_signup(body: SocialSignupIn):
    info = await _verify_google(body.id_token)
    if find_user("google_sub", info["sub"]):
        raise AuthError(409, "ALREADY_SIGNED_UP", "이미 가입한 구글 계정이에요. 로그인해 주세요.")
    _check_terms(body.terms_agreed, body.privacy_agreed, body.terms_version)
    name = body.name.strip()
    _check_nickname(name)
    email = (info.get("email") or "").lower()
    if email and find_user("email", email):
        raise AuthError(409, "EMAIL_TAKEN", "이 이메일로 이미 가입한 계정이 있어요. 아이디로 로그인해 주세요.")

    now = _now()
    row = table("users").insert(
        {
            "email": email or None,
            "google_sub": info["sub"],
            "auth_provider": "google",
            "nickname": name,
            "language": body.language,
            "residence_type": body.residence_type,
            "level": 1,
            "points": 0,
            "terms_version": body.terms_version,
            "terms_agreed_at": now,
            "privacy_agreed_at": now,
            "created_at": now,
        }
    )
    return _session(row)


@router.get("/me", response_model=AuthUser)
def me(user: dict = Depends(current_user)):
    return _user_out(user)


@router.patch("/me", response_model=AuthUser)
def update_me(body: ProfileUpdateIn, user: dict = Depends(current_user)):
    """온보딩에서 모국어·체류 유형·닉네임을 채웁니다."""
    changes = body.model_dump(exclude_none=True)
    if "nickname" in changes and changes["nickname"] != user.get("nickname"):
        _check_nickname(changes["nickname"])
    if changes:
        table("users").update_eq("id", user["id"], changes)
        user = {**user, **changes}
    return _user_out(user)
