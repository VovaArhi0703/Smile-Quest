"""End-to-end local check of the data API and authenticated exercise socket."""

import asyncio
import base64
import io
import json
import os
import uuid
from pathlib import Path

import httpx
import matplotlib
import websockets
from PIL import Image

API = os.environ.get("DATA_API_URL", "http://127.0.0.1:8100")
EXERCISES = os.environ.get("EXERCISE_WS_URL", "ws://127.0.0.1:8001/ws")


def assert_ok(response):
    response.raise_for_status()
    return response.json()


async def main():
    with httpx.Client(base_url=API, timeout=15) as client:
        assert assert_ok(client.get("/health")) == {"status": "ok"}
        email = f"smoke-{uuid.uuid4().hex[:12]}@example.com"
        first = assert_ok(client.post("/auth/signup", json={
            "email": email, "password": "TestPass_123", "full_name": "Тест Пациент"
        }))
        token = first["token"]
        headers = {"Authorization": f"Bearer {token}"}
        assert assert_ok(client.get("/auth/me", headers=headers))["email"] == email
        assert assert_ok(client.get("/profile", headers=headers))["pet_name"] == ""
        changed = assert_ok(client.patch("/profile", headers=headers, json={
            "pet_name": "Лягушонок", "pet_age": "3", "avatar_url": "assets/image/cat.png"
        }))
        assert changed["pet_name"] == "Лягушонок"
        assert changed["pet_age"] == "3"
        assert assert_ok(client.get("/profile", headers=headers))["avatar_url"] == "assets/image/cat.png"
        assert_ok(client.patch("/progress", headers=headers, json={"values": {
            "opened_sections": ["Мимика"], "last_exercise_number": 1
        }}))
        progress = assert_ok(client.get("/progress", headers=headers))
        assert progress["opened_sections"] == ["Мимика"]
        assert progress["last_exercise_number"] == 1
        reward = assert_ok(client.post("/rewards", headers=headers, json={"kind": "signup"}))
        assert reward["awarded"] is True
        assert assert_ok(client.post("/rewards", headers=headers, json={"kind": "signup"}))["awarded"] is False

        image = Image.new("RGB", (64, 64), "green")
        output = io.BytesIO()
        image.save(output, format="JPEG")
        photo = assert_ok(client.post(
            "/photos", headers={**headers, "Content-Type": "image/jpeg"},
            params={"section": "Лицо", "exercise": "Брови"}, content=output.getvalue()
        ))
        photos = assert_ok(client.get("/photos", headers=headers))
        assert len(photos) == 1 and photos[0]["id"] == photo["id"]
        assert client.get(photos[0]["image_url"]).content == output.getvalue()

        second = assert_ok(client.post("/auth/signup", json={
            "email": f"second-{uuid.uuid4().hex[:12]}@example.com",
            "password": "TestPass_123", "full_name": "Другой Человек"
        }))
        other_headers = {"Authorization": f"Bearer {second['token']}"}
        assert assert_ok(client.get("/photos", headers=other_headers)) == []
        assert assert_ok(client.get("/progress", headers=other_headers)) == {}
        assert client.get("/profile").status_code == 401

        async with websockets.connect(EXERCISES) as socket:
            await socket.send(json.dumps({"mode": "init", "exercise": "face_1", "image": "x"}))
            assert json.loads(await socket.recv())["error"] == "unauthorized"
            await socket.send(json.dumps({"mode": "auth", "token": token}))
            assert json.loads(await socket.recv())["status"] == "authenticated"
            sample = Path(matplotlib.get_data_path()) / "sample_data" / "grace_hopper.jpg"
            await socket.send(json.dumps({
                "mode": "observe", "exercise": "face_1",
                "image": base64.b64encode(sample.read_bytes()).decode("ascii"),
            }))
            observation = json.loads(await socket.recv())
            assert observation["status"] == "observation"
            assert observation["features"]["blue_gap"] > 0
            await socket.send(json.dumps({"mode": "auth", "token": "invalid"}))
            assert json.loads(await socket.recv())["error"] == "unauthorized"

        assert client.post("/auth/logout", headers=headers).status_code == 204
        assert client.get("/auth/me", headers=headers).status_code == 401
        login = assert_ok(client.post("/auth/login", json={"email": email, "password": "TestPass_123"}))
        assert login["user"]["id"] == first["user"]["id"]
        assert assert_ok(client.get("/profile", headers={"Authorization": f"Bearer {login['token']}"}))["pet_name"] == "Лягушонок"
    print("OK: auth, profile, progress, rewards, private photos, account isolation, exercise auth")


if __name__ == "__main__":
    asyncio.run(main())
