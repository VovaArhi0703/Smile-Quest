import unittest
from math import cos, radians, sin
from types import SimpleNamespace

from exercise_server.metrics import (
    CalibrationError,
    EXERCISES,
    compare_features,
    extract_features,
)


def face_points():
    points = [SimpleNamespace(x=0.5, y=0.5) for _ in range(478)]
    values = {
        234: (0.2, 0.5), 454: (0.8, 0.5),
        53: (0.33, 0.35), 52: (0.35, 0.35), 65: (0.37, 0.35),
        160: (0.33, 0.45), 159: (0.35, 0.45), 158: (0.37, 0.45),
        145: (0.35, 0.47),
        283: (0.63, 0.35), 282: (0.65, 0.35), 295: (0.67, 0.35),
        387: (0.63, 0.45), 386: (0.65, 0.45), 385: (0.67, 0.45),
        374: (0.65, 0.47),
        111: (0.32, 0.51), 117: (0.36, 0.52),
        340: (0.68, 0.51), 346: (0.64, 0.52),
        33: (0.30, 0.46), 133: (0.40, 0.46),
        263: (0.60, 0.46), 362: (0.70, 0.46),
        61: (0.35, 0.60), 291: (0.65, 0.60),
        13: (0.5, 0.60), 14: (0.5, 0.62),
    }
    for index, (x, y) in values.items():
        points[index] = SimpleNamespace(x=x, y=y)
    return points


