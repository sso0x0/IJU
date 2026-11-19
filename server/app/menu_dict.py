"""업종별 메뉴 사전. OCR 결과를 비슷한 메뉴명으로 보정하는 데 씁니다.

- MENU_DICT: 직접 정리한 동네 가게 메뉴 (정육 부위처럼 표준데이터에 없는 것 포함)
- data/food_names.json: 전국통합식품영양성분정보 음식 표준데이터의 대표식품명을 업종별로 묶은 것

키워드는 places.category_small / category_mid에 들어 있는 글자로 찾습니다.
메뉴판 사진으로 정답지를 만들면서 실제로 나온 메뉴명을 MENU_DICT에 계속 추가하세요.
"""

import json
from pathlib import Path

_FOOD = json.loads(
    (Path(__file__).parent / "data" / "food_names.json").read_text(encoding="utf-8")
)

MENU_DICT: dict[str, list[str]] = {
    "정육": [
        "삼겹살", "오겹살", "목살", "항정살", "가브리살", "갈매기살", "앞다리", "뒷다리",
        "등심", "안심", "갈비", "돼지갈비", "등갈비", "족발", "사태", "다짐육", "불고기",
        "한우 등심", "한우 안심", "한우 채끝", "한우 갈비살", "한우 불고기", "한우 국거리",
        "차돌박이", "양지", "우삼겹", "닭고기", "닭가슴살", "닭다리", "오리고기",
    ],
    "반찬": [
        "김치", "깍두기", "총각김치", "열무김치", "오이소박이", "멸치볶음", "어묵볶음",
        "진미채", "콩자반", "장조림", "메추리알 장조림", "시금치나물", "콩나물무침",
        "고사리나물", "도라지무침", "무생채", "잡채", "계란말이", "감자조림", "깻잎장아찌",
        "오징어젓", "명란젓", "미역줄기볶음", "취나물", "연근조림", "우엉조림",
    ],
    "한식": [
        "김치찌개", "된장찌개", "순두부찌개", "부대찌개", "제육볶음", "오징어볶음",
        "불고기", "비빔밥", "돌솥비빔밥", "김치볶음밥", "갈비탕", "설렁탕", "곰탕",
        "육개장", "감자탕", "뼈해장국", "순대국", "칼국수", "수제비", "냉면", "물냉면",
        "비빔냉면", "백반", "생선구이", "고등어구이", "닭갈비", "막국수", "공기밥",
        "짜글이", "돼지고기 짜글이", "두루치기", "제육덮밥", "김치찜", "주먹밥", "오돌뼈", "오돌뼈볶음",
    ],
    "분식": [
        "김밥", "참치김밥", "치즈김밥", "떡볶이", "라볶이", "순대", "튀김", "어묵",
        "라면", "쫄면", "만두", "우동", "돈까스", "오므라이스",
    ],
    "주점": [
        "오돌뼈", "오돌뼈볶음", "오돌뼈 주먹밥", "주먹밥", "돼지고기 짜글이", "짜글이", "김치짜글이",
        "골뱅이무침", "골뱅이소면", "닭발", "무뼈닭발", "곱창", "곱창볶음", "막창", "대창",
        "닭똥집", "똥집튀김", "두루치기", "제육두루치기", "쭈꾸미볶음", "오징어볶음", "낙지볶음",
        "계란말이", "계란찜", "김치전", "파전", "해물파전", "감자전", "부추전", "두부김치",
        "어묵탕", "오뎅탕", "홍합탕", "알탕", "번데기탕", "치킨", "후라이드", "양념치킨",
        "감자튀김", "노가리", "먹태", "황태구이", "마른안주", "과일안주", "소주", "맥주", "생맥주",
        "막걸리", "콘치즈", "소시지야채볶음", "떡볶이", "라면",
    ],
    "카페": [
        "아메리카노", "카페라떼", "카푸치노", "바닐라라떼", "카라멜마끼아또", "콜드브루",
        "녹차라떼", "고구마라떼", "초코라떼", "아이스티", "레몬에이드", "자몽에이드",
        "밀크티", "딸기라떼", "케이크", "크로플", "마카롱",
    ],
}

