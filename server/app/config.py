from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    supabase_url: str = ""
    supabase_service_key: str = ""

    llm_base_url: str = ""
    llm_api_key: str = ""
    llm_model: str = ""
    llm_timeout: float = 30.0
    # AI에 보내는 사진 크기 (긴 변 px). 손글씨는 클수록 잘 읽지만 느려집니다
    image_max_side: int = 3072
    image_quality: int = 95
    # 메뉴판을 가로 띠 몇 조각으로 나눠 읽을지. 0=자동(세로 사진 3, 가로 사진 2), 1=나누지 않음
    image_tiles: int = 0
    # true면 AI 실패 시 시연용 고정 메뉴(삼겹살 등)를 돌려줌. 리허설·네트워크 장애 대비용
    demo_fallback: bool = False

    # 영수증 유효 기간(일). 인터넷 영수증으로 테스트할 때만 .env에서 늘리기 (개발자3)
    receipt_valid_days: int = 7
    # true면 메모리 DB에 영수증 테스트용 가게(app/test_stores.py)를 추가 (개발자3)
    receipt_test_stores: bool = False

    # 카카오 로컬 API (REST 키). 영수증 가게 주소 → 좌표 변환에 씁니다. 비우면 좌표 없이 저장
    kakao_rest_api_key: str = ""

    # 로그인 (개발자1). AUTH_SECRET이 비면 서버를 켤 때마다 바뀌어서 재시작하면 다시 로그인해야 함
    auth_secret: str = ""
    token_days: int = 30
    # 구글 로그인을 허용할 OAuth 클라이언트 ID (웹·Android 등 여러 개면 쉼표로)
    google_client_ids: str = ""

    @property
    def use_supabase(self) -> bool:
        return bool(self.supabase_url and self.supabase_service_key)

    @property
    def use_llm(self) -> bool:
        return bool(self.llm_base_url and self.llm_api_key and self.llm_model)


settings = Settings()
