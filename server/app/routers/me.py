# 담당: 개발자1 — 내 복습 목록 · 주문 지도 · 학습 기록. 전부 `Authorization: Bearer <토큰>`으로 사용자를 찾습니다.
from datetime import date, datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends

from ..auth import current_user
from ..db import table
from ..schemas import (
    OrderPlaceIn,
    OrderPlaceItem,
    OrderPlacesOut,
    ReviewIn,
    ReviewItem,
    ReviewsOut,
    UserStatsOut,
)

router = APIRouter(prefix="/me", tags=["me"])

KST = timezone(timedelta(hours=9))


def _now() -> str:
    return datetime.now(KST).isoformat()


def _day(value: Any) -> date | None:
    """DB 시각(문자열) → 한국 날짜"""
    try:
        t = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    if t.tzinfo is None:
        t = t.replace(tzinfo=KST)
    return t.astimezone(KST).date()


def _upsert(name: str, match: dict[str, Any], values: dict[str, Any]) -> dict[str, Any]:
    """[match]가 모두 같은 줄이 있으면 고치고, 없으면 새로 넣습니다."""
    rows = table(name).select_eq("user_id", match["user_id"])
    for r in rows:
        if all(str(r.get(k)) == str(v) for k, v in match.items()):
            updated = table(name).update_eq("id", r["id"], values)
            return updated[0] if updated else {**r, **values}
    return table(name).insert({**match, **values})


# ---------- 복습 목록 ----------
def _review(row: dict[str, Any]) -> ReviewItem:
    return ReviewItem(
        id=str(row["id"]),
        sentence=row["sentence"],
        meaning=row.get("meaning") or "",
        order=row.get("order_data"),
        score=row.get("score"),
        cleared=row.get("cleared") or 0,
        next_review_at=str(row.get("next_review_at") or row.get("created_at") or _now()),
    )


@router.get("/reviews", response_model=ReviewsOut)
def list_reviews(user: dict = Depends(current_user)):
    rows = table("review_cards").select_eq("user_id", user["id"])
    rows.sort(key=lambda r: str(r.get("created_at") or ""), reverse=True)  # 최근에 넣은 문장이 위
    return ReviewsOut(reviews=[_review(r) for r in rows])


@router.post("/reviews", response_model=ReviewItem)
def save_review(body: ReviewIn, user: dict = Depends(current_user)):
    """같은 문장이 있으면 진행 상태만 고칩니다 (user_id + sentence가 유니크)."""
    now = _now()
    values = {
        "meaning": body.meaning,
        "score": body.score,
        "cleared": body.cleared,
        "next_review_at": body.next_review_at or now,
        "updated_at": now,
    }
    if body.order is not None:
        values["order_data"] = body.order
    row = _upsert("review_cards", {"user_id": user["id"], "sentence": body.sentence}, values)
    return _review(row)


# ---------- 주문 지도 ----------
def _place(row: dict[str, Any]) -> OrderPlaceItem:
    return OrderPlaceItem(
        id=str(row["id"]),
        store_name=row["store_name"],
        sentence=row["sentence"],
        meaning=row.get("meaning"),
        address=row.get("address"),
        lat=row.get("lat"),
        lng=row.get("lng"),
        ordered_at=str(row.get("ordered_at") or _now()),
    )


@router.get("/order-places", response_model=OrderPlacesOut)
def list_order_places(user: dict = Depends(current_user)):
    rows = table("order_places").select_eq("user_id", user["id"])
    rows.sort(key=lambda r: str(r.get("ordered_at") or ""), reverse=True)
    return OrderPlacesOut(places=[_place(r) for r in rows])


@router.post("/order-places", response_model=OrderPlaceItem)
def save_order_place(body: OrderPlaceIn, user: dict = Depends(current_user)):
    """같은 가게·같은 문장이면 주문 날짜와 위치만 새로 바꿉니다."""
    values = {
        "meaning": body.meaning,
        "address": body.address,
        "lat": body.lat,
        "lng": body.lng,
        "ordered_at": _now(),
    }
    match = {"user_id": user["id"], "store_name": body.store_name, "sentence": body.sentence}
    return _place(_upsert("order_places", match, values))


# ---------- 학습 기록 ----------
def _streak(days: set[date], today: date) -> int:
    """오늘부터 거꾸로 이어진 날 수. 오늘 아직 안 했으면 어제부터 셉니다."""
    day = today if today in days else today - timedelta(days=1)
    count = 0
    while day in days:
        count += 1
        day -= timedelta(days=1)
    return count


@router.get("/stats", response_model=UserStatsOut)
def stats(user: dict = Depends(current_user)):
    uid = user["id"]
    reviews = table("review_cards").select_eq("user_id", uid)
    missions = table("user_missions").select_eq("user_id", uid)

    # 연습 기록·영수증 인증·복습·주문 지도 중 하나라도 한 날을 학습한 날로 봅니다.
    stamps = [r.get("created_at") for r in table("attempts").select_eq("user_id", uid)]
    stamps += [r.get("created_at") for r in table("receipts").select_eq("user_id", uid)]
    stamps += [r.get("updated_at") for r in reviews] + [r.get("created_at") for r in reviews]
    stamps += [r.get("ordered_at") for r in table("order_places").select_eq("user_id", uid)]
    days = {d for d in map(_day, stamps) if d}

    return UserStatsOut(
        level=user.get("level") or 1,
        points=user.get("points") or 0,
        completed_missions=sum(1 for m in missions if m.get("status") == "completed"),
        review_count=len(reviews),
        streak_days=_streak(days, datetime.now(KST).date()),
    )
