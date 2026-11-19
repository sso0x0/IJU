"""메뉴판·영수증 인식 (개발자1). 영수증 인식 함수 scan_receipt는 개발자3이 그대로 가져다 씁니다."""

from .llm import LLMError, vision_json
from .schemas import ReceiptScan, ScannedItem

MENU_PROMPT = """너는 한국 동네 가게의 메뉴판·가격표를 읽는 OCR 도우미다.
사진에서 메뉴를 모두 찾아 아래 JSON 형식으로만 답하라. 설명은 쓰지 마라.
{"items": [{"name": "삼겹살", "price": 2800, "unit": "100g", "confidence": 0.95}]}
- price는 원 단위 정수, 읽을 수 없으면 null
- unit은 "100g", "1인분", "1팩" 같은 판매 단위, 없으면 null
- 손글씨라 확신이 낮으면 confidence를 낮게 준다 (0~1)"""

RECEIPT_PROMPT = """너는 한국 카드 영수증을 읽는 OCR 도우미다.
아래 JSON 형식으로만 답하라. 설명은 쓰지 마라. 카드번호는 절대 출력하지 마라.
{"store_name": "홍천 한우정육점", "business_no": "123-45-67890", "receipt_no": "0012",
 "issued_at": "2026-11-19T13:20:00", "amount": 16800, "confidence": 0.9}
- 읽을 수 없는 값은 null"""

# 시연용 대체 응답: AI 키가 없거나 네트워크가 끊겨도 화면이 멈추지 않게 합니다.
DEMO_MENU = [
    ScannedItem(name="삼겹살", price=2800, unit="100g", confidence=1.0),
    ScannedItem(name="목살", price=2600, unit="100g", confidence=1.0),
    ScannedItem(name="한우 불고기", price=5500, unit="100g", confidence=1.0),
]


async def scan_menu(image_bytes: bytes) -> tuple[list[ScannedItem], bool]:
    """반환값: (메뉴 목록, 대체 응답 여부)"""
    try:
        data = await vision_json(image_bytes, MENU_PROMPT)
        items = [ScannedItem(**i) for i in data.get("items", [])]
        if not items:
            raise LLMError("no items")
        return items, False
    except (LLMError, TypeError, ValueError):
        return DEMO_MENU, True


async def scan_receipt(image_bytes: bytes) -> ReceiptScan:
    """영수증에서 가게명·사업자번호·영수증번호·일시·금액 추출.
    실패하면 confidence=0인 빈 결과를 돌려주므로, 호출 쪽에서 상인 확인 코드로 넘기면 됩니다."""
    try:
        data = await vision_json(image_bytes, RECEIPT_PROMPT)
        return ReceiptScan(**data)
    except (LLMError, TypeError, ValueError):
        return ReceiptScan(confidence=0.0)
