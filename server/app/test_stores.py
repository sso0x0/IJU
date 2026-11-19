"""영수증 인증 테스트용 가게 (개발자3).

인터넷에서 구한 실제 영수증 사진으로 POST /receipts를 시험하려면, 그 영수증의 사업자번호가
stores에 있어야 합니다(등록 가게 검사). 시연 데이터와 섞이지 않게 따로 두고, 켤 때만 씁니다.

- 메모리 DB(.env에 Supabase 없음): .env에 RECEIPT_TEST_STORES=true → 서버 시작 시 자동 추가
- Supabase: server 폴더에서 python scripts/add_test_stores.py 실행
- 오래된 영수증이 섞여 있으니 테스트 중에는 RECEIPT_VALID_DAYS=3650 도 같이 설정
"""

TEST_STORES = [
    {   # 2019-12-29 영수증, 영수증번호 20191229-01-0051, 12,600원
        "id": "00000000-0000-0000-0000-000000000901",
        "name": "[테스트] 디큐브시티 와플가게",
        "type": "cafe",
        "business_no": "551-88-00317",
        "lat": None,
        "lng": None,
        "qr_code": "IJU-TEST-001",
    },
    {   # 2026-05-19 영수증, NO:23992, 12,000원
        "id": "00000000-0000-0000-0000-000000000902",
        "name": "[테스트] GS25 울산연암타운점",
        "type": "convenience",
        "business_no": "343-13-02259",
        "lat": None,
        "lng": None,
        "qr_code": "IJU-TEST-002",
    },
    {   # 2026-10-12 영수증, 결제 0원(현금)
        "id": "00000000-0000-0000-0000-000000000903",
        "name": "[테스트] 스타벅스 센터필드R점",
        "type": "cafe",
        "business_no": "201-81-21515",
        "lat": None,
        "lng": None,
        "qr_code": "IJU-TEST-003",
    },
]
