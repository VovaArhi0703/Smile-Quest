"""PostgreSQL integration tests for authenticated task sync."""

import os
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest import TestCase, skipUnless
from uuid import uuid4

import psycopg
from fastapi.testclient import TestClient
from psycopg import sql
from psycopg.conninfo import make_conninfo

from backend.app import main


TEST_DSN = os.environ.get("TASKS_TEST_DATABASE_URL")
MIGRATION = Path(__file__).with_name("migrations") / "001_user_tasks.sql"


@skipUnless(TEST_DSN, "Set TASKS_TEST_DATABASE_URL to a test PostgreSQL database")
class TaskSyncTest(TestCase):
    @classmethod
    def setUpClass(cls):
        schema = f"tasks_test_{uuid4().hex}"
        with psycopg.connect(TEST_DSN) as conn:
            conn.execute(sql.SQL("CREATE SCHEMA {}").format(sql.Identifier(schema)))
        cls.addClassCleanup(cls.drop_schema, schema)
        cls.task_dsn = make_conninfo(TEST_DSN, options=f"-c search_path={schema},public")
        with psycopg.connect(cls.task_dsn, autocommit=True) as conn:
            conn.execute("CREATE TABLE accounts (id uuid PRIMARY KEY)")
            conn.execute(
                """
                CREATE TABLE sessions (
                  token_hash text PRIMARY KEY,
                  user_id uuid NOT NULL REFERENCES accounts(id),
                  expires_at timestamptz NOT NULL
                )
                """
            )
            migration = MIGRATION.read_text(encoding="utf-8")
            conn.execute(migration)
            conn.execute(migration)
        cls.addClassCleanup(setattr, main, "DATABASE_URL", main.DATABASE_URL)
        main.DATABASE_URL = cls.task_dsn
        cls.client = cls.enterClassContext(TestClient(main.app))

    @staticmethod
    def drop_schema(schema):
        with psycopg.connect(TEST_DSN) as conn:
            conn.execute(sql.SQL("DROP SCHEMA {} CASCADE").format(sql.Identifier(schema)))

    def setUp(self):
        self.first = self.create_session()
        self.second = self.create_session()

    def create_session(self):
        user_id = uuid4()
        token = uuid4().hex
        with psycopg.connect(self.task_dsn) as conn:
            conn.execute("INSERT INTO accounts VALUES (%s)", (user_id,))
            conn.execute(
                "INSERT INTO sessions VALUES (%s,%s,now()+interval '1 day')",
                (main.token_hash(token), user_id),
            )
        return {"Authorization": f"Bearer {token}"}

    def sync(self, headers, **changes):
        response = self.client.post("/tasks/sync", headers=headers, json=changes)
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["tasks"]

    @staticmethod
    def task(task_id="task-1", **values):
        return {
            "id": task_id,
            "kind": "period",
            "title": "Поднять брови",
            "sectionRoute": "/face_exercises",
            "exerciseRoute": "/face_1",
            "startDate": "2026-11-20",
            "endDate": "2026-11-24",
            "hour": 14,
            "minute": 30,
            "repeat": {"days": [2, 1, 2], "exerciseReminders": True},
            **values,
        }

    def test_import_and_update_preserve_creation_order(self):
        legacy_note = "Да, сделать перед завтраком.\n" * 500
        original = self.task("1700000000000000", comment=legacy_note)
        other = self.task("aaa")
        tasks = self.sync(self.first, imports=[original, other])
        self.assertEqual([task["id"] for task in tasks], [original["id"], other["id"]])
        self.assertEqual(tasks[0]["repeat"]["days"], [1, 2])
        self.assertEqual(tasks[0]["endDate"], "2026-11-24")
        self.assertEqual(tasks[0]["comment"], legacy_note)
        edited = {**original, "comment": "Тест", "completed": True}
        updated = self.sync(self.first, upserts=[edited])
        self.assertEqual(updated[0]["comment"], "Тест")
        self.assertTrue(updated[0]["completed"])
        self.assertEqual(self.sync(self.first, imports=[original, other]), updated)
        self.assertEqual(self.client.get("/tasks", headers=self.first).json(), {"tasks": updated})

    def test_authentication_and_isolation_include_tombstones(self):
        self.assertEqual(self.client.get("/tasks").status_code, 401)
        self.assertEqual(self.client.post("/tasks/sync", json={}).status_code, 401)
        request = self.task()
        first = self.sync(self.first, upserts=[request])
        self.assertEqual(self.client.get("/tasks", headers=self.second).json(), {"tasks": []})
        self.assertEqual(self.sync(self.second, deletes=[request["id"]]), [])
        self.assertEqual(self.sync(self.second, imports=[request]), [])
        self.assertEqual(self.sync(self.first), first)

    def test_deleted_task_cannot_be_restored_by_mobile_retries(self):
        request = self.task("deleted-task")
        self.sync(self.first, upserts=[request])
        self.assertEqual(self.sync(self.first, deletes=[request["id"]]), [])
        self.assertEqual(self.sync(self.first, deletes=[request["id"], request["id"]]), [])
        self.assertEqual(self.sync(self.first, imports=[request], upserts=[request]), [])
        with psycopg.connect(self.task_dsn) as conn:
            data = conn.execute(
                "SELECT task_data FROM user_tasks WHERE task_id=%s", (request["id"],)
            ).fetchone()[0]
            self.assertIsNone(data)

    def test_concurrent_clients_keep_other_tasks_and_respect_deletions(self):
        left, right, retired = (self.task(name) for name in ("left", "right", "retired"))
        with ThreadPoolExecutor(max_workers=2) as workers:
            device_one = workers.submit(self.sync, self.first, upserts=[left, retired])
            device_two = workers.submit(
                self.sync, self.first, upserts=[right], deletes=[retired["id"]]
            )
            device_one.result()
            device_two.result()
        self.assertEqual({task["id"] for task in self.sync(self.first)}, {"left", "right"})

    def test_invalid_batch_does_not_write_tasks(self):
        for invalid in (
            self.task("bad-date", startDate="2026-02-30"),
            self.task("bad-time", hour=24),
            self.task("bad-range", endDate="2026-11-19"),
            self.task("fake-owner", user_id=str(uuid4())),
        ):
            with self.subTest(task_id=invalid["id"]):
                response = self.client.post(
                    "/tasks/sync",
                    headers=self.first,
                    json={"upserts": [self.task(), invalid]},
                )
                self.assertEqual(response.status_code, 422)
                self.assertEqual(self.sync(self.first), [])
