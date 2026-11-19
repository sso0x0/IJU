"""AI Hub 소상공인 고객 주문 질의-응답(라벨링 zip들) → phrases.

    python scripts/load_phrases.py <라벨링데이터_train_*.zip> <라벨링데이터_validation_*.zip>

가게에서 직접 말할 만한 손님 발화만 고릅니다: 온라인 쇼핑 표현이 없고 30자 이하.
"""

import csv
import io
import re
import sys
import zipfile

from _common import upsert

CATS = {"음식점": "restaurant", "카페": "cafe", "슈퍼": "mart", "식품": None}
MEAT = re.compile(r"고기|삼겹|목살|등심|안심|앞다리|뒷다리|갈비|정육|국거리|불고기|한우|한돈|돼지|소고기|차돌|양지|사태|항정|수육|보쌈")
SIDE = re.compile(r"반찬|나물|장아찌|젓갈|김치|무침|조림|볶음")
SHOP = re.compile(r"배송|택배|송장|주문번호|반품|교환|환불|쿠폰|적립|로그인|앱|사이트|결제창|입금|출고|도착|배달|링크|홈페이지|리뷰"
                  r"|보내|보낼|발송|착불|온라인|주문서|고객서비스|상담")
# 가게 안에서 쓰는 의도만: 제품 문의, 주문, 포장, 결제
INTENT = re.compile(r"^(제품_|주문_제품|주문_일반|포장_|결제_)")
SLOTS = {"상품명": "product", "수량": "quantity", "가격": "price", "크기": "size"}
MAX_LEN = 30


def store_type(cat: str, text: str) -> str | None:
    if cat in ("슈퍼", "식품"):
        if MEAT.search(text):
            return "butcher"
        if SIDE.search(text):
            return "side_dish"
    return CATS.get(cat)


def rows(zip_paths: list[str]):
    seen = set()
    for p in zip_paths:
        with zipfile.ZipFile(p) as z:
            for name in z.namelist():
                if name.split("_")[0] not in CATS:
                    continue
                for r in csv.DictReader(io.StringIO(z.read(name).decode("utf-8-sig"))):
                    text = " ".join(r["발화문"].split())
                    if (r["발화자"] != "c" or len(text) > MAX_LEN or SHOP.search(text)
                            or not INTENT.match(r["인텐트"])):
                        continue
                    st = store_type(r["카테고리"], text)
                    if not st or (st, text) in seen:
                        continue
                    seen.add((st, text))
                    slots = {k: [v for v in r[col].split("|") if v] for col, k in SLOTS.items() if r[col]}
                    yield {
                        "text": text,
                        "store_type": st,
                        "intent": r["인텐트"] or None,
                        "slots": slots,
                        "source": "aihub_102",
                    }


if __name__ == "__main__":
    upsert("phrases", rows(sys.argv[1:]), "store_type,text")
