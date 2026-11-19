# 담당: 개발자1
from fastapi import APIRouter, HTTPException

from ..db import table
from ..schemas import MenuItem, StoreOut

router = APIRouter(tags=["stores"])


@router.get("/stores/{store_id}", response_model=StoreOut)
def get_store(store_id: str):
    stores = table("stores").select_eq("id", store_id)
    if not stores:
        raise HTTPException(404, "store not found")
    s = stores[0]
    items = table("menu_items").select_eq("store_id", store_id)
    return StoreOut(
        id=s["id"],
        name=s["name"],
        type=s["type"],
        menu_items=[
            MenuItem(
                id=i["id"],
                name=i["name"],
                price=i.get("price"),
                unit=i.get("unit"),
                options=i.get("options") or [],
            )
            for i in items
        ],
    )
