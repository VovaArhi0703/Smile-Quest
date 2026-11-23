"""Small authenticated data API. Exercise frames are handled by another service."""

from __future__ import annotations

import hashlib
import hmac
import io
import os
import secrets
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from uuid import UUID, uuid4

import psycopg
from argon2 import PasswordHasher
from argon2.exceptions import VerificationError
from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request, Response
from fastapi.responses import FileResponse
from PIL import Image, UnidentifiedImageError
from psycopg.rows import dict_row
from pydantic import BaseModel, EmailStr, Field

from .activity import activity_date, activity_summary, current_streak, record_login

from .tasks import create_tasks_router

DATABASE_URL = os.environ.get("DATABASE_URL", "")
PHOTO_ROOT = Path(os.environ.get("PHOTO_ROOT", "./photos"))
PHOTO_SIGNING_KEY = os.environ.get("PHOTO_SIGNING_KEY", "")
LOCAL_MODE = os.environ.get("APP_ENV") == "local"
SESSION_LENGTH = timedelta(days=30)
password_hasher = PasswordHasher()
app = FastAPI(title="Smile Quest Data API")


def db():
    with psycopg.connect(DATABASE_URL, row_factory=dict_row) as connection:
        yield connection


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def require_user(
    authorization: str | None = Header(default=None),
    conn=Depends(db),
) -> UUID:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Требуется вход в аккаунт")
    token = authorization[7:]
    row = conn.execute(
        "SELECT user_id FROM sessions WHERE token_hash = %s AND expires_at > now()",
        (token_hash(token),),
    ).fetchone()
    if row is None:
        raise HTTPException(401, "Сессия истекла. Войдите снова")
    return row["user_id"]


app.include_router(create_tasks_router(db, require_user))


def new_session(conn, user_id: UUID) -> str:
    token = secrets.token_urlsafe(48)
    conn.execute(
        "INSERT INTO sessions(token_hash,user_id,expires_at) VALUES (%s,%s,%s)",
        (token_hash(token), user_id, datetime.now(timezone.utc) + SESSION_LENGTH),
    )
    return token


class SignUpBody(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=256)
    full_name: str = Field(min_length=1, max_length=200)


class LoginBody(BaseModel):
    email: EmailStr
    password: str


class PasswordBody(BaseModel):
    password: str = Field(min_length=8, max_length=256)


class ResetRequestBody(BaseModel):
    email: EmailStr


class ProfileBody(BaseModel):
    full_name: str | None = Field(default=None, max_length=200)
    avatar_url: str | None = Field(default=None, max_length=200)
    pet_name: str | None = Field(default=None, max_length=100)
    pet_age: str | None = Field(default=None, max_length=40)


class ProgressBody(BaseModel):
    values: dict[str, str | int | list[str]]


class RewardBody(BaseModel):
    kind: str


@app.get("/health")
def health(conn=Depends(db)):
    conn.execute("SELECT 1")
    return {"status": "ok"}


@app.post("/auth/signup", status_code=201)
def signup(body: SignUpBody, conn=Depends(db), today: date = Depends(activity_date)):
    email = str(body.email).strip().lower()
    try:
        row = conn.execute(
            "INSERT INTO accounts(email,password_hash,full_name) VALUES (%s,%s,%s) RETURNING id",
            (email, password_hasher.hash(body.password), body.full_name.strip()),
        ).fetchone()
    except psycopg.errors.UniqueViolation:
        raise HTTPException(409, "Аккаунт с таким email уже зарегистрирован") from None
    user_id = row["id"]
    conn.execute("INSERT INTO user_progress(user_id) VALUES (%s)", (user_id,))
    record_login(conn, user_id, today)
    token = new_session(conn, user_id)
    conn.commit()
    return {"token": token, "user": {"id": str(user_id), "email": email}}


