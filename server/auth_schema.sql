-- 로그인 (개발자1). Supabase SQL Editor에서 한 번 실행하세요. 메모리 DB는 필요 없습니다.
alter table users add column if not exists login_id text unique;
alter table users add column if not exists email text unique;
alter table users add column if not exists password_hash text;
alter table users add column if not exists auth_provider text not null default 'local';
alter table users add column if not exists google_sub text unique;
alter table users add column if not exists terms_version text;
alter table users add column if not exists terms_agreed_at timestamptz;
alter table users add column if not exists privacy_agreed_at timestamptz;
alter table users add column if not exists created_at timestamptz default now();

-- 기존 POST /users(닉네임만) 사용자는 그대로 두고, 닉네임은 새로 만드는 계정끼리만 겹치지 않게 앱에서 검사합니다.
-- 가입 화면에서 언어·체류 유형을 받지 않으므로 비어 있어도 되게 합니다.
alter table users alter column language drop not null;
alter table users alter column residence_type drop not null;
