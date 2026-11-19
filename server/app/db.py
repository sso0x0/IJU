"""DB 접근. SUPABASE_URL이 없으면 메모리 DB로 동작해서 Supabase 세팅 전에도 바로 개발할 수 있습니다.

새 테이블을 쓰려면 table("이름")으로 가져와 insert / select_eq를 쓰면 됩니다.
"""

import uuid
from typing import Any

from .config import settings
from .seed_data import SEED

_client = None
if settings.use_supabase:
    from supabase import create_client

    _client = create_client(settings.supabase_url, settings.supabase_service_key)


class _MemoryTable:
    def __init__(self, rows: list[dict[str, Any]]):
        self.rows = [dict(r) for r in rows]

    def insert(self, row: dict[str, Any]) -> dict[str, Any]:
        row = {"id": str(uuid.uuid4()), **row}
        self.rows.append(row)
        return row

    def select_eq(self, column: str, value: Any) -> list[dict[str, Any]]:
        return [r for r in self.rows if r.get(column) == value]

    def all(self) -> list[dict[str, Any]]:
        return list(self.rows)


class _SupabaseTable:
    def __init__(self, name: str):
        self.name = name

    def insert(self, row: dict[str, Any]) -> dict[str, Any]:
        return _client.table(self.name).insert(row).execute().data[0]

    def select_eq(self, column: str, value: Any) -> list[dict[str, Any]]:
        return _client.table(self.name).select("*").eq(column, value).execute().data

    def all(self) -> list[dict[str, Any]]:
        return _client.table(self.name).select("*").execute().data


_memory: dict[str, _MemoryTable] = {}


def table(name: str):
    if _client is not None:
        return _SupabaseTable(name)
    if name not in _memory:
        _memory[name] = _MemoryTable(SEED.get(name, []))
    return _memory[name]
