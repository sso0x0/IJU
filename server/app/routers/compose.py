# 담당: 개발자2 — 키워드 카드로 주문 문장을 조립합니다.
# 문장·문법 조언은 규칙으로 만들고, LLM은 번역·카드 뜻을 맡습니다. 실패하면 규칙 대체 응답을 돌려줍니다.
import logging
import re

from fastapi import APIRouter

from .. import llm
from ..schemas import Card, ComposeIn, ComposeOut

router = APIRouter(tags=["ai"])
log = logging.getLogger(__name__)

_LANG_NAME = {
    "vi": "베트남어",
    "en": "영어",
    "fil": "필리핀어(타갈로그어)",
    "km": "크메르어",
    "ko": "한국어",
}

# 대체 응답용 작은 사전. LLM이 없을 때도 시연 경로(식당)가 자연스럽게 보이게 합니다.
_DICT: dict[str, dict[str, str]] = {
    "김치찌개": {"vi": "canh kim chi", "en": "kimchi stew"},
    "삼겹살": {"vi": "thịt ba chỉ", "en": "pork belly"},
    "1인분": {"vi": "1 phần", "en": "1 serving of"},
    "2인분": {"vi": "2 phần", "en": "2 servings of"},
    "3인분": {"vi": "3 phần", "en": "3 servings of"},
    "덜 맵게": {"vi": "ít cay", "en": "less spicy"},
    "보통으로": {"vi": "cay vừa", "en": "regular spicy"},
    "아주 맵게": {"vi": "thật cay", "en": "extra spicy"},
}
_SPICY = {"덜 맵게", "보통으로", "아주 맵게", "안 맵게"}  # 식당 맵기 카드 → '-게 해 주세요'
_SIDE_DISHES = {"콩자반", "시금치나물", "깍두기", "멸치볶음", "어묵볶음", "김치"}  # 반찬가게 '하나 더' → '-도'
_PLEASE = {"vi": "Cho tôi {}.", "en": "{}, please."}


def _has_batchim(word: str) -> bool:
    last = word[-1]
    return "가" <= last <= "힣" and (ord(last) - 0xAC00) % 28 != 0


def _token(option: str) -> str:
    """옵션 단어를 문장 속 모양으로 바꿉니다. 덜 맵게 → 덜 맵게 해, 콩자반 → 콩자반도."""
    if option in _SPICY:
        return option + " 해"
    if option in _SIDE_DISHES:
        return option + "도"
    return option


def _and(word: str) -> str:
    """두 낱말을 잇는 '-랑/이랑'. 돼지고기 → 돼지고기랑, 버섯 → 버섯이랑"""
    return word + ("이랑" if _has_batchim(word) else "랑")


def _topic(word: str) -> str:
    """'-는/은'. 돼지고기 → 돼지고기는, 버섯 → 버섯은"""
    return word + ("은" if _has_batchim(word) else "는")


def without_sentence(without: list[str]) -> str | None:
    """'빼 주세요' 문장. 돼지고기, 두부 → 돼지고기랑 두부는 빼 주세요."""
    if not without:
        return None
    return " ".join([*(_and(o) for o in without[:-1]), _topic(without[-1]), "빼 주세요."])


def ask_sentence(ask: list[str]) -> str | None:
    """'들어가요?' 문장. 고기 육수, 젓갈 → 고기 육수랑 젓갈 들어가요?"""
    if not ask:
        return None
    return " ".join([*(_and(o) for o in ask[:-1]), ask[-1], "들어가요?"])


def build_sentence(
    menu_item: str,
    options: list[str],
    without: list[str] | None = None,
    ask: list[str] | None = None,
) -> str:
    """앱 scenario/scenarios.dart의 카드(token)와 같은 모양이 나오게 맞춥니다.
    첫 문장 뒤에 '빼 주세요', '들어가요?' 문장을 고른 게 있을 때만 붙입니다."""
    main = " ".join([menu_item, *(_token(o) for o in options if o != menu_item), "주세요."])
    extra = [s for s in (without_sentence(without or []), ask_sentence(ask or [])) if s]
    return " ".join([main, *extra])


def _fallback(body: ComposeIn) -> ComposeOut:
    lang = body.language
    words = [body.menu_item, *body.selected_options, *body.without, *body.ask]
    cards = [Card(word=w, meaning=_DICT.get(w, {}).get(lang, "")) for w in words]
    meaning = ""
    # 빼기·질문 문장의 번역은 사전에 없으니 앱이 가진 번역을 쓰게 비워 둡니다.
    if lang in _PLEASE and not body.without and not body.ask and all(c.meaning for c in cards):
        menu, *opts = [c.meaning for c in cards]
        meaning = _PLEASE[lang].format(" ".join([*opts[:1], menu, *opts[1:]]))
    return ComposeOut(
        cards=cards,
        sentence=build_sentence(body.menu_item, body.selected_options, body.without, body.ask),
        feedback=rule_feedback(body.selected_options, body.without, body.ask),
        meaning=meaning,
    )


