# 담당: 개발자3 — 지금은 시드 데이터를 그대로 돌려줍니다. 수준별 추천은 여기서 구현하세요.
from fastapi import APIRouter

from ..db import table
from ..schemas import Mission, MissionsOut

router = APIRouter(tags=["missions"])


@router.get("/missions", response_model=MissionsOut)
def list_missions(user_id: str):
    # TODO(개발자3): user_id로 사용자 level을 조회해 맞는 미션만 고르기
    rows = table("missions").all()
    return MissionsOut(
        missions=[
            Mission(
                id=r["id"],
                title=r["title"],
                store_type=r["store_type"],
                target_pattern=r["target_pattern"],
                reward=r["reward_points"],
            )
            for r in rows
        ]
    )
