"""WebSocket exercise service. Frames are processed in memory and never stored."""

from __future__ import annotations

import asyncio
import base64
import binascii
import io
import json
import logging
import os
import time
from contextlib import asynccontextmanager
from pathlib import Path

import httpx
import mediapipe as mp
import numpy as np
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from PIL import Image, ImageOps, UnidentifiedImageError
from starlette.websockets import WebSocketDisconnected

from .detail_metrics import DETAIL_EXERCISES, detail_features, detail_landmarks
from .lip_variant_metrics import (
    LIP_VARIANT_EXERCISES,
    lip_variant_features,
    lip_variant_landmarks,
)
from .metrics import (
    CalibrationError,
    EXERCISES,
    FACE_1_LANDMARKS,
    FACE_3_LANDMARKS,
    FACE_3_SQUEEZE_LANDMARKS,
    LIP_4_LANDMARKS,
    compare_features,
    extract_features,
)
from .oral_metrics import ORAL_EXERCISES, oral_features, oral_landmarks

logger = logging.getLogger(__name__)

MAX_ENCODED_BYTES = 600_000
MAX_IMAGE_BYTES = 450_000
MAX_IMAGE_PIXELS = 1_000_000
MAX_FRAME_SIDE = 640
MIN_FRAME_INTERVAL = 0.12
EYE_OBSERVATION_EXERCISES = frozenset({"face_3", "face_4", "face_6", "face_7"})
LEGACY_OBSERVATION_EXERCISES = {"face_1", "face_2", "lip_4"} | EYE_OBSERVATION_EXERCISES
CALIBRATED_ON_DEVICE = (
    ORAL_EXERCISES.keys() | DETAIL_EXERCISES.keys() | LIP_VARIANT_EXERCISES.keys()
)
Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS


def _enabled(value: str | None) -> bool:
    return (value or "").lower() in {"1", "true", "yes"}


@asynccontextmanager
async def lifespan(app: FastAPI):
    model_path = Path(os.environ.get("FACE_LANDMARKER_MODEL", "/models/face_landmarker.task"))
    if not model_path.is_file():
        raise RuntimeError(f"Face Landmarker model is missing: {model_path}")
    if not _enabled(os.environ.get("ALLOW_ANONYMOUS_EXERCISES")):
        if not os.environ.get("EXERCISE_AUTH_URL"):
            raise RuntimeError("Set EXERCISE_AUTH_URL, or enable local anonymous mode")

    options = mp.tasks.vision.FaceLandmarkerOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=str(model_path)),
        running_mode=mp.tasks.vision.RunningMode.IMAGE,
        num_faces=1,
        min_face_detection_confidence=0.5,
        min_face_presence_confidence=0.5,
        output_face_blendshapes=True,
    )
    app.state.landmarker = mp.tasks.vision.FaceLandmarker.create_from_options(options)
    # IMAGE mode is synchronous. Serialize access to one model instance while
    # decoding and inference run off the event loop.
    app.state.landmarker_lock = asyncio.Lock()
    async with httpx.AsyncClient(timeout=5.0) as client:
        app.state.http = client
        try:
            yield
        finally:
            app.state.landmarker.close()


app = FastAPI(title="Smile Quest Exercise Service", lifespan=lifespan)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


async def _valid_user(websocket: WebSocket, token: str) -> bool:
    if not token:
        return False
    auth_url = os.environ["EXERCISE_AUTH_URL"].rstrip("/") + "/auth/me"
    try:
        response = await websocket.app.state.http.get(
            auth_url,
            headers={
                "Authorization": f"Bearer {token}",
            },
        )
        return response.status_code == 200 and bool(response.json().get("id"))
    except (httpx.HTTPError, ValueError):
        logger.warning("Exercise authentication service unavailable")
        return False


def _detect_points(landmarker, encoded: str):
    if len(encoded) > MAX_ENCODED_BYTES:
        raise ValueError("Frame is too large")
    try:
        raw = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise ValueError("Invalid base64 image") from exc
    if len(raw) > MAX_IMAGE_BYTES:
        raise ValueError("Frame is too large")
    try:
        with Image.open(io.BytesIO(raw)) as image:
            if image.width * image.height > MAX_IMAGE_PIXELS:
                raise ValueError("Image dimensions are too large")
            image = ImageOps.exif_transpose(image).convert("RGB")
            image.thumbnail((MAX_FRAME_SIDE, MAX_FRAME_SIDE))
            rgb = np.asarray(image)
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError) as exc:
        raise ValueError("Invalid image") from exc

    result = landmarker.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb))
    if not result.face_landmarks:
        raise ValueError("No face detected")
    blendshapes = {item.category_name: item.score
                   for item in result.face_blendshapes[0]} if result.face_blendshapes else {}
    return result.face_landmarks[0], (image.width, image.height), blendshapes


async def _send_error(websocket: WebSocket, code: str, message: str) -> None:
    await websocket.send_json({"error": code, "message": message})