@app.post("/auth/login")
def login(body: LoginBody, conn=Depends(db), today: date = Depends(activity_date)):
    email = str(body.email).strip().lower()
    row = conn.execute(
        "SELECT id,password_hash FROM accounts WHERE email=%s", (email,)
    ).fetchone()
    if row is None:
        raise HTTPException(401, "Неверный email или пароль")
    try:
        password_hasher.verify(row["password_hash"], body.password)
    except VerificationError:
        raise HTTPException(401, "Неверный email или пароль") from None
    record_login(conn, row["id"], today)
    token = new_session(conn, row["id"])
    conn.commit()
    return {"token": token, "user": {"id": str(row["id"]), "email": email}}


@app.get("/auth/me")
def me(user_id: UUID = Depends(require_user), conn=Depends(db)):
    row = conn.execute("SELECT id,email FROM accounts WHERE id=%s", (user_id,)).fetchone()
    return {"id": str(row["id"]), "email": row["email"]}


@app.post("/auth/logout", status_code=204)
def logout(authorization: str = Header(), user_id: UUID = Depends(require_user), conn=Depends(db)):
    conn.execute("DELETE FROM sessions WHERE token_hash=%s AND user_id=%s", (token_hash(authorization[7:]), user_id))
    conn.commit()
    return Response(status_code=204)


@app.post("/auth/change-password", status_code=204)
def change_password(body: PasswordBody, user_id: UUID = Depends(require_user), conn=Depends(db)):
    conn.execute("UPDATE accounts SET password_hash=%s WHERE id=%s", (password_hasher.hash(body.password), user_id))
    conn.execute("DELETE FROM sessions WHERE user_id=%s", (user_id,))
    conn.commit()
    return Response(status_code=204)


@app.post("/auth/request-reset")
def request_reset(body: ResetRequestBody):
    raise HTTPException(503, "Восстановление пароля по почте пока не настроено")


@app.get("/profile")
def profile(user_id: UUID = Depends(require_user), conn=Depends(db)):
    row = conn.execute(
        "SELECT id,email,full_name,avatar_url,pet_name,pet_age,coins,xp,level FROM accounts WHERE id=%s",
        (user_id,),
    ).fetchone()
    row["id"] = str(row["id"])
    return row


@app.patch("/profile")
def update_profile(body: ProfileBody, user_id: UUID = Depends(require_user), conn=Depends(db)):
    fields = body.model_dump(exclude_unset=True)
    if fields:
        if "avatar_url" in fields and fields["avatar_url"] and not fields["avatar_url"].startswith("assets/"):
            raise HTTPException(400, "Недопустимый аватар")
        for key, value in fields.items():
            conn.execute(f"UPDATE accounts SET {key}=%s WHERE id=%s", (value or "", user_id))
        conn.commit()
    return profile(user_id, conn)


@app.get("/metrics")
def metrics(user_id: UUID = Depends(require_user), conn=Depends(db), today: date = Depends(activity_date)):
    account = conn.execute(
        "SELECT login_streak,login_count,last_login_date FROM accounts WHERE id=%s", (user_id,)
    ).fetchone()
    return {"login_streak": current_streak(account, today), "login_count": account["login_count"]}


@app.post("/activity")
def record_activity(user_id: UUID = Depends(require_user), conn=Depends(db), today: date = Depends(activity_date)):
    account = record_login(conn, user_id, today)
    result = activity_summary(conn, user_id, today, account)
    conn.commit()
    return result


@app.get("/login-days")
def login_days(user_id: UUID = Depends(require_user), conn=Depends(db)):
    rows = conn.execute(
        "SELECT day FROM login_days WHERE user_id=%s AND day >= current_date - interval '35 days' ORDER BY day",
        (user_id,),
    ).fetchall()
    return {"days": [row["day"].isoformat() for row in rows]}


@app.get("/progress")
def progress(user_id: UUID = Depends(require_user), conn=Depends(db)):
    row = conn.execute("SELECT values_json FROM user_progress WHERE user_id=%s", (user_id,)).fetchone()
    return row["values_json"] if row else {}


