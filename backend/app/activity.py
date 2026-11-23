from datetime import date, datetime, timedelta, timezone
from uuid import UUID

from fastapi import Header


def local_login_date(now: datetime, offset_minutes: int) -> date:
    return now.astimezone(timezone(timedelta(minutes=offset_minutes))).date()


def activity_date(
    offset_minutes: int = Header(default=0, ge=-720, le=840, alias="X-Timezone-Offset"),
) -> date:
    return local_login_date(datetime.now(timezone.utc), offset_minutes)


def record_login(conn, user_id: UUID, today: date) -> dict:
    row = conn.execute(
        "SELECT last_login_date,login_streak,login_count FROM accounts WHERE id=%s FOR UPDATE",
        (user_id,),
    ).fetchone()
    last = row["last_login_date"]
    new_day = conn.execute(
        "INSERT INTO login_days(user_id,day) VALUES (%s,%s) ON CONFLICT DO NOTHING RETURNING day",
        (user_id, today),
    ).fetchone()
    if today == last or (last is not None and today < last and new_day is None):
        return row

    if last is None or today > last:
        row["login_streak"] = row["login_streak"] + 1 if last == today - timedelta(days=1) else 1
        row["last_login_date"] = today
    row["login_count"] += int(new_day is not None)
    conn.execute(
        "UPDATE accounts SET last_login_date=%s,login_streak=%s,login_count=%s WHERE id=%s",
        (row["last_login_date"], row["login_streak"], row["login_count"], user_id),
    )
    return row


def current_streak(account: dict, today: date) -> int:
    last = account["last_login_date"]
    return account["login_streak"] if last and last >= today - timedelta(days=1) else 0


def activity_summary(conn, user_id: UUID, today: date, account: dict) -> dict:
    monday = today - timedelta(days=today.weekday())
    visits = conn.execute(
        "SELECT day FROM login_days WHERE user_id=%s AND day BETWEEN %s AND %s ORDER BY day",
        (user_id, monday, today),
    ).fetchall()
    record = conn.execute(
        """
        SELECT COALESCE(MAX(run_length), 0) AS best_streak
        FROM (
            SELECT COUNT(*) AS run_length
            FROM (
                SELECT day - ROW_NUMBER() OVER (ORDER BY day)::int AS run_start
                FROM login_days
                WHERE user_id=%s
            ) AS numbered_visits
            GROUP BY run_start
        ) AS runs
        """,
        (user_id,),
    ).fetchone()
    return {
        "login_count": account["login_count"],
        "login_streak": current_streak(account, today),
        "best_streak": max(account["login_streak"], record["best_streak"]),
        "weekdays": [visit["day"].isoweekday() for visit in visits],
    }
