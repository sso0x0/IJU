# 담당: 개발자3 (P1) — 관리자 대시보드 집계 (PRD F12)
from fastapi import APIRouter

from ..db import table
from ..schemas import AdminStatsOut

router = APIRouter(tags=["admin"])


@router.get("/admin/stats", response_model=AdminStatsOut)
def stats():
    user_missions = table("user_missions").all()
    stores = {s["id"]: s["name"] for s in table("stores").all()}

    # 단계별 도달자 수: best_step이 k 이상인 (사용자, 미션) 수. "4"가 혼자 말하기 도달
    step_counts = {
        str(k): sum(1 for r in user_missions if (r.get("best_step") or 0) >= k) for k in range(1, 5)
    }
    step_counts["completed"] = sum(1 for r in user_missions if r.get("status") == "completed")

    store_visits: dict[str, int] = {}
    for r in table("receipts").all():
        if r.get("verified"):
            name = stores.get(r.get("store_id"), "미등록 가게")
            store_visits[name] = store_visits.get(name, 0) + 1

    return AdminStatsOut(missions=len(user_missions), step_counts=step_counts, store_visits=store_visits)
