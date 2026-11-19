"""PRD 3.7 API 명세의 요청·응답 형식. 형식을 바꾸면 Flutter 쪽 모델도 같이 바꿉니다."""

from typing import Literal

from pydantic import BaseModel, Field

Language = Literal["vi", "en", "fil", "km", "ko"]


# ---------- users (개발자1) ----------
class UserCreate(BaseModel):
    language: Language
    residence_type: str = Field(examples=["worker"])  # worker, marriage, student 등
    nickname: str


class UserOut(BaseModel):
    user_id: str
    level: int


# ---------- stores (개발자1) ----------
class MenuItem(BaseModel):
    id: str | None = None
    name: str
    price: int | None = None
    unit: str | None = None
    options: list[str] = []


class StoreOut(BaseModel):
    id: str
    name: str
    type: str
    menu_items: list[MenuItem]


# ---------- ai/menu-scan (개발자1) ----------
class ScannedItem(BaseModel):
    name: str
    price: int | None = None  # 지금은 읽지 않음 (항상 null). 메뉴 이름 정확도에 집중
    unit: str | None = None
    confidence: float = Field(ge=0, le=1)
    corrected_from: str | None = None  # 메뉴 사전으로 고쳤으면 원래 읽은 글자


class MenuScanOut(BaseModel):
    items: list[ScannedItem]
    fallback: bool = False  # true면 AI 대신 시연용 대체 응답 (DEMO_FALLBACK=true일 때만)
    category: str | None = None  # 힌트로 쓴 업종 (places.category_small)
    raw_lines: list[str] = []  # AI가 사진에서 줄 단위로 읽은 원래 글자 (디버그·직접 수정용)
    error: str | None = None  # 인식 실패 이유: "llm_error", "no_menu" 등. 앱은 다시 찍기/템플릿으로 안내
    elapsed_ms: int = 0  # 요청을 받아서 응답하기까지 걸린 전체 시간 (밀리초)
    llm_ms: int = 0  # 그중 AI 호출에 걸린 시간 (밀리초)


# ---------- missions (개발자3) ----------
class Mission(BaseModel):
    id: str
    title: str
    store_type: str
    target_pattern: str
    reward: int


class MissionsOut(BaseModel):
    missions: list[Mission]


# ---------- ai/compose (개발자2) ----------
class ComposeIn(BaseModel):
    menu_item: str
    selected_options: list[str] = []
    language: Language


class Card(BaseModel):
    word: str
    meaning: str


class ComposeOut(BaseModel):
    cards: list[Card]
    sentence: str
    feedback: str | None = None
    meaning: str


# ---------- ai/pronunciation, ai/tts (개발자2) ----------
class PronunciationIn(BaseModel):
    """음성인식은 기기(Android·iOS·웹 기본 STT)에서 하고, 받아 적은 글자만 보냅니다."""

    transcript: str
    target_sentence: str
    language: Language = "vi"


class PronunciationOut(BaseModel):
    transcript: str
    score: int = Field(ge=0, le=100)
    wrong_words: list[str]
    feedback: str  # 한국어 한두 문장 조언


class TtsIn(BaseModel):
    text: str


class TtsOut(BaseModel):
    audio_url: str | None  # None이면 앱에서 기기 기본 TTS 사용


# ---------- attempts (개발자3) ----------
class AttemptIn(BaseModel):
    user_id: str
    mission_id: str
    step: int = Field(ge=1, le=4)
    sentence: str


class AttemptOut(BaseModel):
    saved: bool
    next_step: int | None


# ---------- receipts (개발자3, 인식 함수는 개발자1) ----------
class Coupon(BaseModel):
    id: str
    value: int
    expires_at: str


class ReceiptOut(BaseModel):
    verified: bool
    reason: str
    coupon: Coupon | None = None


class ReceiptScan(BaseModel):
    """개발자1이 제공하는 영수증 인식 결과 (scan_receipt 반환값)."""

    store_name: str | None = None
    business_no: str | None = None
    receipt_no: str | None = None
    issued_at: str | None = None  # ISO 8601
    amount: int | None = None
    confidence: float = 0.0


# ---------- admin (개발자3) ----------
class AdminStatsOut(BaseModel):
    missions: int
    step_counts: dict[str, int]
    store_visits: dict[str, int]