class MetricTests(unittest.TestCase):
    def test_brow_scores_ignore_eyelid_gaze_and_detect_target_motion(self):
        neutral = face_points()
        looking_down = face_points()
        for index in (160, 159, 158, 145, 387, 386, 385, 374):
            point = looking_down[index]
            looking_down[index] = SimpleNamespace(x=point.x, y=point.y + 0.025)
        raised = face_points()
        for index in (53, 52, 65, 283, 282, 295):
            point = raised[index]
            raised[index] = SimpleNamespace(x=point.x, y=point.y - 0.025)
        frowned = face_points()
        frowned[65] = SimpleNamespace(x=0.39, y=0.36)
        frowned[295] = SimpleNamespace(x=0.65, y=0.36)
        base_raise = extract_features("face_1", neutral, (640, 480))
        down_raise = extract_features("face_1", looking_down, (640, 480))
        high_raise = extract_features("face_1", raised, (640, 480))
        base_frown = extract_features("face_2", neutral, (640, 480))
        down_frown = extract_features("face_2", looking_down, (640, 480))
        peak_frown = extract_features("face_2", frowned, (640, 480))
        for side in ("blue_gap", "orange_gap"):
            self.assertAlmostEqual(base_raise[side], down_raise[side])
            self.assertGreater(high_raise[side], base_raise[side])
        for side in ("blue_frown", "orange_frown"):
            self.assertAlmostEqual(base_frown[side], down_frown[side])
            self.assertGreater(peak_frown[side], base_frown[side])

    def test_strong_eye_squeeze_uses_cheeks_and_blendshapes_beyond_lid_aperture(self):
        neutral = face_points()
        closed = face_points()
        squeezed = face_points()
        for target in (closed, squeezed):
            target[145] = SimpleNamespace(x=0.35, y=0.45)
            target[374] = SimpleNamespace(x=0.65, y=0.45)
        for index in (111, 117, 340, 346):
            point = squeezed[index]
            squeezed[index] = SimpleNamespace(x=point.x, y=point.y - 0.025)
        ordinary = {"eyeSquintLeft": 0.1, "eyeSquintRight": 0.1,
                    "cheekSquintLeft": 0.01, "cheekSquintRight": 0.01}
        strong = {"eyeSquintLeft": 0.7, "eyeSquintRight": 0.7,
                  "cheekSquintLeft": 0.5, "cheekSquintRight": 0.5}
        blink = extract_features("face_3", closed, (640, 480), ordinary)
        peak = extract_features("face_3", squeezed, (640, 480), strong)
        self.assertAlmostEqual(blink["left_eye_opening"], peak["left_eye_opening"])
        self.assertAlmostEqual(blink["right_eye_opening"], peak["right_eye_opening"])
        self.assertGreater(peak["blue_squeeze"], blink["blue_squeeze"] + 0.4)
        self.assertGreater(peak["orange_squeeze"], blink["orange_squeeze"] + 0.4)

    def test_squint_tracks_lower_lid_lift_without_counting_symmetric_blink(self):
        neutral = face_points()
        raised = face_points()
        blink = face_points()
        widened = face_points()
        for lower in (145, 374):
            raised[lower] = SimpleNamespace(x=neutral[lower].x, y=0.455)
            blink[lower] = SimpleNamespace(x=neutral[lower].x, y=0.46)
        for upper in (159, 386):
            blink[upper] = SimpleNamespace(x=neutral[upper].x, y=0.46)
            widened[upper] = SimpleNamespace(x=neutral[upper].x, y=0.435)

        base = extract_features("face_6", neutral, (640, 480))
        lifted = extract_features("face_6", raised, (640, 480))
        closed = extract_features("face_6", blink, (640, 480))
        wide = extract_features("face_6", widened, (640, 480))
        for side in ("blue", "orange"):
            center = f"{side}_squint"
            aperture = f"{side}_squint_aperture"
            self.assertGreater(lifted[center] - base[center], 0.05)
            self.assertAlmostEqual(closed[center], base[center], places=6)
            self.assertAlmostEqual(wide[center], lifted[center], places=6)
            self.assertGreater(wide[aperture], base[aperture])
            self.assertGreater(base[aperture], lifted[aperture])
            self.assertEqual(closed[aperture], 0)
            self.assertAlmostEqual(
                wide[center] - wide[aperture] / 2,
                base[center] - base[aperture] / 2,
            )

        far = [
            SimpleNamespace(x=0.5 + (p.x - 0.5) * 0.55,
                            y=0.5 + (p.y - 0.5) * 0.55)
            for p in raised
        ]
        resized = [
            SimpleNamespace(x=(p.x * 640 * 1.5 + 160) / 1280,
                            y=(p.y * 480 * 1.5) / 720)
            for p in raised
        ]
        for variant, size in ((far, (640, 480)), (resized, (1280, 720))):
            measured = extract_features("face_6", variant, size)
            for side in (
                "blue_squint", "orange_squint",
                "blue_squint_aperture", "orange_squint_aperture",
            ):
                self.assertAlmostEqual(lifted[side], measured[side], places=6)

    def test_every_active_exercise_has_legacy_delta_fields(self):
        points = face_points()
        for exercise in EXERCISES:
            with self.subTest(exercise=exercise):
                baseline = extract_features(exercise, points)
                delta = compare_features(exercise, baseline, baseline)
                self.assertTrue(all(isinstance(v, float) for v in delta.values()))
                if exercise in {"face_1", "face_2"}:
                    self.assertIn("relative_lift", delta)
                    self.assertAlmostEqual(delta["relative_lift"], 1.0)
                elif exercise == "lip_4":
                    self.assertIn("smile_score", delta)
                    self.assertAlmostEqual(delta["smile_score"], 0.0)
                else:
                    self.assertIn("left_close", delta)
                    self.assertIn("right_close", delta)
                    self.assertIn("relative_change", delta)

    def test_smile_score_increases_with_wider_raised_corners(self):
        neutral = face_points()
        smiling = face_points()
        smiling[61] = SimpleNamespace(x=0.32, y=0.57)
        smiling[291] = SimpleNamespace(x=0.68, y=0.57)
        delta = compare_features(
            "lip_4", extract_features("lip_4", neutral), extract_features("lip_4", smiling)
        )
        self.assertGreater(delta["smile_score"], 0.1)
        self.assertGreater(delta["corner_lift_change"], 0.0)

    def test_smile_observation_measures_sides_and_ignores_camera_distance(self):
        neutral = face_points()
        smiling = face_points()
        smiling[61] = SimpleNamespace(x=0.32, y=0.57)
        smiling[291] = SimpleNamespace(x=0.68, y=0.57)
        base = extract_features("lip_4", neutral, (640, 480))
        raised = extract_features("lip_4", smiling, (640, 480))
        for side in ("blue_smile", "orange_smile"):
            self.assertGreater(raised[side] - base[side], 0.08)

        one_side = face_points()
        one_side[61] = smiling[61]
        unilateral = extract_features("lip_4", one_side, (640, 480))
        self.assertGreater(unilateral["blue_smile"], base["blue_smile"])
        self.assertAlmostEqual(unilateral["orange_smile"], base["orange_smile"])

        far = [
            SimpleNamespace(x=0.5 + (p.x - 0.5) * 0.55,
                            y=0.5 + (p.y - 0.5) * 0.55)
            for p in smiling
        ]
        resized = [
            SimpleNamespace(x=(p.x * 640 * 1.5 + 160) / 1280,
                            y=(p.y * 480 * 1.5) / 720)
            for p in smiling
        ]
        for variant, size in ((far, (640, 480)), (resized, (1280, 720))):
            measured = extract_features("lip_4", variant, size)
            for side in ("blue_smile", "orange_smile"):
                self.assertAlmostEqual(raised[side], measured[side], places=6)

        angle = radians(15)
        rotated = []
        for p in smiling:
            x, y = (p.x - 0.5) * 640, (p.y - 0.5) * 480
            rotated.append(SimpleNamespace(
                x=0.5 + (x * cos(angle) - y * sin(angle)) / 640,
                y=0.5 + (x * sin(angle) + y * cos(angle)) / 480,
            ))
        rolled = extract_features("lip_4", rotated, (640, 480))
        for side in ("blue_smile", "orange_smile"):
            self.assertAlmostEqual(raised[side], rolled[side], places=6)

        open_mouth = face_points()
        open_mouth[14] = SimpleNamespace(x=0.5, y=0.68)
        opened = extract_features("lip_4", open_mouth, (640, 480))
        for side in ("blue_smile", "orange_smile"):
            self.assertAlmostEqual(base[side], opened[side], places=6)

    def test_eye_closure_is_per_eye_and_bounded(self):
        neutral = face_points()
        wink = face_points()
        wink[145] = SimpleNamespace(x=0.35, y=0.45)
        delta = compare_features(
            "face_7", extract_features("face_7", neutral), extract_features("face_7", wink)
        )
        self.assertEqual(delta["left_close"], 1.0)
        self.assertEqual(delta["right_close"], 0.0)

    def test_eye_openings_ignore_camera_distance_and_image_aspect_ratio(self):
        near = face_points()
        far = [
            SimpleNamespace(x=0.5 + (p.x - 0.5) * 0.55,
                            y=0.5 + (p.y - 0.5) * 0.55)
            for p in near
        ]
        first = extract_features("face_3", near, (640, 480))
        second = extract_features("face_3", far, (640, 480))
        for side in ("left_eye_opening", "right_eye_opening"):
            self.assertAlmostEqual(first[side], second[side], places=6)

        resized = [
            SimpleNamespace(x=(p.x * 640 * 1.5 + 160) / 1280,
                            y=(p.y * 480 * 1.5) / 720)
            for p in near
        ]
        third = extract_features("face_3", resized, (1280, 720))
        for side in ("left_eye_opening", "right_eye_opening"):
            self.assertAlmostEqual(first[side], third[side], places=6)

    def test_zero_baseline_is_rejected(self):
        with self.assertRaises(CalibrationError):
            compare_features(
                "face_4",
                {"left_eye_opening": 0.0, "right_eye_opening": 0.2},
                {"left_eye_opening": 0.1, "right_eye_opening": 0.1},
            )

    def test_brow_gaps_ignore_distance_and_image_aspect_ratio(self):
        near = face_points()
        far = [
            SimpleNamespace(x=0.5 + (p.x - 0.5) * 0.55,
                            y=0.5 + (p.y - 0.5) * 0.55)
            for p in near
        ]
        first = extract_features("face_1", near, (640, 480))
        second = extract_features("face_1", far, (640, 480))
        self.assertAlmostEqual(first["blue_gap"], second["blue_gap"], places=6)
        self.assertAlmostEqual(first["orange_gap"], second["orange_gap"], places=6)

        resized = [
            SimpleNamespace(x=(p.x * 640 * 1.5 + 160) / 1280,
                            y=(p.y * 480 * 1.5) / 720)
            for p in near
        ]
        third = extract_features("face_1", resized, (1280, 720))
        self.assertAlmostEqual(first["blue_gap"], third["blue_gap"], places=6)
        self.assertAlmostEqual(first["orange_gap"], third["orange_gap"], places=6)

    def test_frown_scores_ignore_distance_and_head_roll(self):
        points = face_points()
        points[65] = SimpleNamespace(x=0.39, y=0.36)
        points[295] = SimpleNamespace(x=0.65, y=0.36)
        far = [
            SimpleNamespace(x=0.5 + (p.x - 0.5) * 0.55,
                            y=0.5 + (p.y - 0.5) * 0.55)
            for p in points
        ]
        angle = radians(15)
        rotated = []
        for p in points:
            x, y = (p.x - 0.5) * 640, (p.y - 0.5) * 480
            rotated.append(SimpleNamespace(
                x=0.5 + (x * cos(angle) - y * sin(angle)) / 640,
                y=0.5 + (x * sin(angle) + y * cos(angle)) / 480,
            ))
        expected = extract_features("face_2", points, (640, 480))
        for variant in (far, rotated):
            measured = extract_features("face_2", variant, (640, 480))
            for side in ("blue_frown", "orange_frown"):
                self.assertAlmostEqual(expected[side], measured[side], places=6)

    def test_brow_gaps_ignore_head_roll(self):
        points = face_points()
        angle = radians(15)
        rotated = []
        for p in points:
            x, y = (p.x - 0.5) * 640, (p.y - 0.5) * 480
            rotated.append(SimpleNamespace(
                x=0.5 + (x * cos(angle) - y * sin(angle)) / 640,
                y=0.5 + (x * sin(angle) + y * cos(angle)) / 480,
            ))
        first = extract_features("face_1", points, (640, 480))
        second = extract_features("face_1", rotated, (640, 480))
        self.assertAlmostEqual(first["blue_gap"], second["blue_gap"], places=6)
        self.assertAlmostEqual(first["orange_gap"], second["orange_gap"], places=6)


if __name__ == "__main__":
    unittest.main()
