import unittest
from math import cos, sin
from types import SimpleNamespace

from exercise_server.detail_metrics import detail_features, detail_landmarks


def nose_points(angle: float = 0, scale: float = 1):
    points = [SimpleNamespace(x=0.5, y=0.5) for _ in range(478)]
    pixels = {
        33: (-95, -30), 133: (-35, -30), 362: (35, -30), 263: (95, -30),
        1: (0, 25), 6: (0, -20),
        49: (-28, 19), 64: (-25, 25), 98: (-18, 32),
        278: (28, 19), 294: (25, 25), 327: (18, 32),
    }
    for index, (x, y) in pixels.items():
        points[index] = SimpleNamespace(
            x=0.5 + scale * (x * cos(angle) - y * sin(angle)) / 640,
            y=0.5 + scale * (x * sin(angle) + y * cos(angle)) / 480,
        )
    return points


class NoseWrinkleTests(unittest.TestCase):
    def test_uses_each_nostril_signal_independently_of_smile_or_squint(self):
        points = nose_points()
        neutral = {"noseSneerLeft": 0.03, "noseSneerRight": 0.02}
        unrelated = {**neutral, "mouthSmileLeft": 0.94,
                     "mouthUpperUpLeft": 0.84, "eyeSquintLeft": 0.90}
        active = {**unrelated, "noseSneerLeft": 0.67}

        baseline = detail_features("face_8", points, (640, 480), neutral)
        self.assertEqual(detail_features("face_8", points, (640, 480), unrelated), baseline)
        wrinkle = detail_features("face_8", points, (640, 480), active)
        self.assertEqual(wrinkle, {"nose_wrinkle_left": 0.67, "nose_wrinkle_right": 0.02})
        self.assertEqual(detail_landmarks("face_8"), {1, 6, 49, 64, 98, 278, 294, 327})

    def test_handles_face_roll_and_refuses_profile_or_small_face(self):
        active = {"noseSneerLeft": 0.67, "noseSneerRight": 0.60}
        normal = detail_features("face_8", nose_points(), (640, 480), active)
        self.assertEqual(
            detail_features("face_8", nose_points(angle=0.55, scale=0.5), (640, 480), active),
            normal,
        )
        profile = nose_points()
        profile[1].x += 0.075
        with self.assertRaisesRegex(ValueError, "Face the camera"):
            detail_features("face_8", profile, (640, 480), active)
        tilted_back = nose_points()
        tilted_back[1].y = tilted_back[33].y + 5 / 480
        with self.assertRaisesRegex(ValueError, "Face the camera"):
            detail_features("face_8", tilted_back, (640, 480), active)
        with self.assertRaisesRegex(ValueError, "Move closer"):
            detail_features("face_8", nose_points(scale=0.15), (640, 480), active)

    def test_never_treats_missing_or_invalid_model_output_as_neutral(self):
        points = nose_points()
        for blendshapes in (None, {}, {"noseSneerLeft": float("nan"), "noseSneerRight": 0.4}):
            with self.subTest(blendshapes=blendshapes):
                with self.assertRaisesRegex(ValueError, "Nose movement is unavailable"):
                    detail_features("face_8", points, (640, 480), blendshapes)
