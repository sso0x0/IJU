"""발음 연습 채점. 기기 음성인식 결과(transcript)를 목표 문장과 어절 단위로 비교합니다.

음성인식은 '600그램'을 '600g'이나 '육백 그램'으로 받아 적기도 해서,
비교 전에 숫자·단위·띄어쓰기를 같은 모양으로 맞춥니다.
"""

import re
from dataclasses import dataclass
from difflib import SequenceMatcher

_DIGITS = "영일이삼사오육칠팔구"
_UNITS = [(10000, "만"), (1000, "천"), (100, "백"), (10, "십")]
_UNIT_WORDS = [("kg", "킬로그램"), ("g", "그램"), ("ml", "밀리리터"), ("l", "리터")]


def _sino(n: int) -> str:
    """정수를 한자어 수사로 읽습니다. 600 → 육백, 1500 → 천오백."""
    if n == 0:
        return "영"
    out = ""
    for value, name in _UNITS:
        q, n = divmod(n, value)
        if q:
            out += ("" if q == 1 else _sino(q)) + name
    if n:
        out += _DIGITS[n]
    return out


def _normalize_word(word: str) -> str:
    w = word.lower()
    w = re.sub(r"[^\w]", "", w)  # 문장부호 제거
    for unit, name in _UNIT_WORDS:
        w = re.sub(rf"(\d)\s*{unit}\b", rf"\1{name}", w)
    return re.sub(r"\d+", lambda m: _sino(int(m.group())), w)


def _words(sentence: str) -> list[str]:
    # '600 그램'처럼 숫자와 단위가 떨어진 경우를 붙여서 한 어절로 봅니다.
    sentence = re.sub(r"(\d)\s+(?=[가-힣a-zA-Z])", r"\1", sentence)
    return [w for w in sentence.split() if _normalize_word(w)]


@dataclass
class Score:
    score: int
    wrong_words: list[str]  # 사용자가 말한 어절 중 틀린 것 (화면에 그대로 표시)
    pairs: list[tuple[str, str]]  # (말한 어절, 원래 어절). 말하지 않은 어절은 ("", 원래)


def _index(words: list[str]) -> tuple[str, list[int]]:
    """정규화한 어절을 이어 붙인 글자열과, 글자마다 몇 번째 어절인지 표시한 목록."""
    text, owner = "", []
    for i, w in enumerate(words):
        n = _normalize_word(w)
        text += n
        owner += [i] * len(n)
    return text, owner


def score(transcript: str, target: str) -> Score:
    said = _words(transcript)
    want = _words(target)
    said_text, said_owner = _index(said)
    want_text, want_owner = _index(want)

    # 띄어쓰기를 무시하고 글자 단위로 맞춥니다 (음성인식 띄어쓰기는 들쭉날쭉함).
    matcher = SequenceMatcher(None, said_text, want_text, autojunk=False)
    value = round(matcher.ratio() * 100)

    wrong_idx: list[int] = []
    pairs: list[tuple[str, str]] = []
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        got = sorted(set(said_owner[i1:i2]))
        exp = sorted(set(want_owner[j1:j2]))
        if not exp and j1 < len(want_owner):  # 글자가 더 들어간 경우: 붙어 있는 원래 어절
            exp = [want_owner[j1]]
        wrong_idx += [i for i in got if i not in wrong_idx]
        pairs.append((" ".join(said[i] for i in got), " ".join(want[j] for j in exp)))

    return Score(
        score=value,
        wrong_words=[said[i] for i in sorted(wrong_idx)],
        pairs=pairs,
    )


def _josa(word: str, with_batchim: str, without: str) -> str:
    last = word[-1] if word else ""
    has = "가" <= last <= "힣" and (ord(last) - 0xAC00) % 28 != 0
    return with_batchim if has else without


def rule_feedback(result: Score) -> str:
    """LLM이 없을 때 쓰는 짧은 한국어 조언."""
    if not result.pairs:
        return "정확해요! 이 문장 그대로 가게에서 말해 보세요."
    if result.score < 30:
        return "잘 들리지 않았어요. ‘정답 듣기’로 들어 보고 천천히 따라 말해 보세요."
    got, exp = result.pairs[0]
    if exp and got:
        return f"‘{got}’ 대신 ‘{exp}’{_josa(exp, '이라고', '라고')} 또렷하게 말해 보세요."
    if exp:
        return f"‘{exp}’{_josa(exp, '을', '를')} 빠뜨렸어요. 천천히 듣고 다시 말해 보세요."
    return f"‘{got}’{_josa(got, '은', '는')} 빼고 말해 보세요."
