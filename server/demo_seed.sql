-- =====================================================================
-- IJU 시연용 데이터 (사용자 데이터 테이블 12개 × 15행)
--   대상: users, stores, menu_items, missions, user_missions, attempts,
--         receipts, coupons, review_cards, order_places, community_posts, follows
--   제외: places, vocab, vocab_meanings, phrases, phrase_templates,
--         pron_error_stats, recipes (이미 공공데이터로 채워진 참조 테이블)
--
-- * 모든 시연 행은 id가 'd0000000-'으로 시작합니다. 맨 앞에서 이전 시연 데이터를
--   지우고 다시 넣으므로 여러 번 실행해도 됩니다. 기존 실제 데이터는 건드리지 않습니다.
-- * 시연 계정 로그인: 아이디 demo01 ~ demo15 / 비밀번호 demo1234
-- * Supabase SQL Editor에 통째로 붙여 넣고 Run 하세요.
-- =====================================================================
begin;

-- ---------- 0. 이전 시연 데이터 정리 (자식 → 부모 순) ----------
delete from follows         where follower_id::text like 'd0000000-%' or followee_id::text like 'd0000000-%';
delete from community_posts where id::text like 'd0000000-%' or user_id::text like 'd0000000-%';
delete from order_places    where id::text like 'd0000000-%' or user_id::text like 'd0000000-%';
delete from review_cards    where id::text like 'd0000000-%' or user_id::text like 'd0000000-%';
delete from coupons         where id::text like 'd0000000-%' or user_id::text like 'd0000000-%';
delete from receipts        where id::text like 'd0000000-%' or user_id::text like 'd0000000-%';
delete from attempts        where id::text like 'd0000000-%' or user_id::text like 'd0000000-%';
delete from user_missions   where id::text like 'd0000000-%' or user_id::text like 'd0000000-%';
delete from missions        where id::text like 'd0000000-%';
delete from menu_items      where id::text like 'd0000000-%' or store_id::text like 'd0000000-%';
delete from stores          where id::text like 'd0000000-%';
delete from users           where id::text like 'd0000000-%';

-- id 규칙: d0000000-0000-0000-00TT-0000000000NN  (TT = 테이블 번호, NN = 01~15)

-- ---------- 1. users ----------
insert into users (id, nickname, language, residence_type, level, points, login_id, email,
                   password_hash, auth_provider, terms_version, terms_agreed_at, privacy_agreed_at,
                   diets, share_map, created_at)
select ('d0000000-0000-0000-0001-0000000000' || lpad(n::text, 2, '0'))::uuid,
       v.nickname, v.lang, v.res, v.lvl, v.pts,
       'demo' || lpad(n::text, 2, '0'),
       'demo' || lpad(n::text, 2, '0') || '@iju.test',
       'pbkdf2_sha256$200000$1a2b3c4d5e6f708192a3b4c5d6e7f801$1d14392413462c729fe980d73abeaf47dfb59fa8b9bc779dfcf2db6ac6ad8700',
       'local', '2026-11', now() - (n || ' days')::interval, now() - (n || ' days')::interval,
       v.diets, v.share, now() - (n * 2 || ' days')::interval
from (values
  (1,  '린',       'vi',  'marriage', 3, 1250, '{}'::text[],          true),
  (2,  '마리아',   'fil', 'worker',   2,  680, '{}'::text[],          true),
  (3,  '소피아',   'km',  'marriage', 1,  150, '{hindu}'::text[],     false),
  (4,  '응옥',     'vi',  'student',  2,  520, '{}'::text[],          true),
  (5,  'John',     'en',  'worker',   1,  100, '{vegan}'::text[],     false),
  (6,  '투이',     'vi',  'worker',   3, 1430, '{}'::text[],          true),
  (7,  '안젤라',   'fil', 'marriage', 2,  760, '{}'::text[],          true),
  (8,  '다라',     'km',  'worker',   1,  200, '{}'::text[],          false),
  (9,  'Ahmed',    'en',  'student',  2,  450, '{islam}'::text[],     true),
  (10, '하',       'vi',  'marriage', 4, 2100, '{}'::text[],          true),
  (11, '조이',     'fil', 'student',  1,   50, '{pesco}'::text[],     false),
  (12, '보파',     'km',  'marriage', 2,  610, '{}'::text[],          true),
  (13, '탄',       'vi',  'worker',   1,  300, '{}'::text[],          true),
  (14, 'Priya',    'en',  'worker',   3, 1180, '{lactoOvo}'::text[],  true),
  (15, '미나',     'vi',  'student',  1,    0, '{}'::text[],          false)
) as v(n, nickname, lang, res, lvl, pts, diets, share);

