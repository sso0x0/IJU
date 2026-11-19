"""카카오 로컬 API로 가게 주소 ↔ 좌표를 찾습니다 (개발자1). 주문 지도에 핀을 찍는 데 씁니다.

.env의 KAKAO_REST_API_KEY가 없거나 호출이 실패하면 None을 돌려주므로, 호출 쪽은 좌표 없이 진행하면 됩니다.
"""

from typing import Any

import httpx

from .config import settings

API = "https://dapi.kakao.com/v2/local"
TIMEOUT = 5.0


async def _get(client: httpx.AsyncClient, path: str, params: dict[str, Any]) -> list[dict[str, Any]]:
    try:
        res = await client.get(
            f"{API}/{path}",
            params=params,
            headers={"Authorization": f"KakaoAK {settings.kakao_rest_api_key}"},
        )
        res.raise_for_status()
        return res.json().get("documents") or []
    except (httpx.HTTPError, ValueError):
        return []


async def locate(name: str | None, address: str | None) -> dict[str, Any] | None:
    """주소(없으면 가게 이름)로 좌표를 찾습니다. {"lat", "lng", "address"} 또는 None."""
    if not settings.kakao_rest_api_key:
        return None
    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        if address:
            docs = await _get(client, "search/address.json", {"query": address, "size": 1})
            if docs:
                d = docs[0]
                road = (d.get("road_address") or {}).get("address_name")
                return {"lat": float(d["y"]), "lng": float(d["x"]), "address": road or d.get("address_name")}
        if name:
            docs = await _get(client, "search/keyword.json", {"query": name, "size": 1})
            if docs:
                d = docs[0]
                return {
                    "lat": float(d["y"]),
                    "lng": float(d["x"]),
                    "address": d.get("road_address_name") or d.get("address_name"),
                }
    return None


async def address_at(lat: float, lng: float) -> str | None:
    """좌표 → 주소 (도로명 우선)."""
    if not settings.kakao_rest_api_key:
        return None
    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        docs = await _get(client, "geo/coord2address.json", {"x": lng, "y": lat})
    if not docs:
        return None
    d = docs[0]
    return (d.get("road_address") or {}).get("address_name") or (d.get("address") or {}).get("address_name")