@app.websocket("/ws")
async def exercise_socket(websocket: WebSocket) -> None:
    await websocket.accept()
    authenticated = _enabled(os.environ.get("ALLOW_ANONYMOUS_EXERCISES"))
    baseline: tuple[str, dict[str, float]] | None = None
    last_frame_at = 0.0

    try:
        while True:
            try:
                text = await websocket.receive_text()
            except (WebSocketDisconnect, WebSocketDisconnected):
                break
            try:
                message = json.loads(text)
                if not isinstance(message, dict):
                    raise ValueError("Expected a JSON object")

                mode = message.get("mode")
                if mode == "auth":
                    if _enabled(os.environ.get("ALLOW_ANONYMOUS_EXERCISES")):
                        await websocket.send_json({"status": "authenticated"})
                        continue
                    authenticated = False
                    baseline = None
                    token = message.get("token")
                    if isinstance(token, str) and await _valid_user(websocket, token):
                        authenticated = True
                        await websocket.send_json({"status": "authenticated"})
                    else:
                        await _send_error(websocket, "unauthorized", "Sign in to perform exercises")
                    continue
                if not authenticated:
                    await _send_error(websocket, "unauthorized", "Sign in to perform exercises")
                    continue
                if not isinstance(mode, str) or mode not in {"init", "track", "observe"}:
                    raise ValueError("Unknown mode")

                exercise = message.get("exercise")
                if not isinstance(exercise, str) or (
                    exercise not in EXERCISES and exercise not in CALIBRATED_ON_DEVICE
                ):
                    await _send_error(websocket, "unknown_exercise", "Exercise is not available")
                    continue
                if mode != "observe" and exercise in CALIBRATED_ON_DEVICE:
                    await _send_error(websocket, "invalid_mode", "This exercise requires observation mode")
                    continue
                if (mode == "observe" and exercise not in LEGACY_OBSERVATION_EXERCISES
                        and exercise not in CALIBRATED_ON_DEVICE):
                    await _send_error(websocket, "unknown_exercise", "Observation is not available")
                    continue
                encoded = message.get("image")
                if not isinstance(encoded, str) or not encoded:
                    raise ValueError("Image is required")

                now = time.monotonic()
                if mode == "track" and now - last_frame_at < MIN_FRAME_INTERVAL:
                    continue
                last_frame_at = now
                async with websocket.app.state.landmarker_lock:
                    points, image_size, blendshapes = await asyncio.to_thread(
                        _detect_points, websocket.app.state.landmarker, encoded
                    )
                if exercise in CALIBRATED_ON_DEVICE:
                    if exercise in ORAL_EXERCISES:
                        features = oral_features(exercise, points, image_size, blendshapes)
                        indices = oral_landmarks(exercise)
                    elif exercise in LIP_VARIANT_EXERCISES:
                        features = lip_variant_features(exercise, points, image_size, blendshapes)
                        indices = lip_variant_landmarks(exercise)
                    else:
                        features = detail_features(exercise, points, image_size, blendshapes)
                        indices = detail_landmarks(exercise)
                    await websocket.send_json({
                        "status": "observation",
                        "features": features,
                        "landmarks": {
                            str(index): [points[index].x, points[index].y]
                            for index in sorted(indices)
                        },
                    })
                    continue
                current = extract_features(exercise, points, image_size, blendshapes)

                if mode == "observe":
                    await websocket.send_json({
                        "status": "observation",
                        "features": (
                            {"blue_gap": current["blue_squint"],
                             "orange_gap": current["orange_squint"],
                             "blue_aperture": current["blue_squint_aperture"],
                             "orange_aperture": current["orange_squint_aperture"]}
                            if exercise == "face_6" else
                            {"blue_gap": current["blue_frown"],
                             "orange_gap": current["orange_frown"]}
                            if exercise == "face_2" else
                            {"blue_gap": current["blue_smile"],
                             "orange_gap": current["orange_smile"]}
                            if exercise == "lip_4" else
                            {"blue_gap": current["left_eye_opening"],
                             "orange_gap": current["right_eye_opening"],
                             **({"blue_squeeze": current["blue_squeeze"],
                                 "orange_squeeze": current["orange_squeeze"]}
                                if exercise == "face_3" else {})}
                            if exercise in EYE_OBSERVATION_EXERCISES else current
                        ),
                        "landmarks": {
                            str(index): [points[index].x, points[index].y]
                            for index in sorted(
                                LIP_4_LANDMARKS if exercise == "lip_4"
                                else FACE_3_SQUEEZE_LANDMARKS if exercise == "face_3"
                                else FACE_3_LANDMARKS if exercise in EYE_OBSERVATION_EXERCISES
                                else FACE_1_LANDMARKS
                            )
                        },
                    })
                elif mode == "init":
                    baseline = (exercise, current)
                    await websocket.send_json({"status": "baseline_set", "baseline": current})
                elif baseline is None or baseline[0] != exercise:
                    await _send_error(websocket, "baseline_required", "Calibrate this exercise first")
                else:
                    delta = compare_features(exercise, baseline[1], current)
                    await websocket.send_json(
                        {"status": "tracking", "current": current, "delta": delta}
                    )
            except (WebSocketDisconnect, WebSocketDisconnected):
                break
            except (ValueError, CalibrationError) as exc:
                await _send_error(websocket, "invalid_frame", str(exc))
            except Exception:
                logger.exception("Exercise frame processing failed")
                await _send_error(websocket, "internal_error", "Frame processing failed")
    except (WebSocketDisconnect, WebSocketDisconnected):
        pass
