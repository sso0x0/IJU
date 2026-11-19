# 담당: 개발자1 — 홈 '가까운 음식점' (GET /places/nearby)
import math

from fastapi import APIRouter, Query
from pydantic import BaseModel

from ..db import select_box, table

router = APIRouter(tags=["stores"])


# ---------- 근처 가게 (홈 '가까운 가게') ----------
class NearbyPlace(BaseModel):
    id: str  # places.id (메뉴판 인식의 place_id로 넘기면 업종 힌트가 들어가요)
    name: str
    store_type: str
    category: str | None = None  # 상가정보 소분류 (예: 한식, 정육점)
    address: str | None = None
    lat: float
    lng: float
    distance_m: int
    partner: bool = False  # 이주 참여 가게 (stores 표에 있음 → 미션·쿠폰)


class NearbyOut(BaseModel):
    places: list[NearbyPlace]


def _distance_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6_371_000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


@router.get("/places/nearby", response_model=NearbyOut)
def nearby_places(
    lat: float = Query(ge=-90, le=90),
    lng: float = Query(ge=-180, le=180),
    radius: int = Query(default=1000, ge=100, le=5000),
    type: str | None = None,
    limit: int = Query(default=20, ge=1, le=50),
):
    """현재 위치에서 [radius]m 안의 가게를 가까운 순으로 줍니다 (상가정보 places 표).

    이주 미션에 맞는 업종(store_type이 있는 곳)만 보여 주고, [type]을 주면 그 업종만.
    이주 참여 가게(stores 표)는 [partner]로 표시하고 앞쪽에 둡니다.
    """
    dlat = radius / 111_320
    dlng = radius / (111_320 * max(math.cos(math.radians(lat)), 0.01))
    rows = select_box(
        "places",
        lat - dlat,
        lat + dlat,
        lng - dlng,
        lng + dlng,
        columns="id,name,branch,store_type,category_small,road_address,lat,lng",
        not_null="store_type",
        limit=2000,
    )
    partners = {
        (s.get("name"), round(s.get("lat") or 0, 4), round(s.get("lng") or 0, 4))
        for s in table("stores").all()
    }
    partner_ids = {str(s["place_id"]) for s in table("stores").all() if s.get("place_id")}
    out = []
    for r in rows:
        if type and r.get("store_type") != type:
            continue
        d = _distance_m(lat, lng, r["lat"], r["lng"])
        if d > radius:
            continue
        name = r["name"] + (f" {r['branch']}" if r.get("branch") else "")
        partner = str(r["id"]) in partner_ids or (
            r["name"],
            round(r["lat"], 4),
            round(r["lng"], 4),
        ) in partners
        out.append(
            NearbyPlace(
                id=str(r["id"]),
                name=name,
                store_type=r["store_type"],
                category=r.get("category_small"),
                address=r.get("road_address"),
                lat=r["lat"],
                lng=r["lng"],
                distance_m=round(d),
                partner=partner,
            )
        )
    # 상가정보에 없는 이주 참여 가게도 넣어요.
    for st in table("stores").all():
        if st.get("lat") is None or st.get("lng") is None or (type and st.get("type") != type):
            continue
        d = _distance_m(lat, lng, st["lat"], st["lng"])
        if d > radius or any(p.partner and p.name == st["name"] for p in out):
            continue
        out.append(
            NearbyPlace(
                id=str(st.get("place_id") or st["id"]),
                name=st["name"],
                store_type=st.get("type") or "restaurant",
                lat=st["lat"],
                lng=st["lng"],
                distance_m=round(d),
                partner=True,
            )
        )
    out.sort(key=lambda p: (not p.partner, p.distance_m))
    return NearbyOut(places=out[:limit])
