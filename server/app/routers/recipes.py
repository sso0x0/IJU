# 메뉴 이름으로 Supabase recipes(식약처 조리식품 레시피) 표에서 레시피를 찾아 재료를 돌려줍니다.
# 앱의 문장 만들기가 이 재료로 '빼 주세요'(보이는 재료)·'들어가요?'(육수·양념) 칩을 보강합니다.
import logging
import re
from functools import lru_cache

from fastapi import APIRouter

from ..db import fetch_all

router = APIRouter(tags=["recipes"])
log = logging.getLogger(__name__)

# 국물·양념처럼 눈에 안 보이는 재료 묶음 이름 (이 묶음의 재료는 '들어가요?'로 묻습니다)
_SAUCE_WORDS = ("육수", "국물", "소스", "양념", "드레싱", "조림장", "밑간", "양념장", "장")
# 줄 앞에 붙는 묶음 이름: '재료 …', '●주재료 …', '[양념] …', '육수 : …', '주재료 > …'
_SECTION = re.compile(
    r"^[\s•●·\-\[(]*"
    r"(필수\s?재료|주\s?재료|부\s?재료|추가\s?재료|반죽\s?재료|재료|곁들임\s?채소|고명|토핑"
    r"|육수\s?재료|육수|국물|양념장|양념|소스|드레싱)"
    r"[\])]*\s*[:：>]?\s+"
)
# '찜소스:다시마국물 100g'처럼 콜론 앞이 양념 이름인 경우
_NAMED_SAUCE = re.compile(r"^\s*([가-힣\s]{1,8}(?:소스|양념|장|국물|육수|드레싱))\s*[:：]\s*")
_PAREN = re.compile(r"\([^)]*\)|\[[^\]]*\]")
_NAME = re.compile(r"^[^\d]+")


def _norm(s: str) -> str:
    """비교용 이름: 공백·기호를 빼고, '삼치튀김, 타르타르소스'처럼 쉼표 뒤는 버립니다."""
    s = s.split(",")[0]
    return re.sub(r"[^0-9A-Za-z가-힣]", "", s)


def _is_sauce(label: str) -> bool:
    return any(w in label for w in _SAUCE_WORDS) and "재료" not in label.replace("육수재료", "")


def _item_name(raw: str) -> str | None:
    s = _PAREN.sub("", raw).strip(" .·•●-[]()>:")
    m = _NAME.match(s)
    name = (m.group(0) if m else "").strip(" .·•●-[]()>:")
    if not name or len(name) > 15 or "인분" in name:
        return None
    return name


def _split_items(line: str) -> list[str]:
    """쉼표로 나누되 괄호 안 쉼표('돼지고기(사태, 60g)')는 나누지 않습니다. '200cc. 망고'도 나눕니다."""
    parts, buf, depth = [], [], 0
    for i, ch in enumerate(line):
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth = max(0, depth - 1)
            # '다시마(3g) 대파(10g)'처럼 쉼표가 빠진 경우: 닫는 괄호 뒤 공백에서 나눕니다.
            if depth == 0 and line[i + 1 : i + 2] == " ":
                buf.append(ch)
                parts.append("".join(buf))
                buf = []
                continue
        if depth == 0 and (ch == "," or (ch == "." and line[i + 1 : i + 2] == " ")):
            parts.append("".join(buf))
            buf = []
            continue
        buf.append(ch)
    parts.append("".join(buf))
    return parts


def parse_ingredients(text: str) -> tuple[list[str], list[str]]:
    """재료 글을 (보이는 재료, 육수·양념 재료) 이름 목록으로 나눕니다."""
    text = (text or "").replace("<br />", "\n").replace("<br/>", "\n").replace("[소스소개]", "\n소스 ")
    main: list[str] = []
    sauce: list[str] = []
    sauce_section = False
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if m := _SECTION.match(line):
            sauce_section = _is_sauce(m.group(1).replace(" ", ""))
            line = line[m.end():]
        elif m := _NAMED_SAUCE.match(line):
            sauce_section = True
            line = line[m.end():]
        for part in _split_items(line):
            # 한 줄 안에서 '저나트륨 두부 된장소스:두부 15g'처럼 양념 이름이 나오면 그 뒤는 양념
            if ":" in part or "：" in part:
                head, part = re.split(r"[:：]", part, maxsplit=1)
                if _is_sauce(head):
                    sauce_section = True
            name = _item_name(part)
            if name:
                (sauce if sauce_section else main).append(name)
    return main, sauce


# 비슷한 레시피를 몇 개까지 모아 공통 재료를 볼지
_MAX_SIMILAR = 15


@lru_cache(maxsize=1)
def _rows() -> tuple[dict, ...]:
    """레시피 이름·분류·재료 (서버가 켜져 있는 동안 한 번만 읽습니다. 1천여 행이라 가볍습니다)."""
    try:
        rows = fetch_all("recipes", "id,name,category,ingredients")
    except Exception:  # noqa: BLE001 — 표가 없거나 연결 실패면 레시피 없이 동작
        log.exception("recipes 표를 읽지 못했어요")
        return ()
    return tuple({**r, "key": _norm(r["name"])} for r in rows if r.get("name"))


def find_recipes(menu: str, rows: tuple[dict, ...]) -> tuple[str | None, list[dict]]:
    """메뉴에 맞는 레시피를 (찾은 방법, 레시피 목록)으로 돌려줍니다.

    1. exact: 이름이 같은 레시피
    2. contained: 메뉴 이름 안에 든 가장 긴 레시피 이름 (얼큰순두부찌개 → 순두부찌개)
    3. similar: 메뉴 이름의 뒷부분(3글자 이상)이 들어간 레시피들 (김치찌개 → 오징어김치찌개,
       완자김치찌개…). 레시피마다 재료가 달라서 앱은 여러 레시피에 공통인 재료만 씁니다.
    """
    m = _norm(menu)
    if not m:
        return None, []
    contained: dict | None = None
    for r in rows:
        if r["key"] == m:
            return "exact", [r]
        if len(r["key"]) >= 3 and r["key"] in m and (contained is None or len(r["key"]) > len(contained["key"])):
            contained = r
    if contained:
        return "contained", [contained]
    for start in range(len(m) - 2):
        tail = m[start:]
        similar = [r for r in rows if tail in r["key"]]
        if similar:
            similar.sort(key=lambda r: len(r["key"]))  # 이름이 짧을수록 덧붙은 재료가 적음
            return "similar", similar[:_MAX_SIMILAR]
    return None, []


@router.get("/recipes/match")
def match_recipe(menu: str):
    """메뉴에 맞는 레시피와 재료. 못 찾으면 mode가 null이고 recipes가 비어 있습니다.

    재료는 main(보이는 재료)과 sauce(육수·국물·양념·소스)로 나눠 줍니다.
    """
    mode, found = find_recipes(menu, _rows())
    recipes = []
    for r in found:
        main, sauce = parse_ingredients(r.get("ingredients") or "")
        recipes.append({"name": r["name"], "category": r.get("category"), "main": main, "sauce": sauce})
    return {"mode": mode, "recipes": recipes}
