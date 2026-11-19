"""적재 스크립트 공용 도구. server/.env의 Supabase 설정을 씁니다.

실행 예 (server 폴더에서):
    .venv\\Scripts\\python scripts\\load_places.py <원본 경로>
원본 데이터 폴더 안에서 실행하지 말고, 경로를 인자로 넘기세요.
"""

import os
import sys
import time
from collections.abc import Iterable

SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SERVER_DIR)
os.chdir(SERVER_DIR)  # pydantic-settings가 .env를 현재 폴더에서 읽습니다
sys.stdout.reconfigure(encoding="utf-8")

from supabase import create_client  # noqa: E402

from app.config import settings  # noqa: E402


def client():
    if not settings.use_supabase:
        sys.exit("server/.env에 SUPABASE_URL과 SUPABASE_SERVICE_KEY를 넣어주세요.")
    return create_client(settings.supabase_url, settings.supabase_service_key)


def upsert(table: str, rows: Iterable[dict], on_conflict: str, batch: int = 1000) -> int:
    """rows를 batch개씩 upsert합니다. 다시 실행해도 같은 행이 중복되지 않습니다."""
    c = client()
    buf: list[dict] = []
    total = 0

    def flush():
        nonlocal total
        for attempt in range(4):
            try:
                c.table(table).upsert(buf, on_conflict=on_conflict, returning="minimal").execute()
                break
            except Exception as e:  # 일시적인 네트워크 오류는 재시도
                if attempt == 3:
                    raise
                print(f"  재시도 {attempt + 1}: {str(e)[:120]}")
                time.sleep(2 * (attempt + 1))
        total += len(buf)
        print(f"  {table}: {total}행", end="\r")
        buf.clear()

    for r in rows:
        buf.append(r)
        if len(buf) >= batch:
            flush()
    if buf:
        flush()
    print(f"  {table}: {total}행 완료")
    return total


def as_list(x):
    if x is None:
        return []
    return x if isinstance(x, list) else [x]


def feats(node) -> dict:
    """한국어기초사전 JSON의 [{"att":..,"val":..}] 묶음을 dict로 바꿉니다."""
    f = node.get("feat", []) if isinstance(node, dict) else node
    return {x["att"]: x["val"] for x in as_list(f)}