def rule_feedback(
    options: list[str],
    without: list[str] | None = None,
    ask: list[str] | None = None,
) -> str | None:
    """문장에 실제로 쓰인 문법을 규칙으로 짚습니다. 맞는 규칙이 없으면 None (LLM에 맡김)."""
    if ask:
        return f"모르는 재료는 ‘들어가요?’로 물어봐요. {ask_sentence(ask[:1])}"
    if without and len(without) > 1:
        return f"두 가지는 ‘-랑’으로 이어요. {without_sentence(without[:2])}"
    if without:
        return f"빼고 싶은 재료는 ‘-는 빼 주세요’로 말해요. {without_sentence(without)}"
    spicy = [o for o in options if o in _SPICY]
    if spicy:
        return f"맵기는 ‘-게 해 주세요’로 부탁해요. {_token(spicy[0])} 주세요"
    more = [o for o in options if o in _SIDE_DISHES]
    if more:
        return f"하나 더 살 때는 ‘-도’를 붙여요. {_token(more[0])} 주세요"
    return None


def _prompt(body: ComposeIn, sentence: str) -> str:
    lang = _LANG_NAME.get(body.language, "영어")
    words = ", ".join([body.menu_item, *body.selected_options, *body.without, *body.ask])
    return f"""너는 한국 동네 가게에서 외국인 손님이 스스로 주문하도록 돕는 한국어 선생님이야.
학습자가 카드를 골라 아래 주문 문장을 완성했어. 문장은 이미 맞으니 고치지 마.

문장: {sentence}
카드: {words}
학습자 모국어: {lang}

할 일:
- cards: 카드 단어 각각의 짧은 {lang} 뜻 (위 카드 순서 그대로)
- meaning: 문장의 자연스러운 {lang} 번역
- feedback: 이 문장에 실제로 쓰인 표현 한 가지를 한국어 한 문장(40자 이내)으로 짚어 줘.
  문장에 없는 조사·단위는 말하지 마. 짚을 문법이 없으면 '주세요' 쓰임을 설명해.
  예) 원하는 것 뒤에 ‘주세요’를 붙이면 공손하게 부탁할 수 있어요.

아래 JSON 하나만 답해.
{{"cards":[{{"word":"카드 단어","meaning":"{lang} 뜻"}}],"meaning":"번역","feedback":"조언"}}"""


# 지금 모델의 크메르어 번역은 다른 문자가 섞이고 뜻이 틀려서, 앱에 넣어 둔 번역을 씁니다.
_NO_LLM_TRANSLATION = {"km"}
_FOREIGN_SCRIPT = re.compile("[぀-ヿ一-鿿가-힣]")  # 가나·한자·한글


def _clean(text: str) -> bool:
    """학습자 언어 번역에 한자·가나·한글이 섞이지 않았는지."""
    return bool(text) and not _FOREIGN_SCRIPT.search(text)


# 같은 조합은 다시 묻지 않습니다 (시연 중 칩을 왔다 갔다 해도 바로 응답).
_cache: dict[tuple, ComposeOut] = {}


@router.post("/ai/compose", response_model=ComposeOut)
async def compose(body: ComposeIn):
    key = (body.menu_item, tuple(body.selected_options), tuple(body.without), tuple(body.ask), body.language)
    if key in _cache:
        return _cache[key]

    # 문장은 규칙으로 만들어 항상 문법이 맞게 하고, LLM은 번역·카드 뜻·조언만 맡습니다.
    fallback = _fallback(body)
    if body.language in _NO_LLM_TRANSLATION:
        return fallback
    try:
        data = await llm.text_json(_prompt(body, fallback.sentence))
        meaning = str(data["meaning"]).strip()
        out = ComposeOut(
            cards=[
                Card(word=c["word"], meaning=c["meaning"] if _clean(c["meaning"]) else "")
                for c in data["cards"]
            ],
            sentence=fallback.sentence,
            # 규칙으로 짚을 수 있으면 규칙 조언이 더 정확합니다.
            feedback=fallback.feedback or str(data.get("feedback") or "").strip() or None,
            # 번역이 이상하면 비워서 앱이 직접 가진 번역을 쓰게 합니다.
            meaning=meaning if _clean(meaning) else "",
        )
    except Exception as e:  # 키 없음, 시간 초과, 형식 오류 모두 대체 응답으로
        log.warning("compose fallback: %s", e)
        return fallback
    _cache[key] = out
    return out