-- ---------- 2. stores (홍천·춘천 일대) ----------
insert into stores (id, name, type, business_no, lat, lng, qr_code)
select ('d0000000-0000-0000-0002-0000000000' || lpad(n::text, 2, '0'))::uuid,
       v.name, v.type, '900-00-' || lpad((10000 + n)::text, 5, '0'),
       v.lat, v.lng, 'IJU-DEMO-' || lpad(n::text, 3, '0')
from (values
  (1,  '홍천 꽃등심 정육점', 'butcher',     37.6972, 127.8885),
  (2,  '희망 반찬가게',      'side_dish',   37.6951, 127.8902),
  (3,  '할머니 순두부',      'restaurant',  37.6988, 127.8861),
  (4,  '카페 모닝',          'cafe',        37.6940, 127.8879),
  (5,  '행복마트 편의점',    'convenience', 37.6965, 127.8920),
  (6,  '춘천 닭갈비집',      'restaurant',  37.8813, 127.7298),
  (7,  '명동 정육마트',      'butcher',     37.8790, 127.7310),
  (8,  '엄마손 반찬',        'side_dish',   37.8825, 127.7275),
  (9,  '소양강 막국수',      'restaurant',  37.8851, 127.7260),
  (10, '커피 한 잔',         'cafe',        37.8802, 127.7333),
  (11, '24시 편의점 홍천점', 'convenience', 37.6930, 127.8851),
  (12, '김밥천국 홍천점',    'restaurant',  37.6978, 127.8897),
  (13, '시장 한우 정육',     'butcher',     37.6959, 127.8869),
  (14, '정다운 반찬',        'side_dish',   37.8838, 127.7289),
  (15, '빵굽는 카페',        'cafe',        37.6947, 127.8912)
) as v(n, name, type, lat, lng);

-- ---------- 3. menu_items (가게마다 1개) ----------
insert into menu_items (id, store_id, name, price, unit, options)
select ('d0000000-0000-0000-0003-0000000000' || lpad(n::text, 2, '0'))::uuid,
       ('d0000000-0000-0000-0002-0000000000' || lpad(n::text, 2, '0'))::uuid,
       v.name, v.price, v.unit, v.opts::jsonb
from (values
  (1,  '한우 등심',     9800, '100g',  '["구이용", "300g", "600g"]'),
  (2,  '멸치볶음',      4000, '1팩',   '["작은 팩", "큰 팩"]'),
  (3,  '순두부찌개',    9000, '1인분', '["순한 맛", "보통 맛", "매운 맛"]'),
  (4,  '아이스 아메리카노', 3000, '1잔', '["톨", "그란데", "샷 추가"]'),
  (5,  '삼각김밥',      1500, '1개',   '["참치마요", "전주비빔"]'),
  (6,  '닭갈비',       14000, '1인분', '["2인분", "3인분", "치즈 추가"]'),
  (7,  '돼지 앞다리살', 1800, '100g',  '["수육용", "찌개용", "500g"]'),
  (8,  '배추김치',      8000, '1kg',   '["500g", "1kg"]'),
  (9,  '물막국수',      9000, '1그릇', '["곱빼기", "덜 맵게"]'),
  (10, '카페라테',      4500, '1잔',   '["따뜻하게", "차갑게", "오트 우유"]'),
  (11, '컵라면',        1300, '1개',   '["매운 맛", "순한 맛"]'),
  (12, '참치김밥',      4500, '1줄',   '["포장", "먹고 가기"]'),
  (13, '한우 국거리',   6500, '100g',  '["국거리", "장조림용", "300g"]'),
  (14, '잡채',          6000, '1팩',   '["작은 팩", "큰 팩"]'),
  (15, '소금빵',        3200, '1개',   '["포장", "데워 주세요"]')
) as v(n, name, price, unit, opts);

-- ---------- 4. missions ----------
insert into missions (id, title, store_type, target_pattern, level, reward_points)
select ('d0000000-0000-0000-0004-0000000000' || lpad(n::text, 2, '0'))::uuid,
       v.title, v.st, v.pat, v.lvl, v.pts
