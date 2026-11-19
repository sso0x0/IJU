"""상가(상권)정보 CSV(시도별) → places.

    python scripts/load_places.py <소상공인시장진흥공단_상가(상권)정보_강원_202609.csv> [기준일 2026-09-30]
"""

import csv
import sys

from _common import upsert

# 상권업종 소분류코드 → 앱 업종 코드 (missions.store_type과 같은 값)
SMALL_TO_TYPE = {
    "G20503": "butcher",     # 정육점
    "G20509": "side_dish",   # 반찬/식료품
    "G20404": "mart",        # 슈퍼마켓
    "G20405": "mart",        # 편의점
    "G20506": "produce",     # 채소/과일
    "G20505": "fish",        # 수산물
    "I21201": "cafe",        # 카페
    "I21001": "bakery",      # 빵/도넛
    "G21501": "pharmacy",    # 약국
}
NOT_RESTAURANT_MID = {"주점"}  # 음식 대분류 중 식당 미션에 맞지 않는 곳


def store_type(row: dict) -> str | None:
    t = SMALL_TO_TYPE.get(row["상권업종소분류코드"])
    if t:
        return t
    if row["상권업종대분류명"] == "음식" and row["상권업종중분류명"].strip() not in NOT_RESTAURANT_MID:
        return "restaurant"
    return None


def num(s: str) -> float | None:
    try:
        return float(s)
    except ValueError:
        return None


def rows(path: str, data_date: str):
    with open(path, encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            yield {
                "id": r["상가업소번호"],
                "name": r["상호명"],
                "branch": r["지점명"] or None,
                "category_large": r["상권업종대분류명"],
                "category_mid": r["상권업종중분류명"].strip(),
                "category_small": r["상권업종소분류명"],
                "category_small_code": r["상권업종소분류코드"],
                "store_type": store_type(r),
                "sido": r["시도명"],
                "sigungu": r["시군구명"],
                "dong": r["행정동명"] or None,
                "road_address": r["도로명주소"] or None,
                "lat": num(r["위도"]),
                "lng": num(r["경도"]),
                "data_date": data_date,
            }


if __name__ == "__main__":
    upsert("places", rows(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "2026-09-30"), "id")
