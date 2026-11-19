# 담당: 개발자2 — 지금은 목 응답입니다. STT·TTS API를 붙이세요.
from fastapi import APIRouter, File, Form, UploadFile

from ..schemas import PronunciationOut, TtsIn, TtsOut

router = APIRouter(tags=["ai"])


@router.post("/ai/pronunciation", response_model=PronunciationOut)
async def pronunciation(audio: UploadFile = File(...), target_sentence: str = Form(...)):
    # TODO(개발자2): STT → 목표 문장과 어절 단위 비교 → 일치율 점수
    await audio.read()
    return PronunciationOut(transcript=target_sentence, score=100, wrong_words=[])


@router.post("/ai/tts", response_model=TtsOut)
async def tts(body: TtsIn):
    # TODO(개발자2): 외부 TTS 연동. None이면 앱에서 기기 기본 TTS로 재생
    return TtsOut(audio_url=None)
