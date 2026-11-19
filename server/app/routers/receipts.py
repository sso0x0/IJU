# 담당: 개발자3 (영수증 인식은 개발자1의 vision.scan_receipt 사용)
from fastapi import APIRouter, File, Form, UploadFile

from ..schemas import ReceiptOut
from ..vision import scan_receipt

router = APIRouter(tags=["receipts"])


@router.post("/receipts", response_model=ReceiptOut)
async def verify_receipt(
    user_id: str = Form(...),
    mission_id: str = Form(...),
    image: UploadFile = File(...),
):
    scan = await scan_receipt(await image.read())
    # TODO(개발자3): PRD 3.9 부정 사용 방지 규칙 (해시 중복, 영수증 재사용, 등록 가게, 24시간, 하루 3회)
    #                통과 시 coupons에 저장하고 쿠폰 반환
    if scan.confidence < 0.5:
        return ReceiptOut(verified=False, reason="low_confidence")  # → 상인 확인 코드 화면
    return ReceiptOut(verified=False, reason="not_implemented")
