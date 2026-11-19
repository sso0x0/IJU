# 담당: 개발자1 — 커뮤니티: "누가 어느 가게에서 어떤 문장을 말했다" 글과 팔로우.
# 글 목록은 로그인 없이도 볼 수 있고, 글쓰기·팔로우는 `Authorization: Bearer <토큰>`이 필요합니다.
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, Header, Query
from pydantic import BaseModel, Field

from ..auth import AuthError, current_user
from ..db import table

router = APIRouter(prefix="/community", tags=["community"])

KST = timezone(timedelta(hours=9))


class PostIn(BaseModel):
    store_name: str = Field(min_length=1, max_length=60)
    sentence: str = Field(min_length=1, max_length=200)
    meaning: str | None = Field(default=None, max_length=300)
    body: str = Field(default="", max_length=1000)
    lat: float | None = None
    lng: float | None = None


class PostOut(BaseModel):
    id: str
    user_id: str
    nickname: str
    store_name: str
    sentence: str
    meaning: str | None = None
    body: str = ""
    lat: float | None = None
    lng: float | None = None
    created_at: str
    mine: bool = False
    following: bool = False


class PostsOut(BaseModel):
    posts: list[PostOut]
    following_count: int = 0
    has_more: bool = False  # 다음 쪽(offset + limit)이 더 있는지


class SharedPlaceOut(BaseModel):
    user_id: str
    nickname: str
    store_name: str
    sentence: str
    meaning: str | None = None
    lat: float
    lng: float
    ordered_at: str
    mine: bool = False
    following: bool = False


class SharedPlacesOut(BaseModel):
    places: list[SharedPlaceOut]


class FollowOut(BaseModel):
    user_id: str
    following: bool


def _viewer(authorization: str | None = Header(default=None)) -> dict[str, Any] | None:
    """로그인했으면 사용자, 아니면 None (목록은 누구나 볼 수 있어요)."""
    if not authorization:
        return None
    try:
        return current_user(authorization)
    except AuthError:
        return None


def _following_ids(user_id: str) -> set[str]:
    return {str(r["followee_id"]) for r in table("follows").select_eq("follower_id", user_id)}


def _post(row: dict[str, Any], viewer_id: str | None, following: set[str]) -> PostOut:
    author = str(row["user_id"])
    return PostOut(
        id=str(row["id"]),
        user_id=author,
        nickname=row.get("nickname") or "이주 친구",
        store_name=row["store_name"],
        sentence=row["sentence"],
        meaning=row.get("meaning"),
        body=row.get("body") or "",
        lat=row.get("lat"),
        lng=row.get("lng"),
        created_at=str(row.get("created_at") or ""),
        mine=viewer_id == author,
        following=author in following,
    )


@router.get("/posts", response_model=PostsOut)
def list_posts(
    following: bool = False,
    author: str | None = None,
    limit: int = Query(default=10, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
    viewer: dict[str, Any] | None = Depends(_viewer),
):
    """전체 글(최신 순)을 [limit]개씩. following=true면 팔로우한 사람 글만, author=me|<id>면 그 사람 글만."""
    viewer_id = str(viewer["id"]) if viewer else None
    follows = _following_ids(viewer_id) if viewer_id else set()
    if author == "me":
        if not viewer_id:
            raise AuthError(401, "LOGIN_REQUIRED", "로그인이 필요해요.")
        author = viewer_id
    rows = table("community_posts").select_eq("user_id", author) if author else table("community_posts").all()
    if following:
        rows = [r for r in rows if str(r["user_id"]) in follows]
    rows.sort(key=lambda r: str(r.get("created_at") or ""), reverse=True)
    page = rows[offset : offset + limit]
    return PostsOut(
        posts=[_post(r, viewer_id, follows) for r in page],
        following_count=len(follows),
        has_more=offset + limit < len(rows),
    )


@router.get("/shared-places", response_model=SharedPlacesOut)
def shared_places(following: bool = False, viewer: dict[str, Any] | None = Depends(_viewer)):
    """'커뮤니티 지도에 공유'를 켠 사람들의 내 지도 (위치가 있는 가게만, 최신 순)."""
    viewer_id = str(viewer["id"]) if viewer else None
    follows = _following_ids(viewer_id) if viewer_id else set()
    try:
        sharers = {str(u["id"]): u for u in table("users").select_eq("share_map", True)}
    except Exception:  # users.share_map 열을 아직 안 만들었으면 (community_schema.sql) 빈 지도
        sharers = {}
    if following:
        sharers = {k: v for k, v in sharers.items() if k in follows}
    rows = [
        r
        for r in table("order_places").all()
        if str(r.get("user_id")) in sharers and r.get("lat") is not None and r.get("lng") is not None
    ]
    rows.sort(key=lambda r: str(r.get("ordered_at") or ""), reverse=True)
    return SharedPlacesOut(
        places=[
            SharedPlaceOut(
                user_id=str(r["user_id"]),
                nickname=sharers[str(r["user_id"])].get("nickname") or "이주 친구",
                store_name=r["store_name"],
                sentence=r["sentence"],
                meaning=r.get("meaning"),
                lat=r["lat"],
                lng=r["lng"],
                ordered_at=str(r.get("ordered_at") or ""),
                mine=str(r["user_id"]) == viewer_id,
                following=str(r["user_id"]) in follows,
            )
            for r in rows[:200]
        ]
    )


@router.post("/posts", response_model=PostOut)
def write_post(body: PostIn, user: dict = Depends(current_user)):
    row = table("community_posts").insert(
        {
            "user_id": user["id"],
            "nickname": user.get("nickname") or user.get("login_id") or "이주 친구",
            **body.model_dump(),
            "created_at": datetime.now(KST).isoformat(),
        }
    )
    return _post(row, str(user["id"]), set())


@router.delete("/posts/{post_id}", response_model=FollowOut)
def delete_post(post_id: str, user: dict = Depends(current_user)):
    """내 글만 지울 수 있어요."""
    table("community_posts").delete_match({"id": post_id, "user_id": user["id"]})
    return FollowOut(user_id=str(user["id"]), following=False)


@router.post("/follow/{user_id}", response_model=FollowOut)
def follow(user_id: str, user: dict = Depends(current_user)):
    if user_id == str(user["id"]):
        raise AuthError(400, "SELF_FOLLOW", "나는 팔로우할 수 없어요.")
    if user_id not in _following_ids(str(user["id"])):
        table("follows").insert(
            {
                "follower_id": user["id"],
                "followee_id": user_id,
                "created_at": datetime.now(KST).isoformat(),
            }
        )
    return FollowOut(user_id=user_id, following=True)


@router.delete("/follow/{user_id}", response_model=FollowOut)
def unfollow(user_id: str, user: dict = Depends(current_user)):
    table("follows").delete_match({"follower_id": user["id"], "followee_id": user_id})
    return FollowOut(user_id=user_id, following=False)
