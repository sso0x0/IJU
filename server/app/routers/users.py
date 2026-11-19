# 담당: 개발자1
from fastapi import APIRouter

from ..db import table
from ..schemas import UserCreate, UserOut

router = APIRouter(tags=["users"])


@router.post("/users", response_model=UserOut)
def create_user(body: UserCreate):
    row = table("users").insert(
        {
            "nickname": body.nickname,
            "language": body.language,
            "residence_type": body.residence_type,
            "level": 1,
            "points": 0,
        }
    )
    return UserOut(user_id=row["id"], level=row["level"])
