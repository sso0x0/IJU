"""로그인 공용 도구 (개발자1): 비밀번호 해시, 로그인 토큰(JWT HS256), 현재 사용자 꺼내기.

새 라이브러리 없이 표준 라이브러리만 씁니다. 다른 라우터에서 로그인한 사용자만 받으려면
`user: dict = Depends(current_user)`를 붙이면 됩니다.
"""

import base64
import hashlib
import hmac
import json
import secrets
import time
from typing import Any

from fastapi import Header

from .config import settings
from .db import table

PBKDF2_ROUNDS = 200_000

# .env에 AUTH_SECRET이 없으면 서버를 켤 때마다 새로 만듭니다 (재시작하면 다시 로그인해야 함).
_SECRET = (settings.auth_secret or secrets.token_urlsafe(32)).encode()


class AuthError(Exception):
    """앱이 그대로 보여 줄 수 있는 오류. main.py에서 {"code", "message"} JSON으로 바꿉니다."""

    def __init__(self, status: int, code: str, message: str):
        self.status = status
        self.code = code
        self.message = message


# ---------- 비밀번호 ----------
def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), PBKDF2_ROUNDS)
    return f"pbkdf2_sha256${PBKDF2_ROUNDS}${salt}${digest.hex()}"


def check_password(password: str, stored: str | None) -> bool:
    try:
        _, rounds, salt, expected = (stored or "").split("$")
    except ValueError:
        return False
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), int(rounds))
    return hmac.compare_digest(digest.hex(), expected)


# ---------- 토큰 ----------
def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _unb64(text: str) -> bytes:
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def make_token(user_id: str) -> str:
    header = _b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    now = int(time.time())
    payload = _b64(json.dumps({"sub": user_id, "iat": now, "exp": now + settings.token_days * 86400}).encode())
    sig = _b64(hmac.new(_SECRET, f"{header}.{payload}".encode(), hashlib.sha256).digest())
    return f"{header}.{payload}.{sig}"


def read_token(token: str) -> str | None:
    """올바르고 만료 전이면 사용자 id, 아니면 None."""
    try:
        header, payload, sig = token.split(".")
        expected = _b64(hmac.new(_SECRET, f"{header}.{payload}".encode(), hashlib.sha256).digest())
        if not hmac.compare_digest(sig, expected):
            return None
        data = json.loads(_unb64(payload))
    except (ValueError, json.JSONDecodeError):
        return None
    if data.get("exp", 0) < time.time():
        return None
    return data.get("sub")


def find_user(column: str, value: Any) -> dict[str, Any] | None:
    rows = table("users").select_eq(column, value)
    return rows[0] if rows else None


def current_user(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    """`Authorization: Bearer <access_token>` 헤더로 로그인한 사용자를 찾습니다."""
    if not authorization or not authorization.lower().startswith("bearer "):
        raise AuthError(401, "LOGIN_REQUIRED", "로그인이 필요해요.")
    user_id = read_token(authorization[7:].strip())
    user = find_user("id", user_id) if user_id else None
    if not user:
        raise AuthError(401, "INVALID_TOKEN", "로그인이 만료됐어요. 다시 로그인해 주세요.")
    return user