from (values
  (1,  '정육점에서 등심 구이용으로 사기',      'butcher',     '[품목] [무게] [용도]으로 주세요', 1, 100),
  (2,  '반찬가게에서 멸치볶음 사기',           'side_dish',   '[반찬] [양] 주세요',             1, 100),
  (3,  '식당에서 순두부찌개 순하게 주문하기',  'restaurant',  '[메뉴] [맵기]로 주세요',         1, 100),
  (4,  '카페에서 아이스 아메리카노 주문하기',  'cafe',        '[음료] [크기]로 주세요',         1, 100),
  (5,  '편의점에서 봉투 달라고 하기',          'convenience', '봉투 [수량] 주세요',             1, 80),
  (6,  '닭갈비 2인분 주문하기',                'restaurant',  '[메뉴] [인분] 주세요',           2, 150),
  (7,  '정육점에서 수육용 고기 사기',          'butcher',     '[품목] [용도]으로 [무게] 주세요', 2, 150),
  (8,  '반찬가게에서 김치 1kg 사기',           'side_dish',   '[반찬] [양] 주세요',             2, 150),
  (9,  '막국수 곱빼기로 주문하기',             'restaurant',  '[메뉴] [옵션]로 주세요',         2, 150),
  (10, '카페에서 오트 우유로 바꾸기',          'cafe',        '[음료] [옵션]으로 바꿔 주세요',  2, 150),
  (11, '편의점에서 컵라면 물 붓기 물어보기',   'convenience', '[장소] 어디예요?',               2, 120),
  (12, '김밥 포장 주문하기',                   'restaurant',  '[메뉴] [수량] 포장해 주세요',    1, 100),
  (13, '정육점에서 국거리 고기 사기',          'butcher',     '[품목] [용도]으로 [무게] 주세요', 3, 200),
  (14, '반찬 두 가지 같이 사기',               'side_dish',   '[반찬]이랑 [반찬] 주세요',       3, 200),
  (15, '빵 데워 달라고 부탁하기',              'cafe',        '[빵] 데워 주세요',               3, 200)
) as v(n, title, st, pat, lvl, pts);

-- ---------- 5. user_missions (사용자 n ↔ 미션 n) ----------
insert into user_missions (id, user_id, mission_id, status, best_step, completed_at)
select ('d0000000-0000-0000-0005-0000000000' || lpad(n::text, 2, '0'))::uuid,
       ('d0000000-0000-0000-0001-0000000000' || lpad(n::text, 2, '0'))::uuid,
       ('d0000000-0000-0000-0004-0000000000' || lpad(n::text, 2, '0'))::uuid,
       case when n % 3 = 0 then 'completed' else 'in_progress' end,
       case when n % 3 = 0 then 4 else 1 + n % 3 end,
       case when n % 3 = 0 then now() - (n || ' hours')::interval end
from generate_series(1, 15) n;

-- ---------- 6. attempts ----------
insert into attempts (id, user_id, mission_id, step, sentence, score, created_at)
select ('d0000000-0000-0000-0006-0000000000' || lpad(n::text, 2, '0'))::uuid,
       ('d0000000-0000-0000-0001-0000000000' || lpad(n::text, 2, '0'))::uuid,
       ('d0000000-0000-0000-0004-0000000000' || lpad(n::text, 2, '0'))::uuid,
       1 + (n % 4), v.sentence, 60 + (n * 7) % 40,
       now() - (n || ' hours')::interval
from (values
  (1,  '한우 등심 300그램 구이용으로 주세요.'),
  (2,  '멸치볶음 한 팩 주세요.'),
  (3,  '순두부찌개 순한 맛으로 주세요.'),
  (4,  '아이스 아메리카노 톨 사이즈로 주세요.'),
  (5,  '봉투 하나 주세요.'),
  (6,  '닭갈비 2인분 주세요.'),
  (7,  '앞다리살 수육용으로 500그램 주세요.'),
  (8,  '배추김치 1킬로 주세요.'),
  (9,  '물막국수 곱빼기로 주세요.'),
  (10, '카페라테 오트 우유로 바꿔 주세요.'),
  (11, '뜨거운 물 어디예요?'),
  (12, '참치김밥 두 줄 포장해 주세요.'),
  (13, '한우 국거리용으로 300그램 주세요.'),
  (14, '잡채랑 멸치볶음 주세요.'),
  (15, '소금빵 데워 주세요.')
) as v(n, sentence);

-- ---------- 7. receipts ----------
insert into receipts (id, user_id, store_id, image_hash, business_no, receipt_no, amount, issued_at, verified, created_at)
select ('d0000000-0000-0000-0007-0000000000' || lpad(n::text, 2, '0'))::uuid,
       ('d0000000-0000-0000-0001-0000000000' || lpad(n::text, 2, '0'))::uuid,
       ('d0000000-0000-0000-0002-0000000000' || lpad(n::text, 2, '0'))::uuid,
       md5('iju-demo-receipt-' || n),
       '900-00-' || lpad((10000 + n)::text, 5, '0'),
       'R2611-' || lpad(n::text, 4, '0'),
       (3 + n % 6) * 3000,
       date_trunc('minute', now() - (n || ' days')::interval),
       n % 4 <> 0,
       now() - (n || ' days')::interval
