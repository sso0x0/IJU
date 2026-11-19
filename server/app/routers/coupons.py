# 담당: 개발자3 — 내 쿠폰 조회 · 사용 처리
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter

from ..db import table
from ..schemas import CouponItem, CouponsOut, CouponUseIn, CouponUseOut
from .receipts import store_code

router = APIRouter(tags=["coupons"])

KST = timezone(timedelta(hours=9))
_STATUS_ORDER = {"active": 0, "used": 1, "expired": 2}

MESSAGES = {
    "ok": "쿠폰을 사용했어요.",
    "not_found": "쿠폰을 찾을 수 없어요.",
    "not_owner": "내 쿠폰이 아니에요.",
    "already_used": "이미 사용한 쿠폰이에요.",
    "expired": "기간이 지난 쿠폰이에요.",
    "wrong_code": "사장님 확인 코드가 맞지 않아요.",
}


def _expired(row: dict[str, Any]) -> bool:
    try:
        t = datetime.fromisoformat(str(row.get("expires_at")).replace("Z", "+00:00"))
    except ValueError:
        return False
    if t.tzinfo is None:
        t = t.replace(tzinfo=KST)
    return t < datetime.now(KST)


def _item(row: dict[str, Any], stores: dict[str, dict[str, Any]]) -> CouponItem:
    status = row.get("status") or "active"
    if status == "active" and _expired(row):
        status = "expired"
    store = stores.get(row.get("store_id") or "")
    return CouponItem(
        id=str(row["id"]),
        store_id=row.get("store_id"),
        store_name=store["name"] if store else None,
        value=row["value"],
        status=status,
        expires_at=str(row.get("expires_at") or ""),
    )


def _stores() -> dict[str, dict[str, Any]]:
    return {s["id"]: s for s in table("stores").all()}


@router.get("/coupons", response_model=CouponsOut)
def list_coupons(user_id: str):
    stores = _stores()
    items = [_item(r, stores) for r in table("coupons").select_eq("user_id", user_id)]
    # 쓸 수 있는 것 → 사용함 → 만료, 같은 상태면 만료 임박 순
    items.sort(key=lambda c: (_STATUS_ORDER[c.status], c.expires_at))
    return CouponsOut(coupons=items)


@router.post("/coupons/{coupon_id}/use", response_model=CouponUseOut)
def use_coupon(coupon_id: str, body: CouponUseIn):
    def fail(reason: str, item: CouponItem | None = None) -> CouponUseOut:
        return CouponUseOut(used=False, reason=reason, message=MESSAGES[reason], coupon=item)

    rows = table("coupons").select_eq("id", coupon_id)
    if not rows:
        return fail("not_found")
    row = rows[0]
    stores = _stores()
    item = _item(row, stores)

    if row.get("user_id") != body.user_id:
        return fail("not_owner")
    if item.status == "used":
        return fail("already_used", item)
    if item.status == "expired":
        return fail("expired", item)

    # 쿠폰을 받은 가게의 사장님 코드여야 사용 처리
    store = stores.get(row.get("store_id") or "")
    if store is None or body.code.strip() != store_code(store):
        return fail("wrong_code", item)

    table("coupons").update_eq("id", coupon_id, {"status": "used"})
    return CouponUseOut(
        used=True, reason="ok", message=MESSAGES["ok"],
        coupon=item.model_copy(update={"status": "used"}),
    )
