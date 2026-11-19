-- =====================================================================
-- IJU 시연용 데이터
--   대상: users, stores, menu_items, missions, user_missions, attempts,
--         receipts, coupons, review_cards, order_places, community_posts, follows
--   제외: places, vocab, vocab_meanings, phrases, phrase_templates,
--         pron_error_stats, recipes (이미 공공데이터로 채워진 참조 테이블)
--
-- * 시연 사용자 n(1~15)은 가게 n의 미션 n을 합니다. 앱 흐름 그대로 데이터가 이어져요.
--     문장 연습(복습 카드) → 실전 주문 1~3단계(attempts) → 영수증 인증(receipts)
--     → 쿠폰 2,000원 30일(coupons) + 미션 완료·포인트(user_missions, users.points)
--     → 내 지도(order_places) → 커뮤니티 글(community_posts)
--   n이 3의 배수(3·6·9·12·15)인 사용자는 아직 미션 진행 중이라 영수증·쿠폰·지도·글이 없습니다.
-- * 업종은 앱 시나리오가 있는 restaurant(식당) · side_dish(반찬가게)만 씁니다.
-- * 복습 카드의 문장·뜻·order_data는 앱(ScenarioOrder.toJson)이 만드는 값과 같아서
--   복습 2·3단계(바꿔 말하기·뜻만 보고 말하기)까지 됩니다.
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
delete from coupons         where id::text like 'd0000000-%' or user_id::text like 'd0000000-%' or store_id::text like 'd0000000-%';
delete from receipts        where id::text like 'd0000000-%' or user_id::text like 'd0000000-%' or store_id::text like 'd0000000-%';
delete from attempts        where id::text like 'd0000000-%' or user_id::text like 'd0000000-%' or mission_id::text like 'd0000000-%';
delete from user_missions   where id::text like 'd0000000-%' or user_id::text like 'd0000000-%' or mission_id::text like 'd0000000-%';
delete from missions        where id::text like 'd0000000-%';
delete from menu_items      where id::text like 'd0000000-%' or store_id::text like 'd0000000-%';
delete from stores          where id::text like 'd0000000-%';
delete from users           where id::text like 'd0000000-%';

-- id 규칙: d0000000-0000-0000-00TT-NNNNNNNNNNNN  (TT = 테이블 번호, N = 행 번호)
create temporary table demo on commit drop as
select v.*,
       n % 3 <> 0                          as done,       -- 미션 완료(영수증 인증까지 함)
       case when n % 3 <> 0 then 3 else (n / 3) % 3 end as best,  -- 실전 주문 최고 단계 (0~3)
       date_trunc('minute', now()) - (n || ' days')::interval as t  -- 그날 주문한 시각
