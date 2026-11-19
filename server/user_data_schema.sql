-- 복습 목록·주문 지도 서버 저장. Supabase SQL Editor에서 한 번 실행하세요. 메모리 DB는 필요 없습니다.

-- 복습 카드: 미션에서 한 문장 + 문장 만들기 카드 조합(order_data) + 진행 단계
alter table review_cards add column if not exists meaning text;
alter table review_cards add column if not exists order_data jsonb;
alter table review_cards add column if not exists score integer;
alter table review_cards add column if not exists cleared integer not null default 0;
alter table review_cards add column if not exists created_at timestamptz not null default now();
alter table review_cards add column if not exists updated_at timestamptz not null default now();
do $$ begin
  alter table review_cards add constraint review_cards_cleared_check check (cleared between 0 and 3);
exception when duplicate_object then null; end $$;
create unique index if not exists review_cards_user_sentence on review_cards (user_id, sentence);

-- 주문 지도: 영수증을 인증한 가게와 그 가게에서 한 문장
create table if not exists order_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  store_name text not null,
  sentence text not null,
  meaning text,
  address text,
  lat double precision,
  lng double precision,
  ordered_at timestamptz not null default now(),
  unique (user_id, store_name, sentence)
);
alter table order_places enable row level security;
