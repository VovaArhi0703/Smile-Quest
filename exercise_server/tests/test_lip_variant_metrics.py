import unittest
from math import cos, isfinite, radians, sin
from types import SimpleNamespace

from exercise_server.lip_variant_metrics import (
    LIP_VARIANT_EXERCISES,
    lip_variant_features,
    lip_variant_landmarks,
)


_FACE = {
    33: (-86, -73, 14), 133: (-40, -73, 6),
    263: (86, -73, 14), 362: (40, -73, 6),
    10: (0, -138, 6), 168: (0, -76, 0), 2: (0, 0, -10),
    152: (0, 91, 22), 199: (0, 72, 17),
    61: (-36, 32, 5), 291: (36, 32, 5),
    0: (0, 21, -4), 17: (0, 43, -4),
    13: (0, 31, -3), 14: (0, 32, -3),
    82: (-15, 31, -3), 87: (-15, 32, -3),
    312: (15, 31, -3), 317: (15, 32, -3),
}


def _observe(exercise, moves=(), blend=None, *, size=(480, 640), scale=1.0, roll=0):
    points = [(0.0, 0.0, 0.0)] * 478
    for index, coordinate in _FACE.items():
        points[index] = coordinate
    for indices, dx, dy in moves:
        for index in indices:
            x, y, z = points[index]
            points[index] = (x + dx, y + dy, z)

    width, height = size
    angle = radians(roll)
    landmarks = [
        SimpleNamespace(
            x=0.48 + scale * (x * cos(angle) - y * sin(angle)) / width,
            y=0.56 + scale * (x * sin(angle) + y * cos(angle)) / height,
            z=scale * z / width,
        )
        for x, y, z in points
    ]
    return lip_variant_features(exercise, landmarks, size, blend)


class LipVariantMetricsTests(unittest.TestCase):
    def test_lifting_upper_lip_keeps_lower_lip_signal_steady(self):
        neutral = _observe("lips_10")
        elevated = _observe("lips_10", [((13, 82, 312), 0, -8)])
        self.assertGreater(elevated["upper_lip_lift"], neutral["upper_lip_lift"] + 0.05)
        self.assertGreater(elevated["lip_opening"], neutral["lip_opening"] + 0.05)
        self.assertAlmostEqual(elevated["lower_lip_drop"], neutral["lower_lip_drop"])

    def test_jaw_opening_does_not_count_as_lower_lip_retraction(self):
        neutral = _observe("lips_10")
        lower_lip = _observe("lips_10", [((14, 87, 317), 0, 10)])
        opening_jaw = _observe("lips_10", [((14, 87, 317, 152, 199), 0, 10)])
        self.assertGreater(lower_lip["lower_lip_drop"], neutral["lower_lip_drop"] + 0.07)
        self.assertGreater(opening_jaw["lip_opening"], neutral["lip_opening"] + 0.07)
        self.assertAlmostEqual(opening_jaw["lower_lip_drop"], neutral["lower_lip_drop"])
        self.assertAlmostEqual(lower_lip["upper_lip_lift"], neutral["upper_lip_lift"])

    def test_smile_sides_measure_corner_motion_relative_to_lips(self):
        neutral = _observe("lips_11")
        right = _observe("lips_11", [((61,), -8, -8)], {"mouthSmileRight": 0.6})
        left = _observe("lips_11", [((291,), 8, -8)], {"mouthSmileLeft": 0.6})
        bilateral = _observe(
            "lips_11", [((61,), -8, -8), ((291,), 8, -8)],
            {"mouthSmileRight": 0.6, "mouthSmileLeft": 0.6},
        )
        drift = _observe("lips_11", [((61, 291, 13), 8, -4)])
        self.assertGreater(right["smile_right"], neutral["smile_right"] + 0.1)
        self.assertAlmostEqual(right["smile_left"], neutral["smile_left"])
        self.assertGreater(left["smile_left"], neutral["smile_left"] + 0.1)
        self.assertAlmostEqual(left["smile_right"], neutral["smile_right"])
        self.assertGreater(right["smile_balance"], 0.1)
        self.assertLess(left["smile_balance"], -0.1)
        self.assertAlmostEqual(bilateral["smile_balance"], neutral["smile_balance"])
        for key in ("smile_right", "smile_left"):
            self.assertAlmostEqual(drift[key], neutral[key])

    def test_shape_metrics_capture_rounding_without_confusing_it_with_opening(self):
        rounded = _observe(
            "lips_12",
            [((61,), 8, 0), ((291,), -8, 0), ((14, 87, 317), 0, 6)],
            {"mouthFunnel": 0.72},
        )
        opened = _observe("lips_12", [((14, 87, 317), 0, 15)])
        self.assertGreater(rounded["lip_rounding"], opened["lip_rounding"])
        self.assertGreater(rounded["lip_pucker"], opened["lip_pucker"])
        self.assertLess(rounded["lip_opening"], opened["lip_opening"])
        self.assertLess(rounded["lip_width"], opened["lip_width"])

    def test_feature_contract_and_geometry_are_invariant_to_roll_and_resize(self):
        for exercise, keys in LIP_VARIANT_EXERCISES.items():
            with self.subTest(exercise=exercise):
                base = _observe(exercise)
                changed = _observe(exercise, size=(700, 490), scale=0.78, roll=12)
                self.assertEqual(set(base), set(keys))
                self.assertTrue(all(isfinite(value) for value in base.values()))
                self.assertTrue({13, 14, 61, 291} <= lip_variant_landmarks(exercise))
                for key, value in base.items():
                    self.assertAlmostEqual(value, changed[key])