from (values
  -- n, 닉네임, 모국어, 체류, 식단·종교,
  --    가게, 업종, 위도, 경도, 메뉴, 가격, 단위, 옵션,
  --    미션 제목, 문장 틀, 레벨, 결제 금액,
  --    문장, 뜻(모국어), order_data, 커뮤니티 글
  (1,  '흐엉',   'vi',  'marriage', '{}'::text[],      true,
       '할머니 김치찌개', 'restaurant', 37.6988, 127.8861, '김치찌개', 9000, '1인분', '["1인분", "2인분", "3인분", "덜 맵게", "보통으로", "아주 맵게"]',
       '식당에서 김치찌개 덜 맵게 주문하기', '[메뉴] [양] [맵기]로 해 주세요', 2, 18000,
       '김치찌개 2인분 덜 맵게 해 주세요.', 'Cho tôi 2 phần canh kim chi ít cay.',
       '{"scenario":"restaurant","menu":"김치찌개","menu_meaning":"canh kim chi","labels":[["2인분"],["덜 맵게"],[],[]]}',
       '"덜 맵게" 말하니까 사장님이 바로 알아들으셨어요!'),
  (2,  '마리아', 'fil', 'worker',   '{}'::text[],      true,
       '희망 반찬가게', 'side_dish', 37.6951, 127.8902, '멸치볶음', 4000, '1팩', '["한 팩", "두 팩", "오천 원어치"]',
       '반찬가게에서 멸치볶음 사기', '[반찬] [양] 주세요', 1, 4000,
       '멸치볶음 한 팩 주세요.', 'Pabili po ng 1 pakete ng ginisang dilis.',
       '{"scenario":"side_dish","menu":"멸치볶음","menu_meaning":"ginisang dilis","labels":[["한 팩"],[]]}',
       '반찬가게에서는 "한 팩"이라고 하면 돼요.'),
  (3,  '소피아', 'km',  'marriage', '{hindu}'::text[], false,
       '홍천 순두부', 'restaurant', 37.6979, 127.8876, '순두부찌개', 9000, '1인분', '["1인분", "2인분", "3인분", "덜 맵게", "보통으로", "아주 맵게"]',
       '식당에서 순두부찌개 덜 맵게 주문하기', '[메뉴] [양] [맵기]로 해 주세요', 2, null,
       '순두부찌개 1인분 덜 맵게 해 주세요.', 'សូមឲ្យខ្ញុំ ១ចាន ស៊ុបតៅហ៊ូទន់ កុំហឹរពេក។',
       '{"scenario":"restaurant","menu":"순두부찌개","menu_meaning":"ស៊ុបតៅហ៊ូទន់","labels":[["1인분"],["덜 맵게"],[],[]]}',
       null),
  (4,  '응옥',   'vi',  'student',  '{}'::text[],      true,
       '춘천 닭갈비집', 'restaurant', 37.8813, 127.7298, '닭갈비', 14000, '1인분', '["1인분", "2인분", "3인분", "덜 맵게", "보통으로", "아주 맵게"]',
       '식당에서 닭갈비 주문하기', '[메뉴] [양] 주세요', 1, 28000,
       '닭갈비 2인분 주세요.', 'Cho tôi 2 phần gà xào cay.',
       '{"scenario":"restaurant","menu":"닭갈비","menu_meaning":"gà xào cay","labels":[["2인분"],[]]}',
       '닭갈비 2인분이면 둘이 먹기 딱 좋아요.'),
  (5,  'John',   'en',  'worker',   '{vegan}'::text[], false,
       '엄마손 반찬', 'side_dish', 37.8825, 127.7275, '두부조림', 5000, '1팩', '["한 팩", "두 팩", "오천 원어치"]',
       '반찬가게에서 두부조림 사기', '[반찬] [양] 주세요', 1, 5000,
       '두부조림 한 팩 주세요.', '1 pack of braised tofu, please.',
       '{"scenario":"side_dish","menu":"두부조림","menu_meaning":"braised tofu","labels":[["한 팩"],[]]}',
       'Vegan friendly side dish. "한 팩" worked!'),
  (6,  '투이',   'vi',  'worker',   '{}'::text[],      true,
       '홍천 기사식당', 'restaurant', 37.6965, 127.8920, '제육볶음', 10000, '1인분', '["1인분", "2인분", "3인분", "덜 맵게", "보통으로", "아주 맵게"]',
       '식당에서 제육볶음 덜 맵게 주문하기', '[메뉴] [양] [맵기]로 해 주세요', 2, null,
       '제육볶음 1인분 덜 맵게 해 주세요.', 'Cho tôi 1 phần thịt heo xào cay ít cay.',
       '{"scenario":"restaurant","menu":"제육볶음","menu_meaning":"thịt heo xào cay","labels":[["1인분"],["덜 맵게"]]}',
       null),
  (7,  '안젤라', 'fil', 'marriage', '{}'::text[],      true,
       '시골 된장', 'restaurant', 37.8790, 127.7310, '된장찌개', 8000, '1인분', '["1인분", "2인분", "3인분", "덜 맵게", "보통으로", "아주 맵게"]',
       '식당에서 된장찌개 주문하기', '[메뉴] [양] 주세요', 1, 16000,
       '된장찌개 2인분 주세요.', 'Pabili po ng 2 order ng Sabaw ng doenjang.',
       '{"scenario":"restaurant","menu":"된장찌개","menu_meaning":"Sabaw ng doenjang","labels":[["2인분"],[],[],[]]}',
       '된장찌개 2인분 주문 성공! 사장님이 천천히 말해 주셨어요.'),
  (8,  '다라',   'km',  'worker',   '{}'::text[],      false,
       '정다운 반찬', 'side_dish', 37.8838, 127.7289, '배추김치', 5000, '500g', '["한 팩", "두 팩", "오천 원어치"]',
       '반찬가게에서 김치 오천 원어치 사기', '[반찬] [가격]어치 주세요', 2, 5000,
       '배추김치 오천 원어치 주세요.', 'សូមឲ្យខ្ញុំ តម្លៃ ៥០០០ វ៉ុន គីមឈី។',
       '{"scenario":"side_dish","menu":"배추김치","menu_meaning":"គីមឈី","labels":[["오천 원어치"],[]]}',
       '"오천 원어치"라고 하면 금액만큼 담아 주세요.'),
  (9,  'Ahmed',  'en',  'student',  '{islam}'::text[], true,
       '소양강 막국수', 'restaurant', 37.8851, 127.7260, '물막국수', 9000, '1그릇', '["1인분", "2인분", "3인분"]',
       '식당에서 막국수 주문하기', '[메뉴] [양] 주세요', 1, null,
       '물막국수 1인분 주세요.', '1 serving of cold buckwheat noodles, please.',
       '{"scenario":"restaurant","menu":"물막국수","menu_meaning":"cold buckwheat noodles","labels":[["1인분"],[],[]]}',
       null),
  (10, '하이',   'vi',  'marriage', '{}'::text[],      true,
       '시장 반찬', 'side_dish', 37.6959, 127.8869, '잡채', 6000, '1팩', '["한 팩", "두 팩", "오천 원어치"]',
       '반찬가게에서 반찬 두 가지 사기', '[반찬] [양] [반찬]도 주세요', 3, 16000,
       '잡채 두 팩 콩자반도 주세요.', 'Cho tôi 2 hộp miến trộn thêm đậu đen kho.',
       '{"scenario":"side_dish","menu":"잡채","menu_meaning":"miến trộn","labels":[["두 팩"],["콩자반"]]}',
       '반찬 두 가지 한 번에 주문 성공! "-도"를 붙이면 돼요.'),
  (11, '조이',   'fil', 'student',  '{pesco}'::text[], false,
       '전주 비빔밥', 'restaurant', 37.6978, 127.8897, '비빔밥', 9000, '1인분', '["1인분", "2인분", "3인분", "덜 맵게", "보통으로", "아주 맵게"]',
       '식당에서 비빔밥 주문하기', '[메뉴] [양] 주세요', 1, 9000,
       '비빔밥 1인분 주세요.', 'Pabili po ng 1 order ng Bibimbap.',
       '{"scenario":"restaurant","menu":"비빔밥","menu_meaning":"Bibimbap","labels":[["1인분"],[],[],[]]}',
       '고기 들어가는지 물어보는 문장도 연습했어요.'),
  (12, '보파',   'km',  'marriage', '{}'::text[],      true,
       '행복 반찬', 'side_dish', 37.6947, 127.8912, '장조림', 7000, '1팩', '["한 팩", "두 팩", "오천 원어치"]',
       '반찬가게에서 장조림 사기', '[반찬] [양] 주세요', 1, null,
       '장조림 두 팩 주세요.', 'សូមឲ្យខ្ញុំ ២កញ្ចប់ សាច់គោខ។',
       '{"scenario":"side_dish","menu":"장조림","menu_meaning":"សាច់គោខ","labels":[["두 팩"],[]]}',
       null),
  (13, '탄투',   'vi',  'worker',   '{}'::text[],      true,
       '홍천 숯불구이', 'restaurant', 37.6972, 127.8885, '삼겹살', 15000, '1인분', '["1인분", "2인분", "3인분"]',
       '식당에서 삼겹살 3인분 주문하기', '[메뉴] [양] 주세요', 1, 45000,
       '삼겹살 3인분 주세요.', 'Cho tôi 3 phần thịt ba chỉ.',
       '{"scenario":"restaurant","menu":"삼겹살","menu_meaning":"thịt ba chỉ","labels":[["3인분"]]}',
       '친구들이랑 삼겹살 3인분! 고기는 인분으로 세요.'),
  (14, 'Priya',  'en',  'worker',   '{}'::text[],      true,
       '새벽 반찬', 'side_dish', 37.8802, 127.7333, '오이소박이', 5000, '1팩', '["한 팩", "두 팩", "오천 원어치"]',
       '반찬가게에서 오이소박이랑 깍두기 사기', '[반찬] [양] [반찬]도 주세요', 3, 10000,
       '오이소박이 한 팩 깍두기도 주세요.', '1 pack of stuffed cucumber kimchi and radish kimchi, please.',
       '{"scenario":"side_dish","menu":"오이소박이","menu_meaning":"stuffed cucumber kimchi","labels":[["한 팩"],["깍두기"]]}',
       'Two side dishes in one sentence. Add "-도"!'),
  (15, '미나',   'vi',  'student',  '{}'::text[],      false,
       '김밥나라 홍천점', 'restaurant', 37.6930, 127.8851, '김밥', 3500, '1줄', '["한 줄", "두 줄", "세 줄"]',
       '식당에서 김밥 두 줄 주문하기', '[메뉴] [몇 줄] 주세요', 1, null,
       '김밥 두 줄 주세요.', 'Cho tôi 2 cơm cuộn.',
       '{"scenario":"restaurant","menu":"김밥","menu_meaning":"cơm cuộn","labels":[["두 줄"],[],[]]}',
       null)
) as v(n, nickname, lang, res, diets, share,
       store, stype, lat, lng, menu, price, unit, opts,
       title, pattern, lvl, amount,
       sentence, meaning, order_data, body);

