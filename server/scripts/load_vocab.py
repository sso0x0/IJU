"""한국어기초사전 전체 내려받기(JSON zip) → vocab, vocab_meanings.

    python scripts/load_vocab.py <전체 내려받기_한국어기초사전_json_*.zip> [--langs ko,en,vi]

기본은 앱이 지원하는 ko, en, vi만 넣습니다. 필리핀어는 사전에 없어 LLM 번역을 씁니다.
"""

import argparse
import json
import zipfile

from _common import as_list, client, feats, upsert

LANG_CODE = {
    "영어": "en", "베트남어": "vi", "타이어": "th", "몽골어": "mn", "인도네시아어": "id",
    "러시아어": "ru", "중국어": "zh", "일본어": "ja", "아랍어": "ar", "프랑스어": "fr", "스페인어": "es",
}
LEVEL = {"초급": 1, "중급": 2, "고급": 3}


def entries(zip_path: str):
    with zipfile.ZipFile(zip_path) as z:
        for name in sorted(z.namelist()):
            if name.endswith(".json"):
                yield from json.load(z.open(name))["LexicalResource"]["Lexicon"]["LexicalEntry"]


def lemma(e) -> str:
    return feats(as_list(e["Lemma"])[0])["writtenForm"]


def vocab_rows(zip_path: str):
    for e in entries(zip_path):
        f = feats(e)
        hn = f.get("homonym_number")
        yield {
            "target_code": int(e["val"]),
            "word": lemma(e),
            "unit": f.get("lexicalUnit", "단어"),
            "homonym_no": int(hn) if hn not in (None, "") else None,
            "pos": f.get("partOfSpeech") or None,
            "level": LEVEL.get(f.get("vocabularyLevel")),
            "semantic_category": f.get("semanticCategory") or None,
        }


def fetch_ids() -> dict[tuple[int, str], int]:
    c = client()
    ids, start, page = {}, 0, 1000
    while True:
        data = c.table("vocab").select("id,target_code,word").range(start, start + page - 1).execute().data
        for r in data:
            ids[(r["target_code"], r["word"])] = r["id"]
        if len(data) < page:
            return ids
        start += page


def meaning_rows(zip_path: str, ids: dict, langs: set[str]):
    seen = set()
    for r in _meaning_rows(zip_path, ids, langs):
        key = (r["vocab_id"], r["sense_no"], r["language"])
        if key not in seen:  # 한 배치에 같은 키가 두 번 있으면 upsert가 실패합니다
            seen.add(key)
            yield r


def _meaning_rows(zip_path: str, ids: dict, langs: set[str]):
    for e in entries(zip_path):
        vid = ids[(int(e["val"]), lemma(e))]
        for i, s in enumerate(as_list(e.get("Sense")), start=1):
            if "ko" in langs:
                d = feats(s).get("definition")
                if d:
                    yield {"vocab_id": vid, "sense_no": i, "language": "ko", "lemma": None, "definition": d}
            for q in as_list(s.get("Equivalent")):
                qf = feats(q)
                code = LANG_CODE.get(qf.get("language"))
                if code in langs:
                    yield {
                        "vocab_id": vid, "sense_no": i, "language": code,
                        "lemma": (qf.get("lemma") or "").strip() or None,
                        "definition": (qf.get("definition") or "").strip() or None,
                    }


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("zip")
    ap.add_argument("--langs", default="ko,en,vi")
    a = ap.parse_args()
    upsert("vocab", vocab_rows(a.zip), "target_code,word")
    upsert("vocab_meanings", meaning_rows(a.zip, fetch_ids(), set(a.langs.split(","))),
           "vocab_id,sense_no,language")
