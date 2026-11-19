"""AI Hub 교육용 아시아어 사용자 한국어 음성(043, VL_pronunciation_lab.zip) → pron_error_stats.

    python scripts/load_pron_errors.py <VL_pronunciation_lab.zip>

모국어 × 오류 유형 × 음소 × 어절별 오류 태그 수를 집계합니다. 음성 원본은 올리지 않습니다.
"""

import collections
import json
import sys
import zipfile

from _common import upsert

# 파일명의 국가·언어 코드 → 앱 언어 코드. 나머지는 소문자로 그대로 씁니다.
LANG = {"VI": "vi", "TL": "fil"}
SOURCE = "aihub_71479"


def overlap(a0, a1, b0, b1):
    return max(0.0, min(a1, b1) - max(a0, b0))


def best(items, s, e):
    it = max(items, key=lambda x: overlap(s, e, x["start"], x["end"]), default=None)
    return it if it and overlap(s, e, it["start"], it["end"]) > 0 else None


def rows(path: str):
    counts = collections.Counter()
    with zipfile.ZipFile(path) as z:
        for n in z.namelist():
            if not n.endswith(".json"):
                continue
            code = n.rsplit("/", 1)[-1].split("-")[3]
            lang = LANG.get(code, code.lower())
            ph = json.loads(z.read(n).decode("utf-8-sig"))["RecordingMetadata"]["phonemic"]
            for t in ph.get("error_tags") or []:
                p = best(ph.get("phones", []), t["start"], t["end"])
                w = best(ph.get("words", []), t["start"], t["end"])
                counts[(lang, t["error_tag"], p["phone"] if p else "", w["word"] if w else "")] += 1
    for (lang, tag, phone, word), c in counts.items():
        yield {"source": SOURCE, "native_language": lang, "error_type": tag,
               "phone": phone, "word": word, "count": c}


if __name__ == "__main__":
    upsert("pron_error_stats", rows(sys.argv[1]), "source,native_language,error_type,phone,word")
