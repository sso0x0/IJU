"""영수증 테스트용 가게를 Supabase stores에 넣습니다 (개발자3). 다시 실행해도 중복되지 않아요.

    python scripts/add_test_stores.py

테스트가 끝나면 Supabase SQL Editor에서 지우세요 (그 가게로 인증한 receipts·coupons가 있으면 먼저 지워야 함):
    delete from coupons where store_id in (select id from stores where qr_code like 'IJU-TEST-%');
    delete from receipts where store_id in (select id from stores where qr_code like 'IJU-TEST-%');
    delete from stores where qr_code like 'IJU-TEST-%';
"""

from _common import upsert

from app.test_stores import TEST_STORES

if __name__ == "__main__":
    upsert("stores", TEST_STORES, "business_no")
