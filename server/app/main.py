from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .auth import AuthError
from .config import settings
from .routers import admin, attempts, auth, compose, coupons, menu_scan, merchant, missions, receipts, recipes, stores, users, voice

app = FastAPI(title="이주 API")

# Flutter Web·실기기에서 호출할 수 있게 전부 허용 (해커톤용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

for r in (auth, users, stores, menu_scan, missions, compose, recipes, voice, attempts, receipts, admin, coupons, merchant):
    app.include_router(r.router)


@app.exception_handler(AuthError)
async def auth_error(_: Request, e: AuthError):
    """로그인 오류는 {"code", "message"}로 돌려줘서 앱이 message를 그대로 띄우고 code로 분기합니다."""
    return JSONResponse(status_code=e.status, content={"code": e.code, "message": e.message})


@app.get("/health")
def health():
    return {
        "ok": True,
        "db": "supabase" if settings.use_supabase else "memory",
        "llm": settings.use_llm,
    }
