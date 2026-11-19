"""메모리 DB용 시연 데이터. supabase/seed.sql과 같은 내용을 유지합니다."""

STORE_ID = "00000000-0000-0000-0000-000000000001"

SEED: dict[str, list[dict]] = {
    # 커뮤니티 시연 글 (메모리 DB에서만). 작성자는 시연용 사용자라 users 표에는 없습니다.
    "community_posts": [
        {
            "id": "10000000-0000-0000-0000-000000000001",
            "user_id": "20000000-0000-0000-0000-000000000001",
            "nickname": "Minh",
            "store_name": "골목식당",
            "sentence": "비빔밥 한 그릇 포장으로 주세요.",
            "meaning": "Cho tôi một tô cơm trộn mang về.",
            "body": "포장도 말해 봤어요! 사장님이 천천히 들어 주셨어요.",
            "lat": 37.6979,
            "lng": 127.8876,
            "created_at": "2026-11-18T12:10:00+09:00",
        },
        {
            "id": "10000000-0000-0000-0000-000000000002",
            "user_id": "20000000-0000-0000-0000-000000000002",
            "nickname": "Sokha",
            "store_name": "새벽반찬",
            "sentence": "두부조림 한 팩 주세요.",
            "meaning": "Cho tôi một hộp đậu phụ kho.",
            "body": "반찬가게에서는 '한 팩'이라고 하면 돼요.",
            "lat": 37.6962,
            "lng": 127.8901,
            "created_at": "2026-11-17T18:40:00+09:00",
        },
        {
            "id": "10000000-0000-0000-0000-000000000003",
            "user_id": "20000000-0000-0000-0000-000000000001",
            "nickname": "Minh",
            "store_name": "홍천 한우정육점",
            "sentence": "국물에 고기 들어가요?",
            "meaning": "Trong nước dùng có thịt không?",
            "body": "할랄이라 꼭 물어봐요. 이 문장 쓰기 좋아요.",
            "lat": 37.6970,
            "lng": 127.8888,
            "created_at": "2026-11-15T11:05:00+09:00",
        },
    ],
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

