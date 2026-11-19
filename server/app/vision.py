"""메뉴판·영수증 인식 (개발자1). 영수증 인식 함수 scan_receipt는 개발자3이 그대로 가져다 씁니다."""

import asyncio
import io
import time
from dataclasses import dataclass, field

from PIL import Image, ImageOps

from .config import settings
from .llm import LLMError, text_json, vision_json
from .menu_dict import correct, dict_for
from .schemas import ReceiptScan, ScannedItem

MENU_PROMPT = """너는 한국 동네 가게의 메뉴판을 읽는 OCR 도우미다. 손글씨 메뉴판도 많다.
{hint}{tile}가격은 읽지 않는다. 메뉴 이름만 정확하게 읽는 것이 목표다.
아래 순서대로 하고, JSON 형식으로만 답하라. 설명은 쓰지 마라.

1단계 raw_lines: 사진의 글자를 위에서 아래로, 왼쪽에서 오른쪽으로 한 줄씩 빠짐없이 그대로 옮겨 적는다.
   메뉴가 아닌 줄(가게 이름, 제목, 전화번호)도 적는다. 여러 칸으로 나뉜 메뉴판은 칸마다 끝까지 읽는다.
   손글씨는 글자 하나하나의 획을 보고 읽는다. 비슷한 글자(예: 돌/도, 글/곱, 이/창)를 특히 주의한다.
2단계 items: raw_lines에서 메뉴 이름인 줄을 하나도 빠뜨리지 말고 모두 옮긴다.

{{"raw_lines": ["오늘의 안주", "돼지고기 짜글이 15,000", "오돌뼈 주먹밥 6000"],
 "items": [{{"name": "돼지고기 짜글이", "unit": null, "confidence": 0.8}},
           {{"name": "오돌뼈 주먹밥", "unit": null, "confidence": 0.8}}]}}

규칙:
- 가게 이름, 메뉴판 제목, 전화번호, 영업시간, 원산지, 가격 숫자는 items에 넣지 않는다
- 절대 추측해서 다른 메뉴로 바꾸지 마라. 애매한 글자는 보이는 대로 적고 confidence를 0.5 이하로 준다
- 글자가 분명할 때만 맞춤법에 맞게 고친다 (예: 김치찌게 → 김치찌개)
- unit은 메뉴 이름 옆의 판매 단위("100g", "1근", "1인분", "1팩")만. 없으면 null
- confidence: 또렷한 인쇄 글씨 0.9 이상, 읽을 만한 손글씨 0.6~0.8, 애매하면 0.5 이하{examples}"""

TILE_HINT = (
    "이 사진은 메뉴판을 가로로 자른 {n}조각 중 {i}번째 조각이다. "
    "위아래 가장자리에서 반쯤 잘린 줄은 건너뛴다 (다른 조각에 온전히 있다).\n"
)


def _menu_prompt(category: str | None, words: list[str], tile: tuple[int, int] | None = None) -> str:
    hint = f"참고: 이 사진은 '{category}' 업종 가게의 메뉴판일 가능성이 높다.\n" if category else ""
    tile_hint = TILE_HINT.format(i=tile[0], n=tile[1]) if tile else ""
    examples = (
        f"\n- 참고용으로 이 업종에서 자주 나오는 메뉴: {', '.join(words[:20])}. "
        "목록에 없는 메뉴도 사진에 있으면 그대로 적는다"
        if words
        else ""
    )
    return MENU_PROMPT.format(hint=hint, tile=tile_hint, examples=examples)


LANG_NAMES = {"vi": "Vietnamese", "en": "English", "fil": "Filipino", "km": "Khmer", "ko": "Korean"}

