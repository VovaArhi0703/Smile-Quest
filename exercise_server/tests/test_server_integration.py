"""Small protocol smoke test with the real local Face Landmarker model."""

import base64
import io
import os
import time
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

import matplotlib
from PIL import Image
from fastapi.testclient import TestClient

from exercise_server.main import app


MODEL = Path(__file__).resolve().parents[1] / "models" / "face_landmarker.task"
SAMPLE_FACE = Path(matplotlib.get_data_path()) / "sample_data" / "grace_hopper.jpg"


@unittest.skipUnless(MODEL.is_file(), "Face Landmarker model is not downloaded")
class ServerIntegrationTests(unittest.TestCase):
    def test_startup_and_websocket_errors(self):
        previous_model = os.environ.get("FACE_LANDMARKER_MODEL")
        previous_anonymous = os.environ.get("ALLOW_ANONYMOUS_EXERCISES")
        os.environ["FACE_LANDMARKER_MODEL"] = str(MODEL)
        os.environ["ALLOW_ANONYMOUS_EXERCISES"] = "true"
        try:
            with TestClient(app) as client:
                self.assertEqual(client.get("/health").json(), {"status": "ok"})
                with client.websocket_connect("/ws") as websocket:
                    websocket.send_json({"mode": "init", "exercise": "unknown", "image": "x"})
                    self.assertEqual(websocket.receive_json()["error"], "unknown_exercise")

                    image = Image.new("RGB", (128, 128), "white")
                    output = io.BytesIO()
                    image.save(output, format="JPEG")
                    encoded = base64.b64encode(output.getvalue()).decode("ascii")
                    websocket.send_json(
                        {"mode": "init", "exercise": "face_1", "image": encoded}
                    )
                    self.assertEqual(websocket.receive_json()["error"], "invalid_frame")
        finally:
            if previous_model is None:
                os.environ.pop("FACE_LANDMARKER_MODEL", None)
            else:
                os.environ["FACE_LANDMARKER_MODEL"] = previous_model
            if previous_anonymous is None:
                os.environ.pop("ALLOW_ANONYMOUS_EXERCISES", None)
            else:
                os.environ["ALLOW_ANONYMOUS_EXERCISES"] = previous_anonymous

    @unittest.skipUnless(SAMPLE_FACE.is_file(), "Matplotlib sample face is unavailable")
    def test_real_face_baseline_and_tracking(self):
        previous_model = os.environ.get("FACE_LANDMARKER_MODEL")
        previous_anonymous = os.environ.get("ALLOW_ANONYMOUS_EXERCISES")
        os.environ["FACE_LANDMARKER_MODEL"] = str(MODEL)
        os.environ["ALLOW_ANONYMOUS_EXERCISES"] = "true"
        try:
            encoded = base64.b64encode(SAMPLE_FACE.read_bytes()).decode("ascii")
            with TestClient(app) as client:
                with client.websocket_connect("/ws") as websocket:
                    websocket.send_json(
                        {"mode": "init", "exercise": "face_4", "image": encoded}
                    )
                    self.assertEqual(websocket.receive_json()["status"], "baseline_set")
                    time.sleep(0.13)
                    websocket.send_json(
                        {"mode": "track", "exercise": "face_4", "image": encoded}
                    )
                    response = websocket.receive_json()
                    self.assertEqual(response["status"], "tracking")
                    self.assertAlmostEqual(response["delta"]["blink_score"], 0.0)
                    websocket.send_json(
                        {"mode": "observe", "exercise": "face_1", "image": encoded}
                    )
                    observation = websocket.receive_json()
                    self.assertEqual(observation["status"], "observation")
                    self.assertGreater(observation["features"]["blue_gap"], 0)
                    self.assertGreater(observation["features"]["orange_gap"], 0)
                    self.assertIn("65", observation["landmarks"])
                    self.assertIn("295", observation["landmarks"])
                    self.assertNotIn("159", observation["landmarks"])
                    websocket.send_json(
                        {"mode": "observe", "exercise": "face_2", "image": encoded}
                    )
                    frown = websocket.receive_json()
                    self.assertEqual(frown["status"], "observation")
                    self.assertEqual(set(frown["features"]), {"blue_gap", "orange_gap"})
                    self.assertEqual(frown["landmarks"], observation["landmarks"])
                    websocket.send_json(
                        {"mode": "observe", "exercise": "face_3", "image": encoded}
                    )
                    eyes = websocket.receive_json()
                    self.assertEqual(eyes["status"], "observation")
                    self.assertGreater(eyes["features"]["blue_gap"], 0)
                    self.assertGreater(eyes["features"]["orange_gap"], 0)
                    self.assertIn("blue_squeeze", eyes["features"])
                    self.assertIn("orange_squeeze", eyes["features"])
                    self.assertEqual(
                        set(eyes["landmarks"]),
                        {"159", "145", "33", "133", "386", "374", "263", "362",
                         "111", "117", "340", "346"},
                    )
                    websocket.send_json(
                        {"mode": "observe", "exercise": "face_4", "image": encoded}
                    )
                    blink = websocket.receive_json()
                    self.assertEqual(blink["status"], "observation")
                    self.assertEqual(blink["features"]["blue_gap"], eyes["features"]["blue_gap"])
                    self.assertEqual(blink["features"]["orange_gap"], eyes["features"]["orange_gap"])
                    self.assertEqual(set(blink["landmarks"]), set(eyes["landmarks"]) -
                                     {"111", "117", "340", "346"})
                    websocket.send_json(
                        {"mode": "observe", "exercise": "face_6", "image": encoded}
                    )
                    squint = websocket.receive_json()
                    self.assertEqual(squint["status"], "observation")
                    self.assertEqual(squint["landmarks"], blink["landmarks"])
                    self.assertEqual(
                        set(squint["features"]),
                        {"blue_gap", "orange_gap", "blue_aperture", "orange_aperture"},
                    )
                    self.assertTrue(all(
                        isinstance(value, (int, float))
                        for value in squint["features"].values()
                    ))
                    websocket.send_json(
                        {"mode": "observe", "exercise": "face_7", "image": encoded}
                    )
                    wink = websocket.receive_json()
                    self.assertEqual(wink["status"], "observation")
                    self.assertEqual(wink["features"], blink["features"])
                    self.assertEqual(wink["landmarks"], blink["landmarks"])
                    websocket.send_json(
                        {"mode": "observe", "exercise": "lip_4", "image": encoded}
                    )
                    smile = websocket.receive_json()
                    self.assertEqual(smile["status"], "observation")
                    self.assertEqual(set(smile["features"]), {"blue_gap", "orange_gap"})
                    self.assertEqual(
                        set(smile["landmarks"]),
                        {"13", "61", "291", "33", "133", "263", "362"},
                    )
        finally:
            if previous_model is None:
                os.environ.pop("FACE_LANDMARKER_MODEL", None)
            else:
                os.environ["FACE_LANDMARKER_MODEL"] = previous_model
            if previous_anonymous is None:
                os.environ.pop("ALLOW_ANONYMOUS_EXERCISES", None)
            else:
                os.environ["ALLOW_ANONYMOUS_EXERCISES"] = previous_anonymous

    def test_public_mode_requires_session(self):
        keys = (
            "FACE_LANDMARKER_MODEL",
            "ALLOW_ANONYMOUS_EXERCISES",
            "EXERCISE_AUTH_URL",
        )
        previous = {key: os.environ.get(key) for key in keys}
        os.environ.update(
            FACE_LANDMARKER_MODEL=str(MODEL),
            ALLOW_ANONYMOUS_EXERCISES="false",
            EXERCISE_AUTH_URL="https://example.invalid",
        )
        try:
            with TestClient(app) as client:
                with client.websocket_connect("/ws") as websocket:
                    websocket.send_json(
                        {"mode": "init", "exercise": "face_4", "image": "unused"}
                    )
                    self.assertEqual(websocket.receive_json()["error"], "unauthorized")
                    with patch(
                        "exercise_server.main._valid_user",
                        new=AsyncMock(return_value=True),
                    ) as verify_user:
                        websocket.send_json({"mode": "auth", "token": "test-token"})
                        self.assertEqual(
                            websocket.receive_json()["status"], "authenticated"
                        )
                        websocket.send_json(
                            {"mode": "init", "exercise": "face_4", "image": "unused"}
                        )
                        self.assertEqual(websocket.receive_json()["error"], "invalid_frame")
                        verify_user.return_value = False
                        websocket.send_json({"mode": "auth", "token": "expired"})
                        self.assertEqual(websocket.receive_json()["error"], "unauthorized")
                        websocket.send_json(
                            {"mode": "init", "exercise": "face_4", "image": "unused"}
                        )
                        self.assertEqual(websocket.receive_json()["error"], "unauthorized")
        finally:
            for key, value in previous.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value
