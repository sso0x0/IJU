# 담당: 개발자3 — 사용자 수준에 맞는 미션 + 진행 상태
from typing import Any

from fastapi import APIRouter

from ..db import table
from ..schemas import Mission, MissionsOut

router = APIRouter(tags=["missions"])

_STATUS_ORDER = {"in_progress": 0, "new": 1, "completed": 2}


def get_user(user_id: str) -> dict[str, Any] | None:
    rows = table("users").select_eq("id", user_id)
    return rows[0] if rows else None


def get_user_mission(user_id: str, mission_id: str) -> dict[str, Any] | None:
    for r in table("user_missions").select_eq("user_id", user_id):
        if r["mission_id"] == mission_id:
            return r
    return None


def save_user_mission(user_id: str, mission_id: str, **changes: Any) -> None:
    """user_missions 한 줄을 만들거나 고칩니다. attempts·receipts에서 같이 씁니다."""
    row = get_user_mission(user_id, mission_id)
    if row:
        table("user_missions").update_eq("id", row["id"], changes)
    else:
        table("user_missions").insert(
            {"user_id": user_id, "mission_id": mission_id,
             "status": "in_progress", "best_step": 0, **changes}
        )


@router.get("/missions", response_model=MissionsOut)
def list_missions(user_id: str):
    user = get_user(user_id)
    level = (user or {}).get("level") or 1
    progress = {r["mission_id"]: r for r in table("user_missions").select_eq("user_id", user_id)}

    missions = []
    for r in table("missions").all():
        # 내 수준보다 한 단계 위까지 보여 줌 (도전 미션)
        if (r.get("level") or 1) > level + 1:
            continue
        p = progress.get(r["id"], {})
        missions.append(
            Mission(
                id=r["id"],
                title=r["title"],
                store_type=r["store_type"],
                target_pattern=r.get("target_pattern") or "",
                reward=r["reward_points"],
                level=r.get("level") or 1,
                status=p.get("status", "new"),
                best_step=p.get("best_step", 0),
            )
        )
    # 진행 중 → 새 미션 → 완료 순, 같은 상태면 쉬운 것부터
    missions.sort(key=lambda m: (_STATUS_ORDER[m.status], m.level))
    return MissionsOut(missions=missions)