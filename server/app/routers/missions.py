# 담당: 개발자3 — 사용자 수준에 맞는 미션 + 진행 상태
from typing import Any

from fastapi import APIRouter, HTTPException

from ..db import table
from ..llm import LLMError, text_json
from ..schemas import Mission, MissionGenerateIn, MissionsOut

router = APIRouter(tags=["missions"])

_STATUS_ORDER = {"in_progress": 0, "new": 1, "completed": 2}


def get_user(user_id: str) -> dict[str, Any] | None:
    rows = table("users").select_eq("id", user_id)
    return rows[0] if rows else None


def get_user_mission(user_id: str, mission_id: str) -> dict[str, Any] | None:
    for r in table("user_missions").select_eq("user_id", user_id):
        if r["mission_id"] == mission_id:
            return r
    return None


def save_user_mission(user_id: str, mission_id: str, **changes: Any) -> None:
    """user_missions 한 줄을 만들거나 고칩니다. attempts·receipts에서 같이 씁니다."""
    row = get_user_mission(user_id, mission_id)
    if row:
        table("user_missions").update_eq("id", row["id"], changes)
    else:
        table("user_missions").insert(
            {"user_id": user_id, "mission_id": mission_id,
             "status": "in_progress", "best_step": 0, **changes}
        )


@router.get("/missions", response_model=MissionsOut)
def list_missions(user_id: str):
    user = get_user(user_id)
    level = (user or {}).get("level") or 1
    progress = {r["mission_id"]: r for r in table("user_missions").select_eq("user_id", user_id)}

    missions = []
    for r in table("missions").all():
        # 내 수준보다 한 단계 위까지 보여 줌 (도전 미션)
        if (r.get("level") or 1) > level + 1:
            continue
        p = progress.get(r["id"], {})
        missions.append(
            Mission(
                id=r["id"],
                title=r["title"],
                store_type=r["store_type"],
                target_pattern=r.get("target_pattern") or "",
                reward=r["reward_points"],
                level=r.get("level") or 1,
                status=p.get("status", "new"),
                best_step=p.get("best_step", 0),
            )
        )
    # 진행 중 → 새 미션 → 완료 순, 같은 상태면 쉬운 것부터
    missions.sort(key=lambda m: (_STATUS_ORDER[m.status], m.level))
    return MissionsOut(missions=missions)

# ---------------------------------------------------------------- 미션 생성
STORE_LABELS = {"butcher": "정육점", "restaurant": "식당", "side_dish": "반찬가게"}

# LLM이 없거나 실패할 때 쓰는 업종별 템플릿: (제목, 목표 문장 패턴, 레벨)
TEMPLATES = {
    "butcher": [
        ("{place}에서 {item} 사기", "[품목] [무게] [용도]으로 주세요", 1),
        ("{place}에서 {item} 두껍게 썰어 달라고 하기", "[품목] [무게] [두께]로 썰어 주세요", 2),
    ],
    "restaurant": [
        ("{place}에서 {item} 주문하기", "[메뉴] [양] 주세요", 1),
        ("{place}에서 {item} 덜 맵게 주문하기", "[메뉴] [맵기]로 해 주세요", 2),
    ],
    "side_dish": [
        ("{place}에서 {item} 사기", "[반찬] [양] 주세요", 1),
        ("{place}에서 반찬 두 가지 사기", "[반찬] [양]이랑 [반찬] [양] 주세요", 2),
    ],
}
DEFAULT_TEMPLATES = [
    ("{place}에서 {item} 사기", "[품목] [양] 주세요", 1),
    ("{place}에서 {item} 있는지 물어보기", "[품목] 있어요?", 1),
]
REWARD_BY_LEVEL = {1: 100, 2: 150, 3: 200}

GENERATE_PROMPT = """너는 한국에 사는 이주민(계절근로자)에게 동네 가게에서 쓸 생활 한국어 미션을 만드는 도우미다.
가게: {place} ({store_type}), 판매 메뉴: {menu}
이 가게에서 실제로 주문할 때 쓰는 미션을 {count}개 만들어 아래 JSON 형식으로만 답하라. 설명은 쓰지 마라.
{{"missions": [{{"title": "정육점에서 삼겹살 사기", "target_pattern": "[품목] [무게] [용도]으로 주세요", "level": 1}}]}}
- title은 "가게에서 무엇 하기" 꼴의 20자 이내 한국어
- target_pattern은 대괄호 [ ]로 바꿔 넣을 자리를 표시한 짧은 주문 문장
- level은 1(쉬움)~3(어려움), 첫 미션은 1"""


def _template_missions(store_type: str, place: str, menu: list[str], count: int) -> list[dict[str, Any]]:
    templates = TEMPLATES.get(store_type, DEFAULT_TEMPLATES)
    out = []
    for i in range(count):
        title, pattern, level = templates[i % len(templates)]
        item = menu[i % len(menu)] if menu else "물건"
        out.append({"title": title.format(place=place, item=item), "target_pattern": pattern, "level": level})
    return out


async def _llm_missions(store_type: str, place: str, menu: list[str], count: int) -> list[dict[str, Any]]:
    data = await text_json(
        GENERATE_PROMPT.format(place=place, store_type=store_type, menu=", ".join(menu) or "없음", count=count)
    )
    out = []
    for m in data.get("missions", [])[:count]:
        title, pattern = str(m.get("title", "")).strip(), str(m.get("target_pattern", "")).strip()
        if title and pattern:
            level = int(m.get("level") or 1)
            out.append({"title": title, "target_pattern": pattern, "level": min(max(level, 1), 3)})
    if not out:
        raise LLMError("no missions")
    return out


@router.post("/missions/generate", response_model=MissionsOut)
async def generate_missions(body: MissionGenerateIn):
    """가게 업종·메뉴로 미션을 만들어 저장합니다. 같은 제목의 미션이 있으면 그걸 돌려줍니다."""
    store_type, menu, place = body.store_type, list(body.menu), None
    if body.store_id:
        stores = table("stores").select_eq("id", body.store_id)
        if not stores:
            raise HTTPException(404, "store not found")
        store_type = stores[0]["type"]
        place = stores[0]["name"]
        menu = menu or [i["name"] for i in table("menu_items").select_eq("store_id", body.store_id)]
    if not store_type:
        raise HTTPException(422, "store_id 또는 store_type이 필요해요")
    place = place or STORE_LABELS.get(store_type, "가게")

    try:
        drafts = await _llm_missions(store_type, place, menu, body.count)
    except (LLMError, TypeError, ValueError):
        drafts = _template_missions(store_type, place, menu, body.count)

    existing = {m["title"]: m for m in table("missions").all()}
    created, seen = [], set()
    for d in drafts:
        if d["title"] in seen:  # 메뉴가 적어 템플릿이 겹치면 한 번만
            continue
        seen.add(d["title"])
        row = existing.get(d["title"]) or table("missions").insert(
            {
                "title": d["title"],
                "store_type": store_type,
                "target_pattern": d["target_pattern"],
                "level": d["level"],
                "reward_points": REWARD_BY_LEVEL[d["level"]],
            }
        )
        created.append(
            Mission(
                id=str(row["id"]), title=row["title"], store_type=row["store_type"],
                target_pattern=row.get("target_pattern") or "", reward=row["reward_points"],
                level=row.get("level") or 1,
            )
        )
    return MissionsOut(missions=created)