-- 미션 레벨별 보상 (missions.py REWARD_BY_LEVEL)
create temporary table demo_reward on commit drop as
select * from (values (1, 100), (2, 150), (3, 200)) as r(lvl, pts);

-- ---------- 1. users (포인트 = 완료한 미션 보상, 레벨 = 미션 레벨 이상) ----------
insert into users (id, nickname, language, residence_type, level, points, login_id, email,
                   password_hash, auth_provider, terms_version, terms_agreed_at, privacy_agreed_at,
                   diets, share_map, created_at)
select ('d0000000-0000-0000-0001-' || lpad(d.n::text, 12, '0'))::uuid,
       d.nickname, d.lang, d.res,
       least(d.lvl + case when d.done and d.n % 2 = 0 then 1 else 0 end, 3),
       case when d.done then r.pts else 0 end,
       'demo' || lpad(d.n::text, 2, '0'),
       'demo' || lpad(d.n::text, 2, '0') || '@iju.test',
       -- 비밀번호 demo1234 (app/auth.py hash_password 형식)
       'pbkdf2_sha256$200000$1a2b3c4d5e6f708192a3b4c5d6e7f801$1d14392413462c729fe980d73abeaf47dfb59fa8b9bc779dfcf2db6ac6ad8700',
       'local', '2026-11-19', d.t - interval '14 days', d.t - interval '14 days',
       d.diets, d.share, d.t - interval '14 days'
