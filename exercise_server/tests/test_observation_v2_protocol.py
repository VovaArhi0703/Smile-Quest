"""Exercise 2.0 client/server contract using a real local Face Landmarker."""

import base64
import io
import math
import os
import time
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

import matplotlib
from fastapi.testclient import TestClient
from PIL import Image

from exercise_server.main import MIN_FRAME_INTERVAL, app


MODEL = Path(__file__).resolve().parents[1] / "models" / "face_landmarker.task"
SAMPLE_FACE = Path(matplotlib.get_data_path()) / "sample_data" / "grace_hopper.jpg"

# The required feature names in the current Flutter program definitions,
# including the opening signal used by open/closed-lip guards.
BOTH_CHEEKS = {"cheek_volume", "cheek_right", "cheek_left", "lip_opening", "lip_center_opening"}
SIDE_CHEEKS = {"cheek_balance", "cheek_right", "cheek_left", "lip_opening", "lip_center_opening"}
JAW_OPENING = {"jaw_open", "chin_drop", "lip_opening", "lip_center_opening"}
CLIENT_FEATURES = {
    "face_8": {"nose_wrinkle_left", "nose_wrinkle_right"},
    "cheeks_1": BOTH_CHEEKS,
    "cheeks_2": BOTH_CHEEKS,
    "cheeks_3": SIDE_CHEEKS,
    "cheeks_4": BOTH_CHEEKS,
    "cheeks_5": SIDE_CHEEKS,
    "jaw_1": JAW_OPENING,
    "jaw_2": {"jaw_side", "chin_side"},
    "jaw_3": JAW_OPENING,
    "lips_1": {"lip_pucker", "lip_rounding"},
    "lips_2": {"lip_pucker", "lip_x", "lip_y", "lip_rounding"},
    "lips_3": {"lip_pucker", "lip_smile", "lip_rounding"},
    "lips_6": {"upper_lip_roll", "lower_lip_roll"},
    "lips_7": {"upper_lip_raise", "lower_lip_drop", "lip_opening", "lip_width"},
    "lips_8": {"lip_pucker", "lip_opening", "lip_center_opening", "lip_rounding"},
    "lips_9": {"lip_opening", "lip_center_opening"},
    "lips_10": {"upper_lip_lift", "lower_lip_drop", "lip_opening"},
    "lips_11": {"smile_right", "smile_left", "smile_balance"},
    "lips_12": {"lip_pucker", "lip_smile", "lip_opening", "lip_width", "lip_rounding"},
}


