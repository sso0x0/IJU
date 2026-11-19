"""업종별 메뉴 사전. OCR 결과를 비슷한 메뉴명으로 보정하는 데 씁니다.

키워드는 places.category_small / category_mid에 들어 있는 글자로 찾습니다.
메뉴판 사진으로 정답지를 만들면서 실제로 나온 메뉴명을 계속 추가하세요.
"""

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
    ],
    "분식": [
        "김밥", "참치김밥", "치즈김밥", "떡볶이", "라볶이", "순대", "튀김", "어묵",
        "라면", "쫄면", "만두", "우동", "돈까스", "오므라이스",
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
    ("백반", "한식"),
    ("한정식", "한식"),
    ("한식", "한식"),
    ("국밥", "한식"),
    ("찌개", "한식"),
]


def dict_for(*categories: str | None) -> tuple[str | None, list[str]]:
    """업종 문자열들(소 → 중 → 대 순)로 맞는 사전을 고릅니다. 없으면 (None, [])."""
    for cat in categories:
        if not cat:
            continue
        for keyword, key in _KEYWORDS:
            if keyword in cat:
                return key, MENU_DICT[key]
    return None, []


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
            return w
        scored.append((d, w, 1 - d / max(len(clean), len(wc))))
    scored.sort()
    best_d, best, sim = scored[0]
    if sim < min_similarity:
        return None
    if len(scored) > 1 and scored[1][0] == best_d:
        return None
    return best
