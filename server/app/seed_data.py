"""메모리 DB용 시연 데이터. supabase/seed.sql과 같은 내용을 유지합니다."""

STORE_ID = "00000000-0000-0000-0000-000000000001"

SEED: dict[str, list[dict]] = {
    "stores": [
        {
            "id": STORE_ID,
            "name": "홍천 한식당",
            "type": "restaurant",
            "business_no": "123-45-67890",
            "lat": 37.6970,
            "lng": 127.8888,
            "qr_code": "IJU-STORE-001",
        }
    ],
    "menu_items": [
        {
            "id": "00000000-0000-0000-0000-000000000101",
            "store_id": STORE_ID,
            "name": "김치찌개",
            "price": 9000,
            "unit": "1인분",
            "options": ["1인분", "2인분", "덜 맵게", "보통으로"],
        },
        {
            "id": "00000000-0000-0000-0000-000000000102",
            "store_id": STORE_ID,
            "name": "제육볶음",
            "price": 10000,
            "unit": "1인분",
            "options": ["1인분", "2인분", "덜 맵게", "보통으로"],
        },
        {
            "id": "00000000-0000-0000-0000-000000000103",
            "store_id": STORE_ID,
            "name": "삼겹살",
            "price": 15000,
            "unit": "1인분",
            "options": ["1인분", "2인분", "3인분"],
        },
    ],
    "missions": [
        {
            "id": "00000000-0000-0000-0000-000000000201",
            "title": "식당에서 삼겹살 2인분 주문하기",
            "store_type": "restaurant",
            "target_pattern": "[메뉴] [양] 주세요",
            "level": 1,
            "reward_points": 100,
        },
        {
            "id": "00000000-0000-0000-0000-000000000202",
            "title": "식당에서 김치찌개 돼지고기 빼고 주문하기",
            "store_type": "restaurant",
            "target_pattern": "[메뉴] 주세요. [재료]는 빼 주세요",
            "level": 1,
            "reward_points": 100,
        },
        {
            "id": "00000000-0000-0000-0000-000000000203",
            "title": "반찬가게에서 반찬 두 가지 사기",
            "store_type": "side_dish",
            "target_pattern": "[반찬] [양] 주세요",
            "level": 2,
            "reward_points": 150,
        },
    ],
}


# 개발자3: 인터넷 영수증 사진 테스트용 가게. .env에 RECEIPT_TEST_STORES=true일 때만 추가 (app/test_stores.py)
from .config import settings  # noqa: E402
from .test_stores import TEST_STORES  # noqa: E402

if settings.receipt_test_stores:
    SEED["stores"] = SEED["stores"] + TEST_STORES
