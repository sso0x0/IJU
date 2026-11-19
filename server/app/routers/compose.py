# 담당: 개발자2 — 지금은 목 응답입니다. llm.text_json()으로 문장 생성을 붙이세요.
from fastapi import APIRouter

from ..schemas import Card, ComposeIn, ComposeOut

router = APIRouter(tags=["ai"])


@router.post("/ai/compose", response_model=ComposeOut)
async def compose(body: ComposeIn):
    # TODO(개발자2): LLM 문장 생성·교정 피드백, 실패 시 아래 목 응답을 대체 응답으로 사용
    words = [body.menu_item, *body.selected_options]
    return ComposeOut(
        cards=[Card(word=w, meaning=w) for w in words],
        sentence=f"{' '.join(words)}으로 주세요.",
        feedback=None,
        meaning="(번역 예정)",
    )