from demo d join demo_reward r on r.lvl = d.lvl;

-- ---------- 2. stores (홍천·춘천 일대, 사장님 확인 코드 = 사업자번호 뒤 4자리) ----------
insert into stores (id, name, type, business_no, lat, lng, qr_code)
select ('d0000000-0000-0000-0002-' || lpad(n::text, 12, '0'))::uuid,
       store, stype, '900-00-' || lpad((10000 + n)::text, 5, '0'),
       lat, lng, 'IJU-DEMO-' || lpad(n::text, 3, '0')
from demo;

-- ---------- 3. menu_items (옵션 = 앱 문장 만들기 카드 이름) ----------
insert into menu_items (id, store_id, name, price, unit, options)
select ('d0000000-0000-0000-0003-' || lpad(n::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0002-' || lpad(n::text, 12, '0'))::uuid,
       menu, price, unit, opts::jsonb
from demo;

-- ---------- 4. missions ----------
insert into missions (id, title, store_type, target_pattern, level, reward_points)
select ('d0000000-0000-0000-0004-' || lpad(d.n::text, 12, '0'))::uuid,
       d.title, d.stype, d.pattern, d.lvl, r.pts
from demo d join demo_reward r on r.lvl = d.lvl;

-- ---------- 5. user_missions (사용자 n ↔ 미션 n) ----------
insert into user_missions (id, user_id, mission_id, status, best_step, completed_at)
select ('d0000000-0000-0000-0005-' || lpad(n::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0004-' || lpad(n::text, 12, '0'))::uuid,
       case when done then 'completed' else 'in_progress' end,
       best,
       case when done then t end
from demo;

-- ---------- 6. attempts (실전 주문 1~best단계, 15분 간격) ----------
insert into attempts (id, user_id, mission_id, step, sentence, score, created_at)
select ('d0000000-0000-0000-0006-' || lpad((d.n * 10 + s)::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0001-' || lpad(d.n::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0004-' || lpad(d.n::text, 12, '0'))::uuid,
       s, d.sentence, 62 + s * 8 + (d.n * 3) % 9,
       d.t - ((4 - s) * 15 || ' minutes')::interval
from demo d cross join generate_series(1, 3) s
where s <= d.best;

-- ---------- 7. receipts (완료한 미션만, 주문 10분 전 발행) ----------
insert into receipts (id, user_id, store_id, image_hash, business_no, receipt_no, amount, issued_at, verified, created_at)
select ('d0000000-0000-0000-0007-' || lpad(n::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0002-' || lpad(n::text, 12, '0'))::uuid,
       md5('iju-demo-receipt-' || n),
       '900-00-' || lpad((10000 + n)::text, 5, '0'),
       'R2611-' || lpad(n::text, 4, '0'),
       amount, t - interval '10 minutes', true, t
from demo where done;

-- ---------- 8. coupons (영수증 인증마다 2,000원, 30일. 5·10번은 사용함) ----------
insert into coupons (id, user_id, store_id, value, status, expires_at)
select ('d0000000-0000-0000-0008-' || lpad(n::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0002-' || lpad(n::text, 12, '0'))::uuid,
       2000,
       case when n % 5 = 0 then 'used' else 'active' end,
       t + interval '30 days'
from demo where done;

-- ---------- 9. review_cards ----------
-- 연습할 때 들어가고(created_at), 복습 단계를 끝낼 때마다 1·3·7일 뒤로 미룹니다 (review_store.dart waitDays).
-- 진행 중 미션은 아직 복습 전(cleared 0, 오늘 복습).
insert into review_cards (id, user_id, sentence, variants, next_review_at, meaning, order_data, score, cleared, created_at, updated_at)
select ('d0000000-0000-0000-0009-' || lpad(n::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
       sentence, '[]'::jsonb,
       case c when 0 then t - interval '1 hour'
              else t + (c * 6 || ' hours')::interval + ((array[1, 3, 7])[c] || ' days')::interval end,
       meaning, order_data::jsonb,
       70 + (n * 7) % 26, c,
       t - interval '1 hour',
       case c when 0 then t - interval '1 hour' else t + (c * 6 || ' hours')::interval end
from (select *, case when done then n % 4 else 0 end as c from demo) d;

-- ---------- 10. order_places (영수증 인증한 가게 → 내 지도) ----------
insert into order_places (id, user_id, store_name, sentence, meaning, address, lat, lng, ordered_at)
select ('d0000000-0000-0000-0010-' || lpad(n::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
       store, sentence, meaning,
       case when lat > 37.8 then '강원특별자치도 춘천시' else '강원특별자치도 홍천군 홍천읍' end,
       lat, lng, t
from demo where done;

-- ---------- 11. community_posts (주문한 가게에서 말한 문장 자랑) ----------
insert into community_posts (id, user_id, nickname, store_name, sentence, meaning, body, lat, lng, created_at)
select ('d0000000-0000-0000-0011-' || lpad(n::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
       nickname, store, sentence, meaning, body, lat, lng,
       t + interval '1 hour'
from demo where done;

-- ---------- 12. follows (n → n+1, 15 → 1 순환) ----------
insert into follows (follower_id, followee_id, created_at)
select ('d0000000-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
       ('d0000000-0000-0000-0001-' || lpad((n % 15 + 1)::text, 12, '0'))::uuid,
       t
from demo;

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
