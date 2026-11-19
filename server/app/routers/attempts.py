# 담당: 개발자3
from fastapi import APIRouter

from ..db import table
from ..schemas import AttemptIn, AttemptOut

router = APIRouter(tags=["attempts"])


@router.post("/attempts", response_model=AttemptOut)
def save_attempt(body: AttemptIn):
    # TODO(개발자3): user_missions.best_step 갱신
    table("attempts").insert(body.model_dump())
    return AttemptOut(saved=True, next_step=body.step + 1 if body.step < 4 else None)
