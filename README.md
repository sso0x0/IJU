# 이주 (이거 주세요)

강원도 이주민이 동네 가게에서 **스스로 주문하며** 생활 한국어를 익히는 앱입니다.
메뉴판을 찍으면 AI가 메뉴를 읽고, 내 식단·종교 기준으로 먹어도 되는지 알려 주고, 주문 문장을 만들어 말하기 연습까지 이어 줍니다.

2026 AI 활용 전국 대학생 창업 해커톤 · 팀 가지소 (이가은 · 신지윤 · 박소현)

## 주요 기능

| 기능 | 내용 |
| --- | --- |
| 시작 | 스플래시 → 로그인 / 온보딩(모국어 · 나는 누구 · 식단 · 종교) → 회원가입 (아이디 또는 구글) |
| 메뉴판 | 촬영 → AI 메뉴 인식 → 판정(먹어도 돼요 · 물어보세요 · 피하세요) → 메뉴 고르기 |
| 문장 · 연습 | 키워드 카드로 주문 문장 조립 → 음성 연습(발음 채점) |
| 실전 주문 | 보여주며 따라하기 → 빈칸 말하기 → 혼자 말하기 |
| 보상 | 영수증 인증 → 쿠폰 · 포인트, 가게와 문장이 내 지도에 저장 |
| 복습 | 보여주기 → 따라 말하기 → 빈칸 말하기 → 혼자 말하기 (간격 반복) |
| 커뮤니티 | 누가 어느 가게에서 어떤 문장을 말했는지 글 · 지도 · 팔로우 |
| 마이페이지 | 내 지도 · 쿠폰 · 말한 문장 · 쓴 글, 모국어 · 식단 · 닉네임 · 비밀번호 변경 |

모국어 11개: 베트남어 · 필리핀어 · 크메르어 · 라오어 · 태국어 · 인도네시아어 · 우즈베크어 · 몽골어 · 네팔어 · 중국어 · 영어

## 실행

**서버** (FastAPI, `server/`)

```bash
cd server
python -m venv .venv
.venv\Scripts\activate            # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
copy .env.example .env           # 값 채우기 (아래 표)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API 문서: http://localhost:8000/docs · `.env`가 없으면 메모리 DB와 시연용 응답으로 동작합니다.

**앱** (Flutter 3.50)

```bash
flutter pub get
flutter run -d chrome --web-port 5000   # 구글 로그인은 승인된 주소(localhost:5000)에서만 돼요
```

실기기에서는 `--dart-define=API_BASE_URL=http://<노트북 IP>:8000` (Android 에뮬레이터는 기본값 10.0.2.2).

## 설정 (`server/.env`)

| 키 | 용도 |
| --- | --- |
| `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` | DB (비우면 메모리 DB) |
| `LLM_BASE_URL`, `LLM_API_KEY`, `LLM_MODEL` | 메뉴 인식 · 번역 · 문장 (OpenAI 호환) |
| `GOOGLE_CLIENT_IDS` | 구글 로그인. 앱의 웹 클라이언트 ID와 같아야 해요 |
| `KAKAO_REST_API_KEY` | 영수증 가게 주소 → 좌표 (내 지도 핀) |
| `RECEIPT_ACCEPT_ANY` | **시연 모드, 기본 `true`** (아래 참고) |

> ⚠️ **영수증 인증은 지금 시연 모드입니다.** `RECEIPT_ACCEPT_ANY=true`(기본값)이면 **아무 사진이나 올려도 인증을 통과**하고 쿠폰이 나갑니다.
> AI 판독 · 중복 · 기간 검사를 모두 건너뛰니, 실제 운영 전에는 꼭 `false`로 바꾸세요.

**DB 시연 데이터**: Supabase SQL Editor에서 `server/demo_seed.sql`을 실행하면 시연 계정 `demo01`~`demo15` (비밀번호 `demo1234`)과 가게 · 미션 · 쿠폰 · 커뮤니티 글이 들어갑니다. 여러 번 실행해도 됩니다.

## 개발 규칙

커밋 전에 통과해야 합니다 (GitHub Actions에서도 실행).

```bash
dart format lib test
flutter analyze
flutter test
```

- **화면 보조 문구(모국어)**: 베트남어 원문으로 `nt('Nghe')`처럼 쓰고, `lib/app/native_strings.dart`에 다른 언어를 더해요.
- **문장 · 재료 · 식단 문구(Tr 맵)**: `vi`·`en`·`fil`·`km`는 맵에 직접, 나머지 7개 언어는 `lib/app/extra_translations.dart`에 영어 원문을 키로 더해요. 빠지면 테스트가 알려 줘요.
- 요청 · 응답 형식은 `server/app/schemas.py`에 있어요.

```text
lib/
├── app/        라우터 · 테마 · 색 · 언어(languages.dart) · 번역표
├── features/   화면별 폴더 (login, onboarding, menu_scan, compose, practice,
│               real_order, review, community, order_map, profile, ...)
└── widgets/    공통 위젯 (버튼, 칩, 지도 place_map.dart, ...)
server/app/
├── routers/    API (auth, me, community, menu_scan, compose, receipts, stores, ...)
└── schemas.py  요청 · 응답 형식
```

참고 데이터(상가정보 · 한국어기초사전 · AI Hub)는 `server/scripts/load_*.py`로 Supabase에 올립니다. 원본 파일은 저장소에 넣지 않아요.