from generate_series(1, 15) n;

-- ---------- 8. coupons ----------
insert into coupons (id, user_id, store_id, value, status, expires_at)
select ('d0000000-0000-0000-0008-0000000000' || lpad(n::text, 2, '0'))::uuid,
       ('d0000000-0000-0000-0001-0000000000' || lpad(n::text, 2, '0'))::uuid,
       ('d0000000-0000-0000-0002-0000000000' || lpad(n::text, 2, '0'))::uuid,
       case when n % 3 = 0 then 2000 else 1000 end,
       case when n % 5 = 0 then 'used' when n % 7 = 0 then 'expired' else 'active' end,
       case when n % 7 = 0 then now() - interval '2 days' else now() + ((10 + n) || ' days')::interval end
from generate_series(1, 15) n;

-- ---------- 9. review_cards ----------
insert into review_cards (id, user_id, sentence, variants, next_review_at, meaning, order_data, score, cleared, created_at, updated_at)
select ('d0000000-0000-0000-0009-0000000000' || lpad(n::text, 2, '0'))::uuid,
       ('d0000000-0000-0000-0001-0000000000' || lpad(n::text, 2, '0'))::uuid,
       v.sentence, '[]'::jsonb,
       now() + ((n % 4) - 1 || ' days')::interval,
       v.meaning,
       jsonb_build_object('menu', v.menu, 'labels', '[[], []]'::jsonb, 'scenario', v.scen, 'menu_meaning', v.mm),
       65 + (n * 5) % 35, n % 4,
       now() - (n || ' days')::interval, now() - (n || ' hours')::interval
from (values
  (1,  '한우 등심 300그램 구이용으로 주세요.', 'Cho tôi 300g thăn bò Hàn để nướng.',          '한우 등심',     'butcher',     'Thăn bò Hàn'),
  (2,  '멸치볶음 한 팩 주세요.',               'Bigyan mo ako ng isang pakete ng dilis.',      '멸치볶음',      'side_dish',   'Pritong dilis'),
  (3,  '순두부찌개 순한 맛으로 주세요.',       'សូមស៊ុបតៅហ៊ូទន់ មិនហឹរ។',                    '순두부찌개',    'restaurant',  'ស៊ុបតៅហ៊ូទន់'),
  (4,  '아이스 아메리카노 톨 사이즈로 주세요.', 'Cho tôi một ly Americano đá cỡ tall.',        '아이스 아메리카노', 'cafe',    'Americano đá'),
  (5,  '봉투 하나 주세요.',                    'One bag, please.',                             '봉투',          'convenience', 'Bag'),
  (6,  '닭갈비 2인분 주세요.',                 'Cho tôi 2 phần gà xào cay.',                   '닭갈비',        'restaurant',  'Gà xào cay'),
  (7,  '앞다리살 수육용으로 500그램 주세요.',  'Bigyan mo ako ng 500g na pork shoulder.',      '돼지 앞다리살', 'butcher',     'Pork shoulder'),
  (8,  '배추김치 1킬로 주세요.',               'សូមគីមឈី ១គីឡូ។',                            '배추김치',      'side_dish',   'គីមឈី'),
  (9,  '물막국수 곱빼기로 주세요.',            'Cold buckwheat noodles, large size, please.', '물막국수',      'restaurant',  'Cold buckwheat noodles'),
  (10, '카페라테 오트 우유로 바꿔 주세요.',    'Cho tôi đổi sang sữa yến mạch.',               '카페라테',      'cafe',        'Cà phê sữa'),
  (11, '뜨거운 물 어디예요?',                  'Saan ang mainit na tubig?',                    '컵라면',        'convenience', 'Cup noodles'),
  (12, '참치김밥 두 줄 포장해 주세요.',        'សូមខ្ចប់គីមបាប់ត្រីធូណា ២។',                  '참치김밥',      'restaurant',  'គីមបាប់ត្រីធូណា'),
  (13, '한우 국거리용으로 300그램 주세요.',    'Cho tôi 300g thịt bò để nấu canh.',            '한우 국거리',   'butcher',     'Thịt bò nấu canh'),
  (14, '잡채랑 멸치볶음 주세요.',              'Japchae and stir-fried anchovies, please.',    '잡채 · 멸치볶음', 'side_dish', 'Japchae, anchovies'),
  (15, '소금빵 데워 주세요.',                  'Hâm nóng bánh mì muối giúp tôi.',              '소금빵',        'cafe',        'Bánh mì muối')
) as v(n, sentence, meaning, menu, scen, mm);

