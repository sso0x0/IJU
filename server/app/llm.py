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
from PIL import Image, ImageOps

from .config import settings


class LLMError(Exception):
    pass


def _shrink(image_bytes: bytes, max_side: int | None = None) -> bytes:
    """AI에 보내기 좋게 사진을 다듬습니다.

    - 폰 사진의 회전 정보(EXIF)를 실제 방향으로 적용 (옆으로 누운 사진 방지)
    - 흐린 손글씨가 잘 보이도록 대비를 살짝 올림
    - 긴 변 IMAGE_MAX_SIDE(기본 3072px)까지만 줄이고 JPEG 품질 IMAGE_QUALITY(기본 95)
      손글씨 획이 뭉개지지 않게 크게 보냅니다. 원본이 더 작으면 키우지 않습니다.
    """
    max_side = max_side or settings.image_max_side
    img = Image.open(io.BytesIO(image_bytes))
    img = ImageOps.exif_transpose(img)
    img = img.convert("RGB")
    img = ImageOps.autocontrast(img, cutoff=1)
    img.thumbnail((max_side, max_side))
    out = io.BytesIO()
    img.save(out, format="JPEG", quality=settings.image_quality)
    return out.getvalue()


def _parse_json(text: str) -> dict:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        raise LLMError(f"JSON not found in response: {text[:200]}")
    try:
        return json.loads(match.group(0))
    except json.JSONDecodeError as e:
        raise LLMError(f"invalid JSON: {e}") from e


# 추론형 모델(GPT-5 이후, o 시리즈)은 temperature 지정을 거부합니다.
_NO_TEMPERATURE = ("gpt-5", "gpt-6", "o1", "o3", "o4")


def _body(content: list[dict] | str) -> dict:
    body = {"model": settings.llm_model, "messages": [{"role": "user", "content": content}]}
    if not settings.llm_model.startswith(_NO_TEMPERATURE):
        body["temperature"] = 0
    return body


async def _chat(content: list[dict] | str) -> dict:
    if not settings.use_llm:
        raise LLMError("LLM is not configured")
    try:
        async with httpx.AsyncClient(timeout=settings.llm_timeout) as client:
            res = await client.post(
                f"{settings.llm_base_url.rstrip('/')}/chat/completions",
                headers={"Authorization": f"Bearer {settings.llm_api_key}"},
                json=_body(content),
            )
            if res.status_code >= 400:
                raise LLMError(f"HTTP {res.status_code}: {res.text[:300]}")
            text = res.json()["choices"][0]["message"]["content"]
    except httpx.TimeoutException as e:
        raise LLMError(f"timeout ({settings.llm_timeout:.0f}s 초과)") from e
    except (httpx.HTTPError, KeyError, IndexError, ValueError) as e:
        raise LLMError(f"{type(e).__name__}: {e}") from e
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
            {
                "type": "image_url",
                # detail=high: OpenAI가 이미지를 작게 줄여 보지 않도록 (손글씨 정확도)
                "image_url": {"url": f"data:image/jpeg;base64,{b64}", "detail": "high"},
            },
        ]
    )


async def text_json(prompt: str) -> dict:
    return await _chat(prompt)
