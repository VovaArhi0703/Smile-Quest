"""Account-owned task lists and incremental updates from the mobile app."""

from __future__ import annotations

import re
from datetime import date
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends
from psycopg.types.json import Jsonb
from pydantic import (
    BaseModel,
    BeforeValidator,
    ConfigDict,
    Field,
    StrictBool,
    StrictInt,
    StringConstraints,
    model_validator,
)


def parse_date(value: object) -> date:
    if not isinstance(value, str) or re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value) is None:
        raise ValueError("Expected an ISO calendar date")
    return date.fromisoformat(value)


TaskId = Annotated[str, StringConstraints(min_length=1, max_length=128, pattern=r"^[a-zA-Z0-9_-]+$")]
Route = Annotated[str, StringConstraints(max_length=256, pattern=r"^(?:/[a-zA-Z0-9_-]+)?$")]
CalendarDate = Annotated[date, BeforeValidator(parse_date)]
Weekday = Annotated[StrictInt, Field(ge=1, le=7)]
PositiveInteger = Annotated[StrictInt, Field(ge=1, le=2_147_483_647)]


class TaskRepeat(BaseModel):
    model_config = ConfigDict(extra="forbid")

    days: list[Weekday] = Field(default_factory=list, max_length=7)
    daysOff: list[Weekday] = Field(default_factory=list, max_length=7)
    exerciseReminders: StrictBool = False
    intervalHours: PositiveInteger = 3
    sets: PositiveInteger = 2

    @model_validator(mode="after")
    def normalize_days(self) -> TaskRepeat:
        self.days = sorted(set(self.days))
        self.daysOff = sorted(set(self.daysOff))
        return self


class TaskData(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: TaskId
    kind: Literal["simple", "period", "deadline"]
    title: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1)]
    sectionRoute: Route = ""
    exerciseRoute: Route = ""
    comment: str = ""
    startDate: CalendarDate | None = None
    endDate: CalendarDate | None = None
    hour: Annotated[StrictInt, Field(ge=0, le=23)] | None = None
    minute: Annotated[StrictInt, Field(ge=0, le=59)] | None = None
    repeat: TaskRepeat = Field(default_factory=TaskRepeat)
    completed: StrictBool = False

    @model_validator(mode="after")
    def validate_schedule(self) -> TaskData:
        if self.endDate is not None and (self.startDate is None or self.endDate < self.startDate):
            raise ValueError("The end date must be on or after the start date")
        return self


class TaskSyncBody(BaseModel):
    model_config = ConfigDict(extra="forbid")

    imports: list[TaskData] = Field(default_factory=list, max_length=200)
    upserts: list[TaskData] = Field(default_factory=list, max_length=200)
    deletes: list[TaskId] = Field(default_factory=list, max_length=200)


def _list_tasks(conn, user_id: UUID) -> dict:
    rows = conn.execute(
        """
        SELECT task_data
        FROM user_tasks
        WHERE user_id=%s AND deleted_at IS NULL
        ORDER BY created_order
        """,
        (user_id,),
    ).fetchall()
    return {"tasks": [row["task_data"] for row in rows]}


def _apply_updates(conn, user_id: UUID, changes: TaskSyncBody) -> None:
    # Serialize updates for one account, even when devices send overlapping batches.
    conn.execute("SELECT id FROM accounts WHERE id=%s FOR NO KEY UPDATE", (user_id,))
    # A tombstone also covers a concurrent deletion before the original item has
    # reached the server. Remove the stored task content when it is deleted.
    if changes.deletes:
        conn.execute(
            """
            INSERT INTO user_tasks (user_id, task_id, deleted_at)
            SELECT %s, task_id, now() FROM unnest(%s::text[]) AS ids(task_id)
            ON CONFLICT (user_id, task_id) DO UPDATE
            SET deleted_at=EXCLUDED.deleted_at, task_data=NULL
            WHERE user_tasks.deleted_at IS NULL
            """,
            (user_id, list(dict.fromkeys(changes.deletes))),
        )
    with conn.cursor() as cursor:
        if changes.imports:
            cursor.executemany(
                """
                INSERT INTO user_tasks (user_id, task_id, task_data) VALUES (%s, %s, %s)
                ON CONFLICT (user_id, task_id) DO NOTHING
                """,
                [
                    (user_id, task.id, Jsonb(task.model_dump(mode="json")))
                    for task in changes.imports
                ],
            )
        if changes.upserts:
            cursor.executemany(
                """
                INSERT INTO user_tasks (user_id, task_id, task_data) VALUES (%s, %s, %s)
                ON CONFLICT (user_id, task_id) DO UPDATE SET task_data=EXCLUDED.task_data
                WHERE user_tasks.deleted_at IS NULL
                  AND user_tasks.task_data IS DISTINCT FROM EXCLUDED.task_data
                """,
                [
                    (user_id, task.id, Jsonb(task.model_dump(mode="json")))
                    for task in changes.upserts
                ],
            )


def create_tasks_router(db, require_user) -> APIRouter:
    router = APIRouter(prefix="/tasks", tags=["tasks"])

    @router.get("")
    def tasks(user_id: UUID = Depends(require_user), conn=Depends(db)):
        return _list_tasks(conn, user_id)

    @router.post("/sync")
    def sync_tasks(body: TaskSyncBody, user_id: UUID = Depends(require_user), conn=Depends(db)):
        if body.imports or body.upserts or body.deletes:
            _apply_updates(conn, user_id, body)
        result = _list_tasks(conn, user_id)
        conn.commit()
        return result

    return router
