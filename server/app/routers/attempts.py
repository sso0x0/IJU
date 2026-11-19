# 담당: 개발자3 — 실전 주문 4단계 기록
from fastapi import APIRouter

from ..db import table
from ..schemas import AttemptIn, AttemptOut
from .missions import get_user_mission, save_user_mission

router = APIRouter(tags=["attempts"])


@router.post("/attempts", response_model=AttemptOut)
def save_attempt(body: AttemptIn):
    table("attempts").insert(body.model_dump())

    current = get_user_mission(body.user_id, body.mission_id)
    best = max(body.step, (current or {}).get("best_step", 0))
    save_user_mission(body.user_id, body.mission_id, best_step=best)

    return AttemptOut(saved=True, next_step=body.step + 1 if body.step < 3 else None)