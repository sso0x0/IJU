# 담당: 개발자3 (영수증 인식은 개발자1의 vision.scan_receipt 사용)
# PRD 3.9 부정 사용 방지 (+ ⓪ 실제 영수증 사진인지): ① 같은 이미지 ② 같은 영수증 ③ 등록 가게 ④ 발행 후 7일 ⑤ 하루 3회 ⑥ 신뢰도 낮으면 상인 확인 코드
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, File, Form, UploadFile

from ..config import settings
from ..db import table
from ..schemas import Coupon, MerchantConfirmIn, ReceiptOut
from ..vision import scan_receipt
from .missions import get_user, save_user_mission

router = APIRouter(tags=["receipts"])

KST = timezone(timedelta(hours=9))
MIN_CONFIDENCE = 0.5   # 이보다 낮으면 자동 승인 대신 상인 확인 코드
# 발행 후 며칠 안의 영수증만 인정 (PRD 3.9는 24시간 → 팀 결정으로 7일).
# 인터넷 영수증 사진으로 테스트할 때만 .env에 RECEIPT_VALID_DAYS=365 처럼 늘리세요. 시연·실서비스는 7일.
VALID_DAYS = settings.receipt_valid_days
DAILY_LIMIT = 3        # 사용자별 하루 인증 횟수
COUPON_VALUE = 2000    # 원. 미션별로 바꾸려면 missions에 컬럼 추가
COUPON_DAYS = 30

MESSAGES = {
    "duplicate_image": "이미 올린 영수증 사진이에요.",
    "duplicate_receipt": "이미 인증한 영수증이에요.",
    "unknown_store": "이주 참여 가게의 영수증이 아니에요.",
    "expired": f"발행 후 {VALID_DAYS}일이 지난 영수증이에요.",
    "daily_limit": f"오늘은 영수증 인증을 {DAILY_LIMIT}번까지 할 수 있어요.",
    "not_receipt": "영수증 사진이 아니에요. 가게에서 받은 영수증을 찍어 주세요.",
    "low_confidence": "영수증을 잘 읽지 못했어요. 다시 찍거나 사장님께 확인 코드를 받아 주세요.",
    "wrong_code": "확인 코드가 맞지 않아요.",
}


def _fail(reason: str) -> ReceiptOut:
    return ReceiptOut(verified=False, reason=reason, message=MESSAGES[reason])


def _digits(value: str | None) -> str:
    return "".join(ch for ch in (value or "") if ch.isdigit())


def _now() -> datetime:
    return datetime.now(KST)


def _parse_time(value: Any) -> datetime | None:
    if not value:
        return None
    try:
        t = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    return t if t.tzinfo else t.replace(tzinfo=KST)  # 영수증 시각은 한국 시간


def _find_store(business_no: str | None) -> dict[str, Any] | None:
    target = _digits(business_no)
    if not target:
        return None
    for s in table("stores").all():  # 사업자번호 하이픈 유무가 달라도 비교되게 숫자만
        if _digits(s.get("business_no")) == target:
            return s
    return None


def _verified_today(user_id: str) -> int:
    today = _now().date()
    count = 0
    for r in table("receipts").select_eq("user_id", user_id):
        t = _parse_time(r.get("created_at"))
        if r.get("verified") and t and t.astimezone(KST).date() == today:
            count += 1
    return count


def store_code(store: dict[str, Any]) -> str:
    """사장님 확인 코드. 쿠폰 사용 처리·상인 화면에서도 씁니다."""
    # stores.confirm_code 컬럼이 있으면 그 값, 없으면 사업자번호 뒤 4자리
    return str(store.get("confirm_code") or _digits(store.get("business_no"))[-4:])


def _reward(user_id: str, mission_id: str, store: dict[str, Any] | None) -> Coupon:
    """쿠폰 발급 + 미션 완료 + 포인트 적립"""
    expires = (_now() + timedelta(days=COUPON_DAYS)).isoformat()
    row = table("coupons").insert(
        {
            "user_id": user_id,
            "store_id": store["id"] if store else None,
            "value": COUPON_VALUE,
            "status": "active",
            "expires_at": expires,
        }
    )
    save_user_mission(user_id, mission_id, status="completed", completed_at=_now().isoformat())

    user = get_user(user_id)
    missions = table("missions").select_eq("id", mission_id)
    if user and missions:
        points = (user.get("points") or 0) + (missions[0].get("reward_points") or 0)
        table("users").update_eq("id", user_id, {"points": points})

    return Coupon(id=str(row["id"]), value=row["value"], expires_at=str(row["expires_at"]))


