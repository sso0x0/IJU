# 이주 API 서버

FastAPI 서버입니다. Flutter 앱은 이 서버만 호출하고, AI 키와 DB 키는 서버의 `.env`에만 둡니다.

## 바로 실행 (키 없이도 동작)

```bash
cd server
python -m venv .venv
.venv\Scripts\activate          # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- API 문서: http://localhost:8000/docs (여기서 바로 요청을 테스트할 수 있어요)
- 상태 확인: http://localhost:8000/health

`.env`가 없으면 **메모리 DB + 시연용 대체 응답**으로 동작합니다. 그래서 Supabase나 AI 키가 준비되기 전에도 셋 다 바로 화면을 붙일 수 있어요.

## 실제 연결

1. `.env.example`을 `.env`로 복사
2. Supabase: SQL Editor에서 `supabase/schema.sql` → `supabase/seed.sql` 순서로 실행하고 `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` 입력
3. LLM: `LLM_BASE_URL`, `LLM_API_KEY`, `LLM_MODEL` 입력 (OpenAI 호환 API면 무엇이든 됨)

## 담당별 파일

| 파일 | 엔드포인트 | 담당 | 상태 |
| --- | --- | --- | --- |
| `routers/auth.py`, `auth.py` | /auth/* (가입·로그인·구글) | 개발자1 | 구현 — 화면 연동은 [AUTH.md](AUTH.md) |
| `routers/users.py` | POST /users | 개발자1 | 구현 (닉네임만 가입, 시연 호환용) |
| `routers/stores.py` | GET /stores/{id} | 개발자1 | 구현 |
| `routers/menu_scan.py`, `vision.py` | POST /ai/menu-scan | 개발자1 | 구현 (실패 시 대체 응답) |
| `vision.py` → `scan_receipt()` | (함수) | 개발자1 | 구현 |
| `routers/compose.py` | POST /ai/compose | 개발자2 | 구현 (문장은 규칙, 번역·카드 뜻·조언은 LLM, 실패 시 대체 응답) |
| `routers/recipes.py` | GET /recipes/match?menu= | 개발자2 | 구현 (Supabase `recipes` 표에서 메뉴와 같은·비슷한 레시피를 찾아 재료를 보이는 재료/육수·양념으로 나눠 줌. 앱은 이 재료로 '빼 주세요'·'들어가요?' 칩을 보강) |
| `routers/voice.py`, `scoring.py` | POST /ai/pronunciation, /ai/tts | 개발자2 | 구현 (STT는 기기에서, 서버는 채점·조언 / TTS는 기기 기본 TTS) |
| `routers/missions.py` | GET /missions | 개발자3 | 시드 데이터 반환 |
| `routers/attempts.py` | POST /attempts | 개발자3 | 저장만 |
| `routers/receipts.py` | POST /receipts, /receipts/merchant-confirm | 개발자3 | 구현 (인식·검증·쿠폰 발급, 사장님 확인 코드) |
| `routers/admin.py` | GET /admin/stats | 개발자3 | 목 응답 |

요청·응답 형식은 전부 `app/schemas.py`에 있습니다. 형식을 바꾸면 팀에 공유하세요.

> **변경 (개발자2)**: `POST /ai/pronunciation`은 이제 오디오 파일이 아니라 JSON
> `{"transcript", "target_sentence", "language"}`을 받습니다. 음성인식은 앱에서 기기 기본 STT로 하고,
> 서버는 받아 적은 문장을 목표 문장과 어절 단위로 비교해 `score`, `wrong_words`, `feedback`을 돌려줍니다.

## 참고 데이터 적재

원본 데이터는 저장소에 넣지 않고, 가공한 결과만 Supabase에 올립니다. `server` 폴더에서 원본 경로를 인자로 넘겨 실행하세요. 같은 행은 upsert라 다시 실행해도 중복되지 않아요.

| 스크립트 | 원본 | 테이블 |
| --- | --- | --- |
| `scripts/load_places.py <강원 CSV> [기준일]` | 공공데이터포털 소상공인시장진흥공단 상가(상권)정보 | `places` |
| `scripts/load_vocab.py <json zip> [--langs ko,en,vi]` | 한국어기초사전 사전 전체 내려받기(JSON) | `vocab`, `vocab_meanings` |
| `scripts/load_phrases.py <train zip> <validation zip>` | AI Hub 소상공인 고객 주문 질의-응답 | `phrases` |
| `scripts/load_pron_errors.py <VL_pronunciation_lab.zip>` | AI Hub 교육용 아시아어 사용자 한국어 음성 | `pron_error_stats` |

```bash
.venv\Scripts\python scripts\load_places.py "...\소상공인시장진흥공단_상가(상권)정보_강원_202609.csv" 2026-09-30
```

## 공용 도구

- `db.table("이름")` → `.insert(row)`, `.select_eq(컬럼, 값)`, `.all()`
- `llm.vision_json(image_bytes, prompt)`, `llm.text_json(prompt)` → JSON dict, 실패 시 `LLMError`

## 실기기에서 테스트

폰과 노트북이 같은 Wi-Fi(핫스팟)에 있으면 앱에서 `http://<노트북 IP>:8000`으로 호출하면 됩니다.
Android 에뮬레이터에서는 `http://10.0.2.2:8000`입니다.
