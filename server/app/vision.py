"""메뉴판·영수증 인식 (개발자1). 영수증 인식 함수 scan_receipt는 개발자3이 그대로 가져다 씁니다."""

from .llm import LLMError, vision_json
from .menu_dict import correct, dict_for
from .schemas import ReceiptScan, ScannedItem

MENU_PROMPT = """너는 한국 동네 가게의 메뉴판·가격표를 읽는 OCR 도우미다.
{hint}먼저 사진의 글자를 한 줄씩 빠짐없이 읽은 뒤, 메뉴만 골라 아래 JSON 형식으로만 답하라. 설명은 쓰지 마라.
{{"items": [{{"name": "삼겹살", "price": 2800, "unit": "100g", "confidence": 0.95}}]}}
- 가게 이름, 메뉴판 제목, 전화번호, 영업시간, 원산지 표시는 메뉴가 아니다
- price는 원 단위 정수 ("2,800원", "2.8천" → 2800). 읽을 수 없으면 null
- unit은 "100g", "1근", "1인분", "1팩" 같은 판매 단위. 없으면 null
- 손글씨나 흐린 글씨라 확신이 낮으면 confidence를 낮게 준다 (0~1)
- 메뉴명은 맞춤법에 맞는 한국어 표준 표기로 쓴다{examples}"""


def _menu_prompt(category: str | None, words: list[str]) -> str:
    hint = f"이 사진은 '{category}' 업종 가게의 메뉴판이다.\n" if category else ""
    examples = f"\n- 이 업종에서 자주 나오는 메뉴: {', '.join(words[:25])}" if words else ""
    return MENU_PROMPT.format(hint=hint, examples=examples)

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


async def scan_menu(
    image_bytes: bytes, categories: tuple[str | None, ...] = ()
) -> tuple[list[ScannedItem], bool]:
    """반환값: (메뉴 목록, 대체 응답 여부)

    categories: 업종 (소 → 중 → 대 순, 예: ("정육점", "축산물", "소매")). 힌트와 사전 보정에 씁니다.
    """
    category = next((c for c in categories if c), None)
    _, words = dict_for(*categories)
    try:
        data = await vision_json(image_bytes, _menu_prompt(category, words))
        items = [ScannedItem(**i) for i in data.get("items", [])]
        if not items:
            raise LLMError("no items")
    except (LLMError, TypeError, ValueError):
        return DEMO_MENU, True
    return [_apply_dict(i, words) for i in items], False


def _apply_dict(item: ScannedItem, words: list[str]) -> ScannedItem:
    """사전에 있는 메뉴면 표기를 맞추고 신뢰도를 올립니다. 없으면 그대로 둡니다."""
    match = correct(item.name, words)
    if match is None:
        return item
    return item.model_copy(
        update={
            "name": match,
            "confidence": max(item.confidence, 0.9),
            "corrected_from": item.name if match != item.name else None,
        }
    )


async def scan_receipt(image_bytes: bytes) -> ReceiptScan:
    """영수증에서 가게명·사업자번호·영수증번호·일시·금액 추출.
    실패하면 confidence=0인 빈 결과를 돌려주므로, 호출 쪽에서 상인 확인 코드로 넘기면 됩니다."""
    try:
        data = await vision_json(image_bytes, RECEIPT_PROMPT)
        return ReceiptScan(**data)
    except (LLMError, TypeError, ValueError):
        return ReceiptScan(confidence=0.0)
