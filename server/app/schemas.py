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
    # 카드에 보여줄 정보 (language로 요청한 모국어). 실패하면 null
    meaning: str | None = None  # 메뉴 이름 뜻 (예: "Soybean paste stew")
    romanization: str | None = None  # 발음 (예: "doen-jang-jji-gae")
    description: str | None = None  # 한 줄 설명 (예: "Hearty stew with tofu and vegetables")


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
    level: int = 1
    status: Literal["new", "in_progress", "completed"] = "new"
    best_step: int = 0 


class MissionsOut(BaseModel):
    missions: list[Mission]


class MissionGenerateIn(BaseModel):
    """가게 업종·메뉴로 미션을 만듭니다. store_id가 없으면 store_type + menu로 만듭니다."""

    store_id: str | None = None
    store_type: str | None = Field(default=None, examples=["restaurant"])
    menu: list[str] = []
    count: int = Field(default=2, ge=1, le=5)


# ---------- ai/compose (개발자2) ----------
class ComposeIn(BaseModel):
    menu_item: str
    selected_options: list[str] = []
    without: list[str] = []  # '돼지고기랑 두부는 빼 주세요.' 문장의 재료
    ask: list[str] = []  # '고기 육수 들어가요?' 문장의 재료
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
    # ok | low_confidence(→ 재촬영 1회 후 상인 확인 코드) | not_receipt | duplicate_image | duplicate_receipt
    # | unknown_store | expired | daily_limit | wrong_code
    reason: str
    message: str | None = None  # 화면에 그대로 띄울 안내 문구
    store_name: str | None = None
    amount: int | None = None
    coupon: Coupon | None = None


class MerchantConfirmIn(BaseModel):
    user_id: str
    mission_id: str
    code: str  # 사장님이 알려주는 확인 코드


class ReceiptScan(BaseModel):
    """개발자1이 제공하는 영수증 인식 결과 (scan_receipt 반환값)."""

    # 실제로 출력된 영수증 사진인지 (손글씨·화면 촬영이면 false). 판단 못 하면 None (개발자3 추가)
    is_receipt: bool | None = None
    store_name: str | None = None
    business_no: str | None = None
    receipt_no: str | None = None
    issued_at: str | None = None  # ISO 8601
    amount: int | None = None
    confidence: float = 0.0


# ---------- coupons (개발자3) ----------
class CouponItem(BaseModel):
    id: str
    store_id: str | None = None
    store_name: str | None = None
    value: int
    status: Literal["active", "used", "expired"]
    expires_at: str


class CouponsOut(BaseModel):
    coupons: list[CouponItem]


class CouponUseIn(BaseModel):
    user_id: str
    code: str  # 사장님 확인 코드 (손님 혼자 사용 처리 못 하게)


class CouponUseOut(BaseModel):
    used: bool
    reason: str  # ok | not_found | not_owner | already_used | expired | wrong_code
    message: str
    coupon: CouponItem | None = None


# ---------- admin (개발자3) ----------
class AdminStatsOut(BaseModel):
    missions: int
    step_counts: dict[str, int]
    store_visits: dict[str, int]