GLOSS_PROMPT = """You help foreigners understand Korean restaurant menus.
For each Korean menu name below, write in {lang}:
- meaning: what the dish is, 2-5 words (e.g. "Soybean paste stew")
- romanization: how to pronounce it in Korean, syllables joined by hyphens (e.g. "doen-jang-jji-gae")
- description: one short sentence a tourist can understand (main ingredients, taste). No more than 12 words.
If a name is not a food (or unreadable), set meaning to null.
Answer only JSON: {{"items": [{{"name": "<same Korean name>", "meaning": "...", "romanization": "...", "description": "..."}}]}}

Menu names:
{names}"""


async def add_glosses(items: list[ScannedItem], language: str) -> list[ScannedItem]:
    """메뉴마다 뜻·발음·한 줄 설명을 붙입니다 (텍스트 AI 한 번 호출). 실패해도 메뉴 목록은 그대로 돌려줍니다."""
    if not items:
        return items
    lang = LANG_NAMES.get(language, "English")
    names = "\n".join(f"- {i.name}" for i in items)
    try:
        data = await text_json(GLOSS_PROMPT.format(lang=lang, names=names))
    except LLMError as e:
        print(f"[menu-scan] 뜻 붙이기 실패: {e}", flush=True)
        return items
    by_name = {
        _key(str(g.get("name", ""))): g for g in data.get("items", []) if isinstance(g, dict)
    }
    out = []
    for it in items:
        g = by_name.get(_key(it.name), {})
        out.append(
            it.model_copy(
                update={
                    "meaning": g.get("meaning") or None,
                    "romanization": g.get("romanization") or None,
                    "description": g.get("description") or None,
                }
            )
        )
    return out


RECEIPT_PROMPT = """너는 한국 카드 영수증을 읽는 OCR 도우미다.
아래 JSON 형식으로만 답하라. 설명은 쓰지 마라. 카드번호는 절대 출력하지 마라.
{"is_receipt": true, "store_name": "홍천 한식당", "business_no": "123-45-67890", "receipt_no": "0012",
 "issued_at": "2026-11-19T13:20:00", "amount": 16800, "confidence": 0.9}
- 읽을 수 없는 값은 null
- is_receipt: 가게 단말기·프린터로 출력한 실제 카드·현금 영수증(감열지 등)을 찍은 사진이면 true.
  손으로 쓴 종이, 메모, 다른 화면(모니터·휴대폰)을 다시 찍은 사진, 영수증이 아닌 사진이면 false"""

# 시연용 대체 응답: DEMO_FALLBACK=true일 때만 씁니다 (리허설·네트워크 장애 대비).
DEMO_MENU = [
    ScannedItem(name="김치찌개", price=9000, unit="1인분", confidence=1.0),
    ScannedItem(name="제육볶음", price=10000, unit="1인분", confidence=1.0),
    ScannedItem(name="삼겹살", price=15000, unit="1인분", confidence=1.0),
]


@dataclass
class MenuScanResult:
    items: list[ScannedItem]
    raw_lines: list[str] = field(default_factory=list)
    fallback: bool = False
    llm_ms: int = 0
    error: str | None = None  # "llm_error"(AI 호출 실패·시간 초과), "no_menu"(메뉴를 못 찾음)


def _split_tiles(image_bytes: bytes) -> list[bytes]:
    """메뉴판을 가로 띠 여러 장으로 겹치게 자릅니다.

    OpenAI 등은 사진의 짧은 변을 약 768px로 줄여서 보기 때문에, 한 장으로 보내면 손글씨가 뭉개집니다.
    가로로 길게 자르면 같은 글자가 더 크게 보입니다. 띠끼리 15% 겹쳐서 경계에 걸린 줄도 한 조각엔 온전히 들어갑니다.
    """
    img = ImageOps.exif_transpose(Image.open(io.BytesIO(image_bytes))).convert("RGB")
    w, h = img.size
    n = settings.image_tiles or (3 if h > w * 1.2 else 2)
    if n <= 1:
        return [image_bytes]
    overlap = 0.15
    step = h / (n - (n - 1) * overlap)  # 각 띠 높이
    tiles = []
    for i in range(n):
        top = int(i * step * (1 - overlap))
        bottom = min(h, int(top + step))
        buf = io.BytesIO()
        img.crop((0, top, w, bottom)).save(buf, format="JPEG", quality=95)
        tiles.append(buf.getvalue())
    return tiles