@router.post("/receipts", response_model=ReceiptOut)
async def verify_receipt(
    user_id: str = Form(...),
    mission_id: str = Form(...),
    image: UploadFile = File(...),
):
    raw = await image.read()
    image_hash = hashlib.sha256(raw).hexdigest()

    # ① 같은 이미지 재업로드 (AI 호출 전에 걸러서 시간·비용 절약)
    if table("receipts").select_eq("image_hash", image_hash):
        return _fail("duplicate_image")
    # ⑤ 하루 인증 횟수
    if _verified_today(user_id) >= DAILY_LIMIT:
        return _fail("daily_limit")

    # 원본 이미지는 저장하지 않음 (카드번호 노출 방지). scan_receipt도 카드번호를 출력하지 않음
    scan = await scan_receipt(raw)

    # ⓪ 손글씨·화면 촬영 등 실제 영수증이 아니면 거절 (AI가 판단 못 하면 None → 아래 검사로 넘어감)
    if scan.is_receipt is False:
        return _fail("not_receipt")

    # ⑥ 인식 실패·신뢰도 낮음 → 앱에서 재촬영 1회 후 상인 확인 코드 화면으로
    issued = _parse_time(scan.issued_at)
    if scan.confidence < MIN_CONFIDENCE or not scan.business_no or not scan.receipt_no or not issued:
        return _fail("low_confidence")

    # ③ 등록 가게
    store = _find_store(scan.business_no)
    if not store:
        return _fail("unknown_store")
    # ④ 발행 후 7일
    if _now() - issued > timedelta(days=VALID_DAYS):
        return _fail("expired")
    # ② 같은 영수증 재사용 (사업자번호 + 영수증 번호 + 발행 일시)
    for r in table("receipts").select_eq("receipt_no", scan.receipt_no):
        same_store = _digits(r.get("business_no")) == _digits(scan.business_no)
        if same_store and _parse_time(r.get("issued_at")) == issued:
            return _fail("duplicate_receipt")

    try:
        table("receipts").insert(
            {
                "user_id": user_id,
                "store_id": store["id"],
                "image_hash": image_hash,
                "business_no": store.get("business_no"),
                "receipt_no": scan.receipt_no,
                "amount": scan.amount,
                "issued_at": issued.isoformat(),
                "verified": True,
                "created_at": _now().isoformat(),
            }
        )
    except Exception:  # Supabase 유니크 제약에 걸린 경우 (동시에 두 번 올림 등)
        return _fail("duplicate_receipt")

    coupon = _reward(user_id, mission_id, store)
    return ReceiptOut(
        verified=True, reason="ok", message="인증 완료! 쿠폰이 발급됐어요.",
        store_name=store["name"], amount=scan.amount, coupon=coupon,
    )


@router.post("/receipts/merchant-confirm", response_model=ReceiptOut)
def merchant_confirm(body: MerchantConfirmIn):
    """영수증 인식이 안 될 때: 사장님이 알려준 확인 코드로 인증 (PRD 3.3 예외 흐름)"""
    if _verified_today(body.user_id) >= DAILY_LIMIT:
        return _fail("daily_limit")

    code = body.code.strip()
    store = next((s for s in table("stores").all() if code and store_code(s) == code), None)
    if not store:
        return _fail("wrong_code")

    table("receipts").insert(
        {
            "user_id": body.user_id,
            "store_id": store["id"],
            # image_hash는 NOT NULL·유니크라 코드 인증 건마다 고유값을 넣음
            "image_hash": f"merchant:{body.user_id}:{body.mission_id}:{_now().timestamp()}",
            "business_no": store.get("business_no"),
            "verified": True,
            "created_at": _now().isoformat(),
        }
    )
    coupon = _reward(body.user_id, body.mission_id, store)
    return ReceiptOut(
        verified=True, reason="ok", message="사장님 확인 완료! 쿠폰이 발급됐어요.",
        store_name=store["name"], coupon=coupon,
    )