# category_small 등에 이 글자가 있으면 해당 사전을 씁니다 (앞에 있을수록 우선).
_KEYWORDS: list[tuple[str, str]] = [
    ("정육", "정육"),
    ("축산", "정육"),
    ("반찬", "반찬"),
    ("분식", "분식"),
    ("김밥", "분식"),
    ("카페", "카페"),
    ("커피", "카페"),
    ("비알코올", "카페"),
    ("주점", "주점"),
    ("호프", "주점"),
    ("포차", "주점"),
    ("술집", "주점"),
    ("요리주점", "주점"),
    ("백반", "한식"),
    ("한정식", "한식"),
    ("한식", "한식"),
    ("국밥", "한식"),
    ("찌개", "한식"),
]


def _merge(*lists: list[str]) -> list[str]:
    """순서를 지키며 중복 제거. 직접 정리한 메뉴가 앞에 오도록 (프롬프트 예시에 쓰임)."""
    seen: set[str] = set()
    out = []
    for lst in lists:
        for w in lst:
            if w not in seen:
                seen.add(w)
                out.append(w)
    return out


def dict_for(*categories: str | None) -> tuple[str | None, list[str]]:
    """업종 문자열들(소 → 중 → 대 순)로 맞는 사전을 고릅니다.

    업종을 모르면 (None, 전체 음식명). 업종을 알지만 사전이 없는 업종(예: 안경점)이면 (None, []).
    """
    known = [c for c in categories if c]
    for cat in known:
        for keyword, key in _KEYWORDS:
            if keyword in cat:
                food_key = "한식" if key == "주점" else key
                return key, _merge(MENU_DICT[key], _FOOD["groups"].get(food_key, []))
    if known:
        return None, []
    return None, _merge(*MENU_DICT.values(), _FOOD["all"])


def _distance(a: str, b: str) -> int:
    """편집 거리: a를 b로 바꾸는 데 필요한 글자 추가·삭제·교체 횟수."""
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def correct(name: str, words: list[str], min_similarity: float = 0.6) -> str | None:
    """메뉴명 전체로 먼저 찾고, 없으면 띄어쓴 단어별로 고칩니다 (예: 오도뼈 주먹밥 → 오돌뼈 주먹밥)."""
    whole = _correct_one(name, words, min_similarity)
    if whole is not None or " " not in name.strip():
        return whole
    vocab = _vocab(tuple(words))
    parts = name.split()
    fixed = [_correct_one(p, vocab, min_similarity) or p for p in parts]
    return " ".join(fixed) if fixed != parts else None


_VOCAB_CACHE: dict[int, list[str]] = {}


def _vocab(words: tuple[str, ...]) -> list[str]:
    """사전 메뉴명을 띄어쓰기로 나눈 단어 목록 (2글자 이상)."""
    key = hash(words)
    if key not in _VOCAB_CACHE:
        _VOCAB_CACHE[key] = sorted({p for w in words for p in w.split() if len(p) >= 2} | set(words))
    return _VOCAB_CACHE[key]


def _correct_one(name: str, words: list[str], min_similarity: float) -> str | None:
    """사전에서 가장 가까운 메뉴명을 찾습니다.

    띄어쓰기는 무시하고 비교합니다. 가장 가까운 후보가 둘 이상이거나
    충분히 비슷하지 않으면 None (잘못 고치는 것보다 그대로 두는 게 낫습니다).
    """
    clean = name.replace(" ", "")
    if not clean or not words:
        return None
    scored = []
    for w in words:
        wc = w.replace(" ", "")
        d = _distance(clean, wc)
        if d == 0:
            return name  # 띄어쓰기만 다르면 메뉴판 표기 그대로
        scored.append((d, w, 1 - d / max(len(clean), len(wc))))
    scored.sort()
    best_d, best, sim = scored[0]
    if sim < min_similarity:
        return None
    if len(scored) > 1 and scored[1][0] == best_d:
        return None
    return best
