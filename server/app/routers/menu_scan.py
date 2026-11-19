# 담당: 개발자1
import time

from fastapi import APIRouter, File, Form, UploadFile

from ..db import table
from ..schemas import MenuScanOut
from ..vision import scan_menu

router = APIRouter(tags=["ai"])


def _place_categories(place_id: str | None) -> tuple[str | None, ...]:
    """places 테이블(소상공인 상가정보)에서 업종을 소 → 중 → 대 순으로 꺼냅니다."""
    if not place_id:
        return ()
    try:
        rows = table("places").select_eq("id", place_id)
    except Exception:  # DB 연결 문제로 인식 전체가 멈추지 않게
        return ()
    if not rows:
        return ()
    p = rows[0]
    return (p.get("category_small"), p.get("category_mid"), p.get("category_large"))


@router.post("/ai/menu-scan", response_model=MenuScanOut)
async def menu_scan(
    image: UploadFile = File(...),
    place_id: str | None = Form(None),  # places.id. 있으면 업종 힌트 + 메뉴 사전 보정
):
    started = time.perf_counter()
    categories = _place_categories(place_id)
    result = await scan_menu(await image.read(), categories)
    return MenuScanOut(
        items=result.items,
        fallback=result.fallback,
        category=next((c for c in categories if c), None),
        raw_lines=result.raw_lines,
        error=result.error,
        llm_ms=result.llm_ms,
        elapsed_ms=round((time.perf_counter() - started) * 1000),
    )