-- ---------- 10. order_places ----------
insert into order_places (id, user_id, store_name, sentence, meaning, address, lat, lng, ordered_at)
select ('d0000000-0000-0000-0010-0000000000' || lpad(n::text, 2, '0'))::uuid,
       rc.user_id, s.name, rc.sentence, rc.meaning,
       case when s.lat > 37.8 then '강원특별자치도 춘천시' else '강원특별자치도 홍천군 홍천읍' end,
       s.lat, s.lng, now() - (n || ' days')::interval
from generate_series(1, 15) n
join review_cards rc on rc.id = ('d0000000-0000-0000-0009-0000000000' || lpad(n::text, 2, '0'))::uuid
join stores s       on s.id  = ('d0000000-0000-0000-0002-0000000000' || lpad(n::text, 2, '0'))::uuid;

-- ---------- 11. community_posts ----------
insert into community_posts (id, user_id, nickname, store_name, sentence, meaning, body, lat, lng, created_at)
select ('d0000000-0000-0000-0011-0000000000' || lpad(n::text, 2, '0'))::uuid,
       u.id, u.nickname, op.store_name, op.sentence, op.meaning, v.body, op.lat, op.lng,
       now() - (n * 5 || ' hours')::interval
from (values
  (1,  '사장님이 천천히 말해 주셔서 성공했어요!'),
  (2,  '멸치볶음 정말 맛있어요. 한 팩이면 3일 먹어요.'),
  (3,  '처음엔 떨렸는데 "순한 맛" 말하니까 바로 알아들으셨어요.'),
  (4,  '톨, 그란데 발음 연습 많이 했어요 ㅎㅎ'),
  (5,  '봉투 달라고 처음 말해 봤어요.'),
  (6,  '닭갈비 2인분이면 둘이 먹기 딱 좋아요.'),
  (7,  '수육용이라고 말하면 알아서 썰어 주세요.'),
  (8,  '김치는 1킬로가 제일 저렴해요.'),
  (9,  '곱빼기 발음이 어려웠는데 통했어요!'),
  (10, '오트 우유로 바꿀 수 있는 카페예요.'),
  (11, '편의점 뜨거운 물은 계산대 옆에 있어요.'),
  (12, '포장해 달라고 하면 단무지도 넣어 주세요.'),
  (13, '국거리 고기로 미역국 끓였어요.'),
  (14, '반찬 두 가지 한 번에 주문 성공!'),
  (15, '소금빵 데워 주니까 훨씬 맛있어요.')
) as v(n, body)
join users u        on u.id  = ('d0000000-0000-0000-0001-0000000000' || lpad(n::text, 2, '0'))::uuid
join order_places op on op.id = ('d0000000-0000-0000-0010-0000000000' || lpad(n::text, 2, '0'))::uuid;

-- ---------- 12. follows (n → n+1, 15 → 1 순환) ----------
insert into follows (follower_id, followee_id, created_at)
select ('d0000000-0000-0000-0001-0000000000' || lpad(n::text, 2, '0'))::uuid,
       ('d0000000-0000-0000-0001-0000000000' || lpad((n % 15 + 1)::text, 2, '0'))::uuid,
       now() - (n || ' days')::interval
from generate_series(1, 15) n;

commit;

-- 확인용
select 'users' t, count(*) from users where id::text like 'd0000000-%'
union all select 'stores', count(*) from stores where id::text like 'd0000000-%'
union all select 'menu_items', count(*) from menu_items where id::text like 'd0000000-%'
union all select 'missions', count(*) from missions where id::text like 'd0000000-%'
union all select 'user_missions', count(*) from user_missions where id::text like 'd0000000-%'
union all select 'attempts', count(*) from attempts where id::text like 'd0000000-%'
union all select 'receipts', count(*) from receipts where id::text like 'd0000000-%'
union all select 'coupons', count(*) from coupons where id::text like 'd0000000-%'
union all select 'review_cards', count(*) from review_cards where id::text like 'd0000000-%'
union all select 'order_places', count(*) from order_places where id::text like 'd0000000-%'
union all select 'community_posts', count(*) from community_posts where id::text like 'd0000000-%'
union all select 'follows', count(*) from follows where follower_id::text like 'd0000000-%';