@app.patch("/progress")
def update_progress(body: ProgressBody, user_id: UUID = Depends(require_user), conn=Depends(db)):
    allowed = {"opened_sections", "last_section_title", "last_section_route", "last_exercise_title", "last_exercise_route", "last_exercise_number"}
    if set(body.values) - allowed:
        raise HTTPException(400, "Неизвестное поле прогресса")
    for key, value in body.values.items():
        if key == "opened_sections" and not isinstance(value, list):
            raise HTTPException(400, "Неверный формат разделов")
        if key == "last_exercise_number" and not isinstance(value, int):
            raise HTTPException(400, "Неверный номер упражнения")
        if key not in {"opened_sections", "last_exercise_number"} and not isinstance(value, str):
            raise HTTPException(400, "Неверный формат прогресса")
    import json
    conn.execute(
        "INSERT INTO user_progress(user_id,values_json) VALUES (%s,%s::jsonb) "
        "ON CONFLICT(user_id) DO UPDATE SET values_json=user_progress.values_json || EXCLUDED.values_json",
        (user_id, json.dumps(body.values, ensure_ascii=False)),
    )
    conn.commit()
    return progress(user_id, conn)


def award_achievements(conn, user_id: UUID) -> list[str]:
    row = conn.execute(
        "SELECT login_count,level FROM accounts WHERE id=%s", (user_id,)
    ).fetchone()
    photo_count = conn.execute(
        "SELECT count(*) AS n FROM users_photos WHERE user_id=%s", (user_id,)
    ).fetchone()["n"]
    candidates = []
    if row["login_count"] >= 3:
        candidates.append("novice")
    if photo_count >= 5:
        candidates.append("photographer")
    if row["level"] >= 5:
        candidates.append("master")
    added = []
    for achievement in candidates:
        result = conn.execute(
            "INSERT INTO user_achievements(user_id,achievement_id) VALUES (%s,%s) ON CONFLICT DO NOTHING RETURNING achievement_id",
            (user_id, achievement),
        ).fetchone()
        if result:
            added.append(achievement)
    return added


def add_points(conn, user_id: UUID, xp_reward: int, coin_reward: int) -> dict:
    row = conn.execute(
        "SELECT xp,coins,level FROM accounts WHERE id=%s FOR UPDATE", (user_id,)
    ).fetchone()
    xp = row["xp"] + xp_reward
    coins = row["coins"] + coin_reward
    level = row["level"]
    while xp >= 100:
        xp -= 100
        coins += 50 * level
        level += 1
    if row["level"] < 5 <= level:
        coins += 500
    conn.execute(
        "UPDATE accounts SET xp=%s,coins=%s,level=%s WHERE id=%s",
        (xp, coins, level, user_id),
    )
    return {"xp": xp, "coins": coins, "level": level}


@app.get("/achievements")
def achievements(user_id: UUID = Depends(require_user), conn=Depends(db)):
    rows = conn.execute(
        "SELECT achievement_id FROM user_achievements WHERE user_id=%s ORDER BY unlocked_at",
        (user_id,),
    ).fetchall()
    return {"ids": [row["achievement_id"] for row in rows]}


@app.post("/achievements/check")
def check_achievements(user_id: UUID = Depends(require_user), conn=Depends(db)):
    added = award_achievements(conn, user_id)
    conn.commit()
    return {"new": added}