async def _scan_one(image: bytes, prompt: str) -> tuple[list[str], list[ScannedItem]]:
    data = await vision_json(image, prompt)
    raw_lines = [str(x) for x in data.get("raw_lines", []) if str(x).strip()]
    items = []
    for i in data.get("items", []):
        i = {k: v for k, v in i.items() if k != "price"}  # 가격은 읽지 않음
        items.append(ScannedItem(**i))
    return raw_lines, items


def _key(name: str) -> str:
    return name.replace(" ", "")


def _merge_items(groups: list[list[ScannedItem]]) -> list[ScannedItem]:
    """조각별 결과를 합칩니다. 겹친 부분의 중복은 신뢰도 높은 쪽, 잘린 이름은 긴 쪽을 남깁니다."""
    merged: list[ScannedItem] = []
    for items in groups:
        for it in items:
            k = _key(it.name)
            if not k:
                continue
            dup = next(
                (j for j, m in enumerate(merged) if k == _key(m.name) or k in _key(m.name) or _key(m.name) in k),
                None,
            )
            if dup is None:
                merged.append(it)
                continue
            old = merged[dup]
            if len(k) > len(_key(old.name)) or (
                len(k) == len(_key(old.name)) and it.confidence > old.confidence
            ):
                merged[dup] = it
    return merged


async def scan_menu(
    image_bytes: bytes, categories: tuple[str | None, ...] = ()
) -> MenuScanResult:
    """categories: 업종 (소 → 중 → 대 순, 예: ("한식", "음식점", "음식")). 힌트와 사전 보정에 씁니다."""
    category = next((c for c in categories if c), None)
    _, words = dict_for(*categories)
    started = time.perf_counter()
    try:
        tiles = _split_tiles(image_bytes)
    except Exception as e:  # 이미지가 아니거나 깨진 파일
        return _failed(f"bad_image: {e}")
    n = len(tiles)
    prompts = [_menu_prompt(category, words, (i + 1, n) if n > 1 else None) for i in range(n)]
    results = await asyncio.gather(
        *(_scan_one(t, p) for t, p in zip(tiles, prompts)), return_exceptions=True
    )
    llm_ms = _ms(started)
    ok = [r for r in results if not isinstance(r, BaseException)]
    errors = [r for r in results if isinstance(r, BaseException)]
    for e in errors:
        print(f"[menu-scan] 조각 인식 실패: {type(e).__name__}: {e}", flush=True)
    if not ok:
        e = errors[0]
        kind = "llm_error" if isinstance(e, LLMError) else "bad_response"
        return _failed(f"{kind}: {e}", llm_ms=llm_ms)
    raw_lines: list[str] = []
    for lines, _ in ok:
        for line in lines:
            if not raw_lines or raw_lines[-1] != line:
                raw_lines.append(line)
    items = _merge_items([its for _, its in ok])
    if not items:
        return _failed("no_menu", raw_lines, llm_ms=llm_ms)
    return MenuScanResult(
        items=[_apply_dict(i, words) for i in items],
        raw_lines=raw_lines,
        llm_ms=llm_ms,
        error=f"partial: {len(errors)}/{n} 조각 실패" if errors else None,
    )


def _ms(started: float) -> int:
    return round((time.perf_counter() - started) * 1000)


def _failed(error: str, raw_lines: list[str] | None = None, llm_ms: int = 0) -> MenuScanResult:
    if settings.demo_fallback:
        return MenuScanResult(
            items=DEMO_MENU, raw_lines=raw_lines or [], fallback=True, error=error, llm_ms=llm_ms
        )
    return MenuScanResult(items=[], raw_lines=raw_lines or [], error=error, llm_ms=llm_ms)


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
