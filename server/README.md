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
| `routers/users.py` | POST /users | 개발자1 | 구현 |
| `routers/stores.py` | GET /stores/{id} | 개발자1 | 구현 |
| `routers/menu_scan.py`, `vision.py` | POST /ai/menu-scan | 개발자1 | 구현 (실패 시 대체 응답) |
| `vision.py` → `scan_receipt()` | (함수) | 개발자1 | 구현 |
| `routers/compose.py` | POST /ai/compose | 개발자2 | 목 응답 |
| `routers/voice.py` | POST /ai/pronunciation, /ai/tts | 개발자2 | 목 응답 |
| `routers/missions.py` | GET /missions | 개발자3 | 시드 데이터 반환 |
| `routers/attempts.py` | POST /attempts | 개발자3 | 저장만 |
| `routers/receipts.py` | POST /receipts | 개발자3 | 인식만, 검증·쿠폰은 TODO |
| `routers/admin.py` | GET /admin/stats | 개발자3 | 목 응답 |

요청·응답 형식은 전부 `app/schemas.py`에 있습니다. 형식을 바꾸면 팀에 공유하세요.

## 공용 도구

- `db.table("이름")` → `.insert(row)`, `.select_eq(컬럼, 값)`, `.all()`
- `llm.vision_json(image_bytes, prompt)`, `llm.text_json(prompt)` → JSON dict, 실패 시 `LLMError`

## 실기기에서 테스트

폰과 노트북이 같은 Wi-Fi(핫스팟)에 있으면 앱에서 `http://<노트북 IP>:8000`으로 호출하면 됩니다.
Android 에뮬레이터에서는 `http://10.0.2.2:8000`입니다.
