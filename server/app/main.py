from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .routers import admin, attempts, compose, coupons, menu_scan, merchant, missions, receipts, recipes, stores, users, voice

app = FastAPI(title="이주 API")

# Flutter Web·실기기에서 호출할 수 있게 전부 허용 (해커톤용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

for r in (users, stores, menu_scan, missions, compose, recipes, voice, attempts, receipts, admin, coupons, merchant):
    app.include_router(r.router)


@app.get("/health")
def health():
    return {
        "ok": True,
        "db": "supabase" if settings.use_supabase else "memory",
        "llm": settings.use_llm,
    }