@app.post("/rewards")
def reward(body: RewardBody, user_id: UUID = Depends(require_user), conn=Depends(db), today: date = Depends(activity_date)):
    kinds = {
        "login": (10, 5),
        "signup": (40, 0),
        "streak5": (15, 15),
    }
    if body.kind not in kinds:
        raise HTTPException(400, "Неизвестная награда")
    row = conn.execute("SELECT login_streak,last_login_date FROM accounts WHERE id=%s FOR UPDATE", (user_id,)).fetchone()
    if body.kind == "streak5" and current_streak(row, today) < 5:
        raise HTTPException(400, "Серия входов ещё не достигла 5 дней")
    event_key = f"login:{today.isoformat()}" if body.kind == "login" else body.kind
    inserted = conn.execute(
        "INSERT INTO reward_events(user_id,event_key) VALUES (%s,%s) ON CONFLICT DO NOTHING RETURNING event_key",
        (user_id, event_key),
    ).fetchone()
    if not inserted:
        return {"awarded": False}
    xp_reward, coin_reward = kinds[body.kind]
    values = add_points(conn, user_id, xp_reward, coin_reward)
    conn.commit()
    return {"awarded": True, **values}


def sign_photo(photo_id: UUID, exp: int) -> str:
    return hmac.new(PHOTO_SIGNING_KEY.encode(), f"{photo_id}:{exp}".encode(), hashlib.sha256).hexdigest()


@app.post("/photos", status_code=201)
async def upload_photo(
    request: Request,
    section: str = Query(max_length=100),
    exercise: str = Query(max_length=100),
    user_id: UUID = Depends(require_user),
    conn=Depends(db),
):
    raw = await request.body()
    if len(raw) > 6_000_000:
        raise HTTPException(413, "Фото слишком большое")
    try:
        with Image.open(io.BytesIO(raw)) as image:
            if image.format != "JPEG" or image.width * image.height > 20_000_000:
                raise ValueError()
            image.verify()
    except (UnidentifiedImageError, OSError, ValueError):
        raise HTTPException(400, "Нужен корректный JPEG") from None
    photo_id = uuid4()
    file_name = f"{photo_id}.jpg"
    path = PHOTO_ROOT / str(user_id) / file_name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    try:
        conn.execute(
            "INSERT INTO users_photos(id,user_id,file_name,section,exercise) VALUES (%s,%s,%s,%s,%s)",
            (photo_id, user_id, file_name, section, exercise),
        )
        add_points(conn, user_id, 15, 10)
        conn.commit()
    except Exception:
        path.unlink(missing_ok=True)
        raise
    return {"id": str(photo_id)}


@app.get("/photos")
def list_photos(
    request: Request,
    start: datetime | None = None,
    end: datetime | None = None,
    section: str | None = None,
    exercise: str | None = None,
    user_id: UUID = Depends(require_user),
    conn=Depends(db),
):
    clauses = ["user_id=%s"]
    args: list = [user_id]
    for field, op, value in (("date_taken", ">=", start), ("date_taken", "<", end), ("section", "=", section), ("exercise", "=", exercise)):
        if value is not None:
            clauses.append(f"{field}{op}%s")
            args.append(value)
    rows = conn.execute(
        "SELECT id,section,exercise,date_taken FROM users_photos WHERE "
        + " AND ".join(clauses) + " ORDER BY date_taken DESC LIMIT 1000",
        args,
    ).fetchall()
    exp = int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp())
    for row in rows:
        row["image_url"] = f"{request.base_url}photos/{row['id']}/image?exp={exp}&sig={sign_photo(row['id'], exp)}"
        row["id"] = str(row["id"])
        row["date_taken"] = row["date_taken"].isoformat()
    return rows


@app.get("/photos/{photo_id}/image")
def photo_image(photo_id: UUID, exp: int, sig: str, conn=Depends(db)):
    if exp < int(datetime.now(timezone.utc).timestamp()) or not hmac.compare_digest(sig, sign_photo(photo_id, exp)):
        raise HTTPException(403, "Ссылка на фото истекла")
    row = conn.execute("SELECT user_id,file_name FROM users_photos WHERE id=%s", (photo_id,)).fetchone()
    if row is None:
        raise HTTPException(404, "Фото не найдено")
    path = PHOTO_ROOT / str(row["user_id"]) / row["file_name"]
    if not path.is_file():
        raise HTTPException(404, "Файл не найден")
    return FileResponse(path, media_type="image/jpeg", headers={"Cache-Control": "private, max-age=300"})
