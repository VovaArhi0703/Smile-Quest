import unittest
from math import cos, isfinite, radians, sin
from types import SimpleNamespace

from exercise_server.oral_metrics import ORAL_EXERCISES, oral_features, oral_landmarks


def _face():
    points = [(0.0, 0.0, 0.0)] * 478
    landmarks = {
        33: (-86, -73, 13), 133: (-40, -73, 5),
        263: (86, -73, 13), 362: (40, -73, 5),
        10: (0, -138, 6), 168: (0, -76, 0), 2: (0, 0, -10),
        187: (-81, 7, 33), 205: (-68, 4, 14), 206: (-64, 22, 15),
        411: (81, 7, 33), 425: (68, 4, 14), 426: (64, 22, 15),
        152: (0, 91, 22), 199: (0, 72, 17),
        61: (-36, 32, 5), 291: (36, 32, 5),
        0: (0, 21, -4), 17: (0, 43, -4),
        13: (0, 31, -3), 14: (0, 32, -3),
        82: (-15, 31, -3), 87: (-15, 32, -3),
        312: (15, 31, -3), 317: (15, 32, -3),
    }
    for index, position in landmarks.items():
        points[index] = position
    return points


def _shift(points, indices, dx=0, dy=0, dz=0):
    for index in indices:
        x, y, z = points[index]
        points[index] = (x + dx, y + dy, z + dz)


def _measure(exercise, points, blend=None, *, size=(480, 640), scale=1, yaw=0, pitch=0, roll=0):
    width, height = size
    a, b, c = map(radians, (yaw, pitch, roll))
    landmarks = []
    for x, y, z in points:
        x, z = x * cos(a) + z * sin(a), -x * sin(a) + z * cos(a)
        y, z = y * cos(b) - z * sin(b), y * sin(b) + z * cos(b)
        x, y = x * cos(c) - y * sin(c), x * sin(c) + y * cos(c)
        landmarks.append(SimpleNamespace(
            x=0.48 + x * scale / width,
            y=0.56 + y * scale / height,
            z=z * scale / width,
        ))
    return oral_features(exercise, landmarks, size, blend)


class CheekMetricTests(unittest.TestCase):
    def test_volume_distinguishes_puff_and_suck_against_neutral(self):
        neutral = _measure("cheeks_4", _face())
        puffed, sucked = _face(), _face()
        _shift(puffed, (187, 205, 206), dx=-6, dz=-13)
        _shift(puffed, (411, 425, 426), dx=6, dz=-13)
        _shift(sucked, (187, 205, 206), dx=7, dz=9)
        _shift(sucked, (411, 425, 426), dx=-7, dz=9)
        puff = _measure("cheeks_4", puffed, {"cheekPuff": 0.7})
        suck = _measure("cheeks_4", sucked)
        self.assertGreater(puff["cheek_volume"], neutral["cheek_volume"] + 0.15)
        self.assertLess(suck["cheek_volume"], neutral["cheek_volume"] - 0.08)
        self.assertAlmostEqual(puff["cheek_balance"], neutral["cheek_balance"])

    def test_right_left_balance_tracks_only_the_active_cheek(self):
        right, left = _face(), _face()
        _shift(right, (187, 205, 206), dx=-8, dz=-7)
        _shift(left, (411, 425, 426), dx=8, dz=-7)
        base = _measure("cheeks_3", _face())
        right_result = _measure("cheeks_3", right, yaw=25, roll=9)
        left_result = _measure("cheeks_5", left, yaw=-25)
        self.assertGreater(right_result["cheek_balance"], base["cheek_balance"] + 0.08)
        self.assertLess(left_result["cheek_balance"], base["cheek_balance"] - 0.08)
        self.assertAlmostEqual(right_result["cheek_left"], base["cheek_left"])
        self.assertAlmostEqual(left_result["cheek_right"], base["cheek_right"])


