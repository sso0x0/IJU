# 담당: 개발자3 (P1) — 상인 QR · 손님용 가게 페이지 · 사장님 화면
# 상인용 앱은 만들지 않고(PRD 비목표) 서버가 바로 띄우는 웹 페이지로 대신합니다.
#   GET /stores/{id}/qr.png   가게에 붙일 QR 이미지 (→ /m/{qr_code})
#   GET /m/{qr_code}          손님이 QR을 찍으면 보는 페이지: 메뉴 미리보기 + 이 가게 미션
#   GET /merchant/{qr_code}   사장님 화면: 확인 코드, 오늘 인증 방문·쿠폰, 인쇄용 QR
import html
import io
import os
from datetime import datetime, timedelta, timezone
from typing import Any

import segno
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import HTMLResponse, Response

from ..db import table
from .receipts import store_code

router = APIRouter(tags=["merchant"])

KST = timezone(timedelta(hours=9))
STORE_LABELS = {"restaurant": "식당", "side_dish": "반찬가게"}


def _find_store(key: str) -> dict[str, Any]:
    """qr_code 또는 store id로 가게를 찾습니다."""
    for s in table("stores").all():
        if key in (s.get("qr_code"), s.get("id")):
            return s
    raise HTTPException(404, "등록되지 않은 가게예요")


def _base_url(request: Request) -> str:
    # 폰에서 찍을 QR이라 localhost면 안 됨 → PUBLIC_BASE_URL=http://192.168.0.10:8000 처럼 설정
    return (os.getenv("PUBLIC_BASE_URL") or str(request.base_url)).rstrip("/")


def _qr_target(store: dict[str, Any], request: Request) -> str:
    return f"{_base_url(request)}/m/{store.get('qr_code') or store['id']}"


def _won(v: int | None) -> str:
    return "" if v is None else f"{v:,}원"


def _parse(value: Any) -> datetime | None:
    try:
        t = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    return t if t.tzinfo else t.replace(tzinfo=KST)


def _page(title: str, body: str) -> HTMLResponse:
    return HTMLResponse(
        f"""<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)}</title>
<style>
  :root {{ --primary:#0E7C5A; --soft:#E7F4EF; --text:#1A1D21; --body:#4A4F57; --sub:#5A606A;
          --line:#E3E6E9; --bg:#F4F6F5; --accent:#FFB27A; --coupon:#3D1C03; }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; font-family:-apple-system,BlinkMacSystemFont,"Pretendard","Apple SD Gothic Neo",sans-serif;
         color:var(--text); background:var(--bg); }}
  main {{ max-width:480px; margin:0 auto; padding:24px 20px 40px; }}
  .brand {{ color:var(--primary); font-weight:800; font-size:15px; letter-spacing:.02em; }}
  h1 {{ font-size:26px; margin:6px 0 4px; }}
  .sub {{ color:var(--sub); font-size:14px; margin:0 0 20px; }}
  .card {{ background:#fff; border:1px solid var(--line); border-radius:18px; padding:16px; margin-bottom:14px; }}
  .card h2 {{ font-size:15px; margin:0 0 10px; }}
  .row {{ display:flex; justify-content:space-between; gap:12px; padding:9px 0; border-top:1px solid var(--line); font-size:15px; }}
  .row:first-of-type {{ border-top:none; }}
  .muted {{ color:var(--sub); }}
  .mission {{ background:var(--soft); border-radius:14px; padding:12px 14px; margin-top:8px; }}
  .mission b {{ display:block; font-size:15px; }}
  .mission span {{ font-size:13px; color:var(--body); }}
  .code {{ font-size:56px; font-weight:800; letter-spacing:.18em; color:var(--primary); text-align:center; margin:4px 0; }}
  .stats {{ display:grid; grid-template-columns:repeat(3,1fr); gap:8px; }}
  .stat {{ background:var(--bg); border-radius:14px; padding:12px 8px; text-align:center; }}
  .stat b {{ display:block; font-size:19px; white-space:nowrap; }}
  .stat span {{ font-size:12px; color:var(--sub); }}
  .qr {{ display:block; width:220px; height:220px; margin:8px auto; image-rendering:pixelated; }}
  .note {{ font-size:13px; color:var(--body); line-height:1.6; }}
  .coupon {{ background:var(--accent); color:var(--coupon); border-radius:16px; padding:14px 16px; font-weight:700; }}
  @media print {{ body {{ background:#fff; }} .noprint {{ display:none; }} }}
</style></head>
<body><main>{body}</main></body></html>"""
    )


@router.get("/stores/{store_id}/qr.png")
def store_qr(store_id: str, request: Request):
    store = _find_store(store_id)
    buf = io.BytesIO()
    segno.make(_qr_target(store, request), error="m").save(buf, kind="png", scale=10, border=2)
    return Response(buf.getvalue(), media_type="image/png")


