# 담당: 개발자1
from fastapi import APIRouter, File, UploadFile

from ..schemas import MenuScanOut
from ..vision import scan_menu

router = APIRouter(tags=["ai"])


@router.post("/ai/menu-scan", response_model=MenuScanOut)
async def menu_scan(image: UploadFile = File(...)):
    items, fallback = await scan_menu(await image.read())
    return MenuScanOut(items=items, fallback=fallback)
