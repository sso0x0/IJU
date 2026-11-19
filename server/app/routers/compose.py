# 담당: 개발자2 — 지금은 목 응답입니다. llm.text_json()으로 문장 생성을 붙이세요.
from fastapi import APIRouter

from ..schemas import Card, ComposeIn, ComposeOut

router = APIRouter(tags=["ai"])


from .. import llm

@router.post("/ai/compose", response_model=ComposeOut)
async def compose(body: ComposeIn):
    prompt = f"""너는 한국 식당에서 외국인 손님이 주문하도록 돕는 한국어 선생님이야.
메뉴: {body.menu_item}
옵션: {", ".join(body.selected_options) or "없음"}
학습자 언어: {body.language}
아래 JSON 형식으로만 답해.
{{"cards":[{{"word":"한국어 단어","meaning":"학습자 언어 뜻"}}],
 "sentence":"짧고 공손한 주문 문장","meaning":"문장의 학습자 언어 번역"}}"""
    try:
        data = await llm.text_json(prompt)
        return ComposeOut(**data)
    except Exception:
        return _fallback(body)  # 지금 있는 목 응답을 함수로 빼서 대체 응답으로 사용