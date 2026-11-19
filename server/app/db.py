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

    def update_eq(self, column: str, value: Any, changes: dict[str, Any]) -> list[dict[str, Any]]:
        updated = []
        for r in self.rows:
            if r.get(column) == value:
                r.update(changes)
                updated.append(dict(r))
        return updated

    def delete_match(self, match: dict[str, Any]) -> None:
        self.rows = [r for r in self.rows if not all(r.get(k) == v for k, v in match.items())]


class _SupabaseTable:
    def __init__(self, name: str):
        self.name = name

    def insert(self, row: dict[str, Any]) -> dict[str, Any]:
        return _client.table(self.name).insert(row).execute().data[0]

    def select_eq(self, column: str, value: Any) -> list[dict[str, Any]]:
        return _client.table(self.name).select("*").eq(column, value).execute().data

    def all(self) -> list[dict[str, Any]]:
        return _client.table(self.name).select("*").execute().data

    def update_eq(self, column: str, value: Any, changes: dict[str, Any]) -> list[dict[str, Any]]:
        return _client.table(self.name).update(changes).eq(column, value).execute().data

    def delete_match(self, match: dict[str, Any]) -> None:
        query = _client.table(self.name).delete()
        for k, v in match.items():
            query = query.eq(k, v)
        query.execute()


_memory: dict[str, _MemoryTable] = {}


def fetch_all(name: str, columns: str = "*", page: int = 1000) -> list[dict[str, Any]]:
    """표 전체를 [columns]만 가져옵니다. Supabase는 한 번에 1000행까지라 나눠서 받습니다."""
    if _client is None:
        return table(name).all()
    rows: list[dict[str, Any]] = []
    start = 0
    while True:
        chunk = _client.table(name).select(columns).range(start, start + page - 1).execute().data
        rows.extend(chunk)
        if len(chunk) < page:
            return rows
        start += page


def select_box(
    name: str,
    lat_min: float,
    lat_max: float,
    lng_min: float,
    lng_max: float,
    *,
    columns: str = "*",
    not_null: str | None = None,
    limit: int = 1000,
) -> list[dict[str, Any]]:
    """위도·경도 상자 안의 행 (근처 가게). [not_null] 열이 비어 있는 행은 뺍니다."""
    if _client is None:
        return [
            r
            for r in table(name).all()
            if r.get("lat") is not None
            and r.get("lng") is not None
            and lat_min <= r["lat"] <= lat_max
            and lng_min <= r["lng"] <= lng_max
            and (not_null is None or r.get(not_null) is not None)
        ][:limit]
    q = (
        _client.table(name)
        .select(columns)
        .gte("lat", lat_min)
        .lte("lat", lat_max)
        .gte("lng", lng_min)
        .lte("lng", lng_max)
    )
    if not_null:
        q = q.not_.is_(not_null, "null")
    return q.limit(limit).execute().data


def table(name: str):
    if _client is not None:
        return _SupabaseTable(name)
    if name not in _memory:
        _memory[name] = _MemoryTable(SEED.get(name, []))
    return _memory[name]
