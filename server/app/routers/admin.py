# 담당: 개발자3 (P1)
from fastapi import APIRouter

from ..schemas import AdminStatsOut

router = APIRouter(tags=["admin"])


@router.get("/admin/stats", response_model=AdminStatsOut)
def stats():
    # TODO(개발자3): 실제 집계
    return AdminStatsOut(missions=0, step_counts={}, store_visits={})
