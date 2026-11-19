-- PRD 3.8 데이터 모델. Supabase 대시보드 > SQL Editor에 붙여넣고 실행하세요.
-- 서버는 service key로 접근하므로 RLS는 켜두되 정책은 만들지 않습니다(앱에서 DB 직접 접근 금지).

create extension if not exists pgcrypto;

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  nickname text not null,
  language text not null,
  residence_type text,
  level int not null default 1,
  points int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null,
  business_no text unique,
  lat double precision,
  lng double precision,
  qr_code text unique
);

create table if not exists menu_items (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  name text not null,
  price int,
  unit text,
  options jsonb not null default '[]'
);

create table if not exists missions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  store_type text not null,
  target_pattern text,
  level int not null default 1,
  reward_points int not null default 100
);

create table if not exists user_missions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  mission_id uuid not null references missions(id) on delete cascade,
  status text not null default 'in_progress',
  best_step int not null default 0,
  completed_at timestamptz,
  unique (user_id, mission_id)
);

create table if not exists attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  mission_id uuid not null references missions(id) on delete cascade,
  step int not null check (step between 1 and 4),
  sentence text,
  score int,
  created_at timestamptz not null default now()
);

create table if not exists receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  store_id uuid references stores(id),
  image_hash text not null unique,              -- 같은 이미지 재업로드 차단
  business_no text,
  receipt_no text,
  amount int,
  issued_at timestamptz,
  verified boolean not null default false,
  created_at timestamptz not null default now(),
  unique (business_no, receipt_no, issued_at)   -- 같은 영수증 재사용 차단
);

create table if not exists coupons (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  store_id uuid references stores(id),
  value int not null,
  status text not null default 'active',
  expires_at timestamptz not null
);

create table if not exists review_cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  sentence text not null,
  variants jsonb not null default '[]',
  next_review_at timestamptz
);

alter table users enable row level security;
alter table stores enable row level security;
alter table menu_items enable row level security;
alter table missions enable row level security;
alter table user_missions enable row level security;
alter table attempts enable row level security;
alter table receipts enable row level security;
alter table coupons enable row level security;
alter table review_cards enable row level security;
