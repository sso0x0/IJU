"""멀티모달 LLM 호출 공용 함수. OpenAI 호환 Chat Completions API 하나로 통일합니다.

- vision_json(image, prompt): 이미지 + 지시문 → JSON(dict)
- text_json(prompt): 지시문 → JSON(dict)   (개발자2 문장 생성에서 사용)

키가 없거나 실패·시간 초과면 LLMError를 던집니다. 호출하는 쪽에서 대체 응답으로 넘기세요.
"""

import base64
import io
import json
import re

import httpx
from PIL import Image

from .config import settings


class LLMError(Exception):
    pass


def _shrink(image_bytes: bytes, max_side: int = 1600) -> bytes:
    """이미지를 줄여 업로드·추론 시간을 단축합니다 (메뉴 인식 8초 목표)."""
    img = Image.open(io.BytesIO(image_bytes))
    img = img.convert("RGB")
    img.thumbnail((max_side, max_side))
    out = io.BytesIO()
    img.save(out, format="JPEG", quality=85)
    return out.getvalue()


def _parse_json(text: str) -> dict:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        raise LLMError(f"JSON not found in response: {text[:200]}")
    try:
        return json.loads(match.group(0))
    except json.JSONDecodeError as e:
        raise LLMError(f"invalid JSON: {e}") from e


async def _chat(content: list[dict] | str) -> dict:
    if not settings.use_llm:
        raise LLMError("LLM is not configured")
    try:
        async with httpx.AsyncClient(timeout=settings.llm_timeout) as client:
            res = await client.post(
                f"{settings.llm_base_url.rstrip('/')}/chat/completions",
                headers={"Authorization": f"Bearer {settings.llm_api_key}"},
                json={
                    "model": settings.llm_model,
                    "temperature": 0,
                    "messages": [{"role": "user", "content": content}],
                },
            )
            res.raise_for_status()
            text = res.json()["choices"][0]["message"]["content"]
    except (httpx.HTTPError, KeyError, IndexError) as e:
        raise LLMError(str(e)) from e
    return _parse_json(text)


async def vision_json(image_bytes: bytes, prompt: str) -> dict:
    try:
        small = _shrink(image_bytes)
    except Exception as e:  # 이미지가 아니거나 깨진 파일
        raise LLMError(f"bad image: {e}") from e
    b64 = base64.b64encode(small).decode()
    return await _chat(
        [
            {"type": "text", "text": prompt},
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
        ]
    )


async def text_json(prompt: str) -> dict:
    return await _chat(prompt)
