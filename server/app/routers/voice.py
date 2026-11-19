# 담당: 개발자2 — 음성인식은 기기에서 하고, 서버는 받아 적은 문장을 채점·조언합니다.
import logging

from fastapi import APIRouter

from .. import llm
from ..scoring import rule_feedback, score
from ..schemas import PronunciationIn, PronunciationOut, TtsIn, TtsOut

router = APIRouter(tags=["ai"])
log = logging.getLogger(__name__)


def _prompt(body: PronunciationIn, wrong: list[tuple[str, str]]) -> str:
    pairs = ", ".join(f"'{got or '(말 안 함)'}' → '{exp or '(필요 없음)'}'" for got, exp in wrong)
    return f"""너는 외국인에게 한국어 발음을 가르치는 선생님이야.
목표 문장: {body.target_sentence}
음성인식 결과: {body.transcript}
틀린 부분(들린 말 → 원래 말): {pairs}

가장 중요한 한 가지를 고쳐 주는 조언을 한국어 한 문장(50자 이내)으로 써.
받침, 모음, 조사처럼 구체적인 소리를 짚어 줘. 예) ‘구이용으로’의 ㅇ 받침을 또렷하게 말해 보세요.
아래 JSON 하나만 답해.
{{"feedback":"조언"}}"""


@router.post("/ai/pronunciation", response_model=PronunciationOut)
async def pronunciation(body: PronunciationIn):
    result = score(body.transcript, body.target_sentence)
    feedback = rule_feedback(result)
    if result.pairs:
        try:
            data = await llm.text_json(_prompt(body, result.pairs[:3]))
            feedback = str(data["feedback"]).strip() or feedback
        except Exception as e:
            log.warning("pronunciation feedback fallback: %s", e)
    return PronunciationOut(
        transcript=body.transcript,
        score=result.score,
        wrong_words=result.wrong_words,
        feedback=feedback,
    )


@router.post("/ai/tts", response_model=TtsOut)
async def tts(body: TtsIn):
    # 앱은 기기 기본 TTS(flutter_tts)로 바로 재생합니다. 외부 TTS(CLOVA 등)를 붙이면 audio_url을 채우세요.
    return TtsOut(audio_url=None)