class JawMetricTests(unittest.TestCase):
    def test_jaw_motion_is_independent_of_whether_lips_are_open(self):
        neutral, closed_chew, open_chew = _face(), _face(), _face()
        _shift(closed_chew, (152, 199), dy=11)
        _shift(open_chew, (152, 199), dy=11)
        _shift(open_chew, (14, 87, 317), dy=14)
        rest = _measure("jaw_1", neutral)
        closed = _measure("jaw_3", closed_chew)
        opened = _measure("jaw_3", open_chew)
        self.assertGreater(closed["jaw_open"], rest["jaw_open"] + 0.08)
        self.assertAlmostEqual(closed["jaw_open"], opened["jaw_open"])
        self.assertAlmostEqual(closed["lip_opening"], rest["lip_opening"])
        self.assertGreater(opened["lip_opening"], closed["lip_opening"] + 0.10)

    def test_center_gap_reports_open_lips_even_with_closed_corners(self):
        slightly_open = _face()
        _shift(slightly_open, (14,), dy=8)
        for exercise in ("jaw_3", "cheeks_1", "lips_1"):
            with self.subTest(exercise=exercise):
                rest = _measure(exercise, _face())
                result = _measure(exercise, slightly_open, yaw=15, roll=12)
                self.assertAlmostEqual(result["lip_opening"], rest["lip_opening"])
                self.assertGreater(result["lip_center_opening"], rest["lip_center_opening"] + .06)

    def test_side_motion_uses_chin_and_ignores_a_lip_only_reposition(self):
        moved, lip_only = _face(), _face()
        _shift(moved, (152, 199), dx=-10)
        _shift(lip_only, (0, 13, 14, 17, 61, 291), dx=-10)
        neutral = _measure("jaw_2", _face())
        self.assertGreater(_measure("jaw_2", moved)["jaw_side"], neutral["jaw_side"] + 0.07)
        self.assertAlmostEqual(_measure("jaw_2", lip_only)["jaw_side"], neutral["jaw_side"])

    def test_chin_signals_corroborate_native_jaw_predictions(self):
        frame = _face()
        rest = _measure("jaw_3", frame)
        native_only = _measure("jaw_3", frame, {"jawOpen": 0.7, "jawRight": 0.6})
        self.assertGreater(native_only["jaw_open"], rest["jaw_open"] + 0.15)
        self.assertGreater(native_only["jaw_side"], rest["jaw_side"] + 0.08)
        self.assertEqual(native_only["chin_drop"], rest["chin_drop"])
        self.assertEqual(native_only["chin_side"], rest["chin_side"])

        _shift(frame, (152, 199), dx=-4, dy=4)
        motion = _measure("jaw_3", frame, yaw=18, roll=11)
        self.assertGreater(motion["chin_drop"], rest["chin_drop"] + 0.025)
        self.assertGreater(motion["chin_side"], rest["chin_side"] + 0.025)