@router.get("/m/{qr_code}", response_class=HTMLResponse)
def customer_page(qr_code: str):
    store = _find_store(qr_code)
    label = STORE_LABELS.get(store["type"], "가게")
    items = table("menu_items").select_eq("store_id", store["id"])
    missions = [m for m in table("missions").all() if m.get("store_type") == store["type"]]
    missions.sort(key=lambda m: m.get("level") or 1)

    menu_rows = "".join(
        f'<div class="row"><span>{html.escape(i["name"])}'
        f'{" <span class=muted>/ " + html.escape(i["unit"]) + "</span>" if i.get("unit") else ""}</span>'
        f"<b>{_won(i.get('price'))}</b></div>"
        for i in items
    ) or '<p class="note">메뉴를 준비하고 있어요.</p>'
    mission_rows = "".join(
        f'<div class="mission"><b>{html.escape(m["title"])}</b>'
        f'<span>레벨 {m.get("level") or 1} · 보상 {m.get("reward_points") or 0}P + 쿠폰</span></div>'
        for m in missions[:3]
    ) or '<p class="note">이 가게 미션을 준비하고 있어요.</p>'

    return _page(
        f"{store['name']} · 이주",
        f"""
<div class="brand">이주 · 이거 주세요</div>
<h1>{html.escape(store['name'])}</h1>
<p class="sub">이주 참여 {label} · 한국어로 주문하고 쿠폰 받기</p>
<div class="card"><h2>메뉴 미리보기</h2>{menu_rows}</div>
<div class="card"><h2>이 가게에서 할 수 있는 미션</h2>{mission_rows}</div>
<div class="coupon">미션을 끝내고 영수증을 인증하면 다음 방문 쿠폰을 드려요</div>
<p class="note" style="margin-top:14px">이주 앱에서 미션을 고르고 주문 문장을 연습한 뒤, 사장님께 말해 보세요.<br>
Hãy luyện câu gọi món trong app 이주 rồi nói với chủ quán nhé.</p>
""",
    )


@router.get("/merchant/{qr_code}", response_class=HTMLResponse)
def merchant_page(qr_code: str):
    """사장님 화면. 해커톤용이라 별도 로그인 없이 가게 QR 코드 주소로 엽니다."""
    store = _find_store(qr_code)
    today = datetime.now(KST).date()

    receipts = [r for r in table("receipts").select_eq("store_id", store["id"]) if r.get("verified")]
    todays = [r for r in receipts if (t := _parse(r.get("created_at"))) and t.astimezone(KST).date() == today]
    coupons = table("coupons").select_eq("store_id", store["id"])
    used = [c for c in coupons if c.get("status") == "used"]
    amount_today = sum(r.get("amount") or 0 for r in todays)

    recent = sorted(receipts, key=lambda r: str(r.get("created_at") or ""), reverse=True)[:5]
    recent_rows = "".join(
        f'<div class="row"><span class="muted">{(_parse(r.get("created_at")) or datetime.now(KST)).astimezone(KST):%m/%d %H:%M}</span>'
        f'<b>{_won(r.get("amount")) or "확인 코드 인증"}</b></div>'
        for r in recent
    ) or '<p class="note">아직 인증된 방문이 없어요.</p>'
    key = html.escape(store.get("qr_code") or store["id"])

    return _page(
        f"{store['name']} · 사장님 화면",
        f"""
<div class="brand">이주 · 사장님 화면</div>
<h1>{html.escape(store['name'])}</h1>
<p class="sub">손님이 영수증을 못 찍을 때 아래 확인 코드를 알려 주세요.</p>
<div class="card"><h2>사장님 확인 코드</h2><div class="code">{html.escape(store_code(store))}</div>
<p class="note" style="text-align:center;margin:0">쿠폰 사용 처리에도 같은 코드를 써요.</p></div>
<div class="card"><h2>오늘</h2><div class="stats">
  <div class="stat"><b>{len(todays)}</b><span>인증 방문</span></div>
  <div class="stat"><b>{_won(amount_today) or "0원"}</b><span>인증 매출</span></div>
  <div class="stat"><b>{len(used)}/{len(coupons)}</b><span>쿠폰 사용/발급</span></div>
</div></div>
<div class="card"><h2>최근 인증</h2>{recent_rows}</div>
<div class="card"><h2>가게에 붙일 QR</h2>
<img class="qr" src="/stores/{key}/qr.png" alt="가게 QR 코드">
<p class="note" style="text-align:center">손님이 찍으면 메뉴와 이 가게 미션이 보여요.</p>
<p class="noprint" style="text-align:center"><a href="/m/{key}">손님 화면 미리보기</a></p></div>
""",
    )
