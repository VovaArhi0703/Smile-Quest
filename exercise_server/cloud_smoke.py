"""Check the deployed exercise protocol with a public sample face."""

from __future__ import annotations

import asyncio
import base64
import json
import math
import uuid
from pathlib import Path

import httpx
import matplotlib
import websockets

from exercise_server.detail_metrics import DETAIL_EXERCISES
from exercise_server.lip_variant_metrics import LIP_VARIANT_EXERCISES
from exercise_server.oral_metrics import ORAL_EXERCISES


API_URL = "https://api.smilequest.ru"
EXERCISE_WS = "wss://exercise.smilequest.ru/ws"
SAMPLE_FACE = Path(matplotlib.get_data_path()) / "sample_data" / "grace_hopper.jpg"
LEGACY_EXERCISES = ("face_1", "face_2", "face_3", "face_4", "face_6", "face_7", "lip_4")
NEW_EXERCISES = ORAL_EXERCISES | DETAIL_EXERCISES | LIP_VARIANT_EXERCISES
OBSERVATION_EXERCISES = (*LEGACY_EXERCISES, *NEW_EXERCISES)


async def main() -> None:
    if not SAMPLE_FACE.is_file():
        raise FileNotFoundError(SAMPLE_FACE)
    image = base64.b64encode(SAMPLE_FACE.read_bytes()).decode("ascii")

    async with httpx.AsyncClient(timeout=15) as http:
        for url in (API_URL, EXERCISE_WS.replace("wss://", "https://").removesuffix("/ws")):
            health = await http.get(f"{url}/health")
            health.raise_for_status()
            assert health.json()["status"] == "ok", url
        email = f"exercise-smoke-{uuid.uuid4().hex[:12]}@example.com"
        response = await http.post(
            f"{API_URL}/auth/signup",
            json={"email": email, "password": uuid.uuid4().hex, "full_name": "Test Patient"},
        )
        response.raise_for_status()
        token = response.json()["token"]

    async with websockets.connect(EXERCISE_WS, max_size=750_000) as ws:
        await ws.send(json.dumps({"mode": "auth", "token": token}))
        assert json.loads(await asyncio.wait_for(ws.recv(), timeout=10))["status"] == "authenticated"

        for exercise in OBSERVATION_EXERCISES:
            await ws.send(json.dumps({"mode": "observe", "exercise": exercise, "image": image}))
            result = json.loads(await asyncio.wait_for(ws.recv(), timeout=10))
            assert result.get("status") == "observation", (exercise, result)
            assert result["landmarks"], exercise
            if exercise == "face_1":
                assert {"33", "133", "263", "362", "53", "283"} <= set(result["landmarks"])
            if exercise == "face_2":
                assert set(result["features"]) == {"blue_gap", "orange_gap"}
            if exercise == "face_3":
                assert {"blue_gap", "orange_gap", "blue_squeeze", "orange_squeeze"} == set(result["features"])
                assert {"111", "117", "340", "346"} <= set(result["landmarks"])
            if exercise == "face_6":
                assert {"blue_gap", "orange_gap", "blue_aperture", "orange_aperture"} == set(result["features"])
            if exercise == "lip_4":
                assert set(result["features"]) == {"blue_gap", "orange_gap"}
            if exercise in NEW_EXERCISES:
                assert set(result["features"]) == set(NEW_EXERCISES[exercise]), exercise
                assert all(math.isfinite(value) for value in result["features"].values()), exercise
                assert all(
                    len(point) == 2 and all(0 <= value <= 1 for value in point)
                    for point in result["landmarks"].values()
                ), exercise

        await ws.send(json.dumps({"mode": "init", "exercise": "lip_4", "image": image}))
        result = json.loads(await asyncio.wait_for(ws.recv(), timeout=10))
        assert result.get("status") == "baseline_set", result
        await asyncio.sleep(0.13)
        await ws.send(json.dumps({"mode": "track", "exercise": "lip_4", "image": image}))
        result = json.loads(await asyncio.wait_for(ws.recv(), timeout=10))
        assert result.get("status") == "tracking", result
        assert abs(result["delta"]["smile_score"]) < 0.001, result

    print(f"OK: public health, authenticated observations for {len(OBSERVATION_EXERCISES)} exercises, and legacy smile tracking")


if __name__ == "__main__":
    asyncio.run(main())