@unittest.skipUnless(MODEL.is_file(), "Face Landmarker model is not downloaded")
@unittest.skipUnless(SAMPLE_FACE.is_file(), "Matplotlib sample face is unavailable")
class ObservationV2ProtocolTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.face = base64.b64encode(SAMPLE_FACE.read_bytes()).decode("ascii")
        output = io.BytesIO()
        Image.new("RGB", (128, 128), "white").save(output, format="JPEG")
        cls.no_face = base64.b64encode(output.getvalue()).decode("ascii")

    def test_real_observations_and_legacy_baseline_coexist(self):
        env = {
            "FACE_LANDMARKER_MODEL": str(MODEL),
            "ALLOW_ANONYMOUS_EXERCISES": "true",
        }
        with (
            patch.dict(os.environ, env),
            TestClient(app) as client,
            client.websocket_connect("/ws") as socket,
        ):
            socket.send_json({"mode": "init", "exercise": "face_4", "image": self.face})
            self.assertEqual(socket.receive_json()["status"], "baseline_set")

            for exercise, required in CLIENT_FEATURES.items():
                with self.subTest(exercise=exercise):
                    socket.send_json({
                        "mode": "observe", "exercise": exercise, "image": self.face,
                    })
                    self._assert_observation(socket.receive_json(), required)

            socket.send_json({"mode": "observe", "exercise": "lip_4", "image": self.face})
            legacy = socket.receive_json()
            self._assert_observation(legacy, {"blue_gap", "orange_gap"})
            self.assertEqual(set(legacy["features"]), {"blue_gap", "orange_gap"})

            # Legacy requests are rate limited relative to the last frame.
            time.sleep(MIN_FRAME_INTERVAL + 0.02)
            socket.send_json({"mode": "track", "exercise": "face_4", "image": self.face})
            tracking = socket.receive_json()
            self.assertEqual(tracking["status"], "tracking")
            self.assertAlmostEqual(tracking["delta"]["blink_score"], 0.0)

    def test_invalid_requests_are_rejected_without_closing_connection(self):
        env = {
            "FACE_LANDMARKER_MODEL": str(MODEL),
            "ALLOW_ANONYMOUS_EXERCISES": "true",
        }
        cases = (
            ({"mode": "init", "exercise": "cheeks_1"}, "invalid_mode"),
            ({"mode": "track", "exercise": "jaw_1"}, "invalid_mode"),
            ({"mode": [], "exercise": "cheeks_1"}, "invalid_frame"),
            ({"mode": "observe", "exercise": "cheeks_1"}, "invalid_frame"),
            ({"mode": "observe", "exercise": "cheeks_1", "image": "**"}, "invalid_frame"),
            ({"mode": "observe", "exercise": "cheeks_1", "image": self.no_face},
             "invalid_frame"),
            ({"mode": "observe", "exercise": "tongue_1", "image": self.face},
             "unknown_exercise"),
        )
        with (
            patch.dict(os.environ, env),
            TestClient(app) as client,
            client.websocket_connect("/ws") as socket,
        ):
            socket.send_text("{")
            self.assertEqual(socket.receive_json()["error"], "invalid_frame")
            for index, (request, error) in enumerate(cases):
                with self.subTest(case=index):
                    socket.send_json(request)
                    self.assertEqual(socket.receive_json()["error"], error)
            socket.send_json({"mode": "observe", "exercise": "face_8", "image": self.face})
            self._assert_observation(socket.receive_json(), CLIENT_FEATURES["face_8"])

    def test_observation_on_public_socket_requires_valid_session(self):
        env = {
            "FACE_LANDMARKER_MODEL": str(MODEL),
            "ALLOW_ANONYMOUS_EXERCISES": "false",
            "EXERCISE_AUTH_URL": "https://example.invalid",
        }
        request = {"mode": "observe", "exercise": "jaw_1", "image": self.face}
        verify = AsyncMock(side_effect=[True, False])
        with (
            patch.dict(os.environ, env),
            patch("exercise_server.main._valid_user", verify),
            TestClient(app) as client,
            client.websocket_connect("/ws") as socket,
        ):
            socket.send_json(request)
            self.assertEqual(socket.receive_json()["error"], "unauthorized")
            socket.send_json({"mode": "auth", "token": "valid-test-session"})
            self.assertEqual(socket.receive_json()["status"], "authenticated")
            socket.send_json(request)
            self._assert_observation(socket.receive_json(), CLIENT_FEATURES["jaw_1"])
            socket.send_json({"mode": "auth", "token": "expired-test-session"})
            self.assertEqual(socket.receive_json()["error"], "unauthorized")
            socket.send_json(request)
            self.assertEqual(socket.receive_json()["error"], "unauthorized")

    def _assert_observation(self, response, required):
        self.assertEqual(response.get("status"), "observation", response)
        features = response["features"]
        self.assertLessEqual(required, features.keys())
        for value in features.values():
            self.assertIsInstance(value, (int, float))
            self.assertTrue(math.isfinite(value))
        self.assertTrue(response["landmarks"])
        for index, coordinates in response["landmarks"].items():
            self.assertTrue(index.isdecimal())
            self.assertEqual(len(coordinates), 2)
            for coordinate in coordinates:
                self.assertIsInstance(coordinate, (int, float))
                self.assertGreaterEqual(coordinate, 0)
                self.assertLessEqual(coordinate, 1)