class LipMetricTests(unittest.TestCase):
    def test_width_and_expression_separate_tube_from_smile(self):
        pucker, smile = _face(), _face()
        _shift(pucker, (61,), dx=9)
        _shift(pucker, (291,), dx=-9)
        _shift(smile, (61,), dx=-9, dy=-6)
        _shift(smile, (291,), dx=9, dy=-6)
        base = _measure("lips_1", _face())
        tube = _measure("lips_3", pucker, {"mouthPucker": 0.6})
        grin = _measure("lips_3", smile, {"mouthSmileLeft": 0.7, "mouthSmileRight": 0.6})
        self.assertGreater(tube["lip_pucker"], base["lip_pucker"] + 0.20)
        self.assertGreater(grin["lip_smile"], base["lip_smile"] + 0.25)
        self.assertLess(grin["lip_pucker"], base["lip_pucker"])

    def test_narrowing_corners_alone_does_not_increase_rounding(self):
        pinched = _face()
        _shift(pinched, (61,), dx=9)
        _shift(pinched, (291,), dx=-9)
        rest = _measure("lips_1", _face())
        narrower = _measure("lips_1", pinched)
        rounded = _measure("lips_1", pinched, {"mouthPucker": 0.6, "mouthFunnel": 0.4})
        self.assertLess(narrower["lip_width"], rest["lip_width"] - 0.10)
        self.assertEqual(narrower["lip_rounding"], rest["lip_rounding"])
        self.assertEqual(rounded["lip_rounding"], 0.6)

    def test_pucker_translation_preserves_shape_and_direction(self):
        shifted = _face()
        _shift(shifted, (0, 17, 61, 291), dx=-8, dy=-5)
        base = _measure("lips_2", _face(), {"mouthPucker": 0.6})
        result = _measure("lips_2", shifted, {"mouthPucker": 0.6}, roll=12)
        self.assertAlmostEqual(result["lip_pucker"], base["lip_pucker"])
        self.assertGreater(result["lip_x"], base["lip_x"] + 0.06)
        self.assertGreater(result["lip_y"], base["lip_y"] + 0.03)

    def test_independent_lip_roll_and_lip_retraction(self):
        rolled = _measure("lips_6", _face(), {"mouthRollUpper": 0.65, "mouthRollLower": 0.09})
        retracted = _face()
        _shift(retracted, (0, 13, 82, 312), dy=-6)
        _shift(retracted, (17, 14, 87, 317), dy=7)
        base = _measure("lips_7", _face())
        result = _measure("lips_7", retracted)
        self.assertGreater(rolled["upper_lip_roll"], rolled["lower_lip_roll"] + 0.5)
        self.assertGreater(result["upper_lip_raise"], base["upper_lip_raise"] + 0.04)
        self.assertGreater(result["lower_lip_drop"], base["lower_lip_drop"] + 0.05)
        self.assertGreater(result["lip_opening"], base["lip_opening"] + 0.10)


class OralObservationTests(unittest.TestCase):
    def test_every_selector_returns_finite_features_and_overlay_points(self):
        neutral_roll = {"mouthRollUpper": 0.0, "mouthRollLower": 0.0}
        for exercise, keys in ORAL_EXERCISES.items():
            with self.subTest(exercise=exercise):
                features = _measure(exercise, _face(), neutral_roll)
                self.assertEqual(set(features), set(keys))
                self.assertTrue(all(isfinite(value) for value in features.values()))
                self.assertTrue(oral_landmarks(exercise))

    def test_identical_pose_survives_zoom_frame_resize_and_moderate_head_rotation(self):
        for exercise in ("cheeks_3", "jaw_2", "lips_2"):
            with self.subTest(exercise=exercise):
                normal = _measure(exercise, _face())
                rotated = _measure(
                    exercise, _face(), size=(620, 480), scale=0.74, yaw=25, pitch=8, roll=13,
                )
                for key, value in normal.items():
                    self.assertAlmostEqual(value, rotated[key])

    def test_extreme_pose_and_small_faces_reject_instead_of_creating_an_observation(self):
        with self.assertRaisesRegex(ValueError, "Look toward"):
            _measure("cheeks_1", _face(), yaw=60)
        with self.assertRaisesRegex(ValueError, "too far"):
            _measure("lips_1", _face(), scale=0.2)

    def test_missing_lip_roll_is_not_a_neutral_observation(self):
        for blend in (None, {"mouthRollUpper": 0.5}, {"mouthRollLower": 0.5}):
            with self.subTest(blend=blend):
                with self.assertRaisesRegex(ValueError, "score is unavailable"):
                    _measure("lips_6", _face(), blend)

    def test_bad_model_score_rejects_frame(self):
        for exercise, blend in (
            ("cheeks_1", {"cheekPuff": float("nan")}),
            ("jaw_3", {"jawOpen": float("inf")}),
            ("lips_7", {"mouthLowerDownRight": 1.5}),
        ):
            with self.subTest(exercise=exercise):
                with self.assertRaisesRegex(ValueError, "score is unavailable"):
                    _measure(exercise, _face(), blend)
