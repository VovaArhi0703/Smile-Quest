"""Pure geometry and the response fields expected by the Flutter exercises.

These scores are movement signals, not medical measurements. Thresholds in the
app still need validation with real patients and a rehabilitation specialist.
"""

from __future__ import annotations

from math import hypot, isfinite
from statistics import median
from typing import Sequence


EXERCISES = frozenset({"face_1", "face_2", "face_3", "face_4", "face_6", "face_7", "lip_4"})
EPSILON = 1e-6
BROW_BLUE = (53, 52, 65)
BROW_ORANGE = (283, 282, 295)
FACE_1_LANDMARKS = frozenset((*BROW_BLUE, *BROW_ORANGE, 33, 133, 263, 362))
FACE_3_LANDMARKS = frozenset((159, 145, 33, 133, 386, 374, 263, 362))
FACE_3_SQUEEZE_LANDMARKS = FACE_3_LANDMARKS | frozenset((111, 117, 340, 346))
LIP_4_LANDMARKS = frozenset((13, 61, 291, 33, 133, 263, 362))


class CalibrationError(ValueError):
    """The neutral frame cannot be used as a baseline."""


def _distance(points: Sequence, first: int, second: int) -> float:
    a, b = points[first], points[second]
    return hypot(a.x - b.x, a.y - b.y)


def _opening(
    points: Sequence,
    top: int,
    bottom: int,
    outer: int,
    inner: int,
    image_size: tuple[int, int] | None,
) -> float:
    image_width, image_height = image_size or (1, 1)
    if image_width <= 0 or image_height <= 0:
        raise CalibrationError("Invalid image dimensions")

    def pixel_distance(first: int, second: int) -> float:
        a, b = points[first], points[second]
        return hypot(
            (a.x - b.x) * image_width,
            (a.y - b.y) * image_height,
        )

    width = pixel_distance(outer, inner)
    if width <= EPSILON:
        raise CalibrationError("Eye width is too small; recalibrate")
    return pixel_distance(top, bottom) / width


def _squint_observation(
    points: Sequence,
    top: int,
    bottom: int,
    first_corner: int,
    second_corner: int,
    image_size: tuple[int, int] | None,
) -> tuple[float, float]:
    """Return lid-center height and vertical aperture in units of eye width.

    The center rises as the lower lid lifts. The aperture allows the client
    to distinguish that motion from raising the upper lid to open wider.
    """
    image_width, image_height = image_size or (1, 1)
    if image_width <= 0 or image_height <= 0:
        raise CalibrationError("Invalid image dimensions")

    def xy(index: int) -> tuple[float, float]:
        point = points[index]
        return point.x * image_width, point.y * image_height

    a, b = xy(first_corner), xy(second_corner)
    if a[0] > b[0]:
        a, b = b, a
    dx, dy = b[0] - a[0], b[1] - a[1]
    eye_width = hypot(dx, dy)
    if eye_width <= EPSILON:
        raise CalibrationError("Eye width is too small; recalibrate")
    corner_center = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    top_xy, bottom_xy = xy(top), xy(bottom)
    up = (dy / eye_width, -dx / eye_width)

    def height(point: tuple[float, float]) -> float:
        return ((point[0] - corner_center[0]) * up[0]
                + (point[1] - corner_center[1]) * up[1]) / eye_width

    upper = height(top_xy)
    lower = height(bottom_xy)
    return (upper + lower) / 2, max(0.0, upper - lower)


def _brow_features(
    points: Sequence, image_size: tuple[int, int] | None
) -> dict[str, float]:
    """Project each brow against the stable eye-corner line, not the eyelids.

    Ratios to interocular distance compensate for uniform camera zoom. Pixel
    coordinates avoid x/y distortion when image aspect ratios differ.
    """
    width, height = image_size or (1, 1)
    if width <= 0 or height <= 0:
        raise CalibrationError("Invalid image dimensions")

    def xy(index: int) -> tuple[float, float]:
        point = points[index]
        if not all(isfinite(value) and -0.1 <= value <= 1.1 for value in (point.x, point.y)):
            raise CalibrationError("Face landmarks are outside the frame")
        return point.x * width, point.y * height

    first = tuple((a + b) / 2 for a, b in zip(xy(33), xy(133)))
    second = tuple((a + b) / 2 for a, b in zip(xy(263), xy(362)))
    horizontal = (second[0] - first[0], second[1] - first[1])
    eye_distance = hypot(*horizontal)
    if eye_distance <= EPSILON or (image_size is not None and eye_distance < 35):
        raise CalibrationError("Face is too far from the camera")
    up = (horizontal[1] / eye_distance, -horizontal[0] / eye_distance)

    along = (horizontal[0] / eye_distance, horizontal[1] / eye_distance)

    def brow_height(indices: tuple[int, ...], eye_center: tuple[float, float]) -> float:
        return float(median(
            ((xy(index)[0] - eye_center[0]) * up[0]
             + (xy(index)[1] - eye_center[1]) * up[1]) / eye_distance
            for index in indices
        ))

    blue_height = brow_height(BROW_BLUE, first)
    orange_height = brow_height(BROW_ORANGE, second)
    # The inner brow moves toward the nose when frowning. A smaller downward
    # component also recognizes patients whose inward movement is limited.
    blue_inner = xy(65)
    orange_inner = xy(295)
    blue_canthus = xy(133)
    orange_canthus = xy(362)
    blue_inward = ((blue_inner[0] - blue_canthus[0]) * along[0]
                   + (blue_inner[1] - blue_canthus[1]) * along[1]) / eye_distance
    orange_inward = ((orange_canthus[0] - orange_inner[0]) * along[0]
                     + (orange_canthus[1] - orange_inner[1]) * along[1]) / eye_distance
    return {
        "blue_gap": blue_height,
        "orange_gap": orange_height,
        "blue_frown": blue_inward - 0.25 * blue_height,
        "orange_frown": orange_inward - 0.25 * orange_height,
    }


def _cheek_lift(points: Sequence, cheek: tuple[int, int], corners: tuple[int, int],
                image_size: tuple[int, int] | None) -> float:
    width, height = image_size or (1, 1)
    if width <= 0 or height <= 0:
        raise CalibrationError("Invalid image dimensions")
    def xy(index: int) -> tuple[float, float]:
        return points[index].x * width, points[index].y * height
    a, b = xy(corners[0]), xy(corners[1])
    dx, dy = b[0] - a[0], b[1] - a[1]
    eye_width = hypot(dx, dy)
    if eye_width <= EPSILON:
        raise CalibrationError("Eye width is too small; recalibrate")
    up = (dy / eye_width, -dx / eye_width)
    center = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    return float(median(
        ((xy(index)[0] - center[0]) * up[0]
         + (xy(index)[1] - center[1]) * up[1]) / eye_width
        for index in cheek
    ))


def _smile_features(
    points: Sequence, image_size: tuple[int, int] | None
) -> dict[str, float]:
    """Measure each mouth corner relative to the upper lip and eye axis."""
    width, height = image_size or (1, 1)
    if width <= 0 or height <= 0:
        raise CalibrationError("Invalid image dimensions")

    def xy(index: int) -> tuple[float, float]:
        point = points[index]
        if not all(isfinite(value) and -0.1 <= value <= 1.1 for value in (point.x, point.y)):
            raise CalibrationError("Face landmarks are outside the frame")
        return point.x * width, point.y * height

    left_eye = tuple((a + b) / 2 for a, b in zip(xy(33), xy(133)))
    right_eye = tuple((a + b) / 2 for a, b in zip(xy(263), xy(362)))
    dx, dy = right_eye[0] - left_eye[0], right_eye[1] - left_eye[1]
    eye_distance = hypot(dx, dy)
    if eye_distance <= EPSILON or (image_size is not None and eye_distance < 35):
        raise CalibrationError("Face is too far from the camera")
    horizontal = (dx / eye_distance, dy / eye_distance)
    up = (horizontal[1], -horizontal[0])
    center = xy(13)

    def corner_score(index: int, direction: int) -> float:
        corner = xy(index)
        offset = (corner[0] - center[0], corner[1] - center[1])
        outward = direction * (offset[0] * horizontal[0] + offset[1] * horizontal[1])
        lift = offset[0] * up[0] + offset[1] * up[1]
        return (outward + 0.6 * lift) / eye_distance

    return {"blue_smile": corner_score(61, -1),
            "orange_smile": corner_score(291, 1)}


def extract_features(
    exercise: str, points: Sequence, image_size: tuple[int, int] | None = None,
    blendshapes: dict[str, float] | None = None,
) -> dict[str, float]:
    """Use ratios so calibration and streaming frames can have different sizes."""
    if exercise not in EXERCISES:
        raise ValueError("Unknown exercise")
    if len(points) < 455:
        raise ValueError("Face landmarks are incomplete")

    face_width = _distance(points, 234, 454)
    if face_width <= EPSILON:
        raise CalibrationError("Face width is too small; recalibrate")

    if exercise == "face_1":
        per_brow = _brow_features(points, image_size)
        return {
            **per_brow,
            "brow_height": (per_brow["blue_gap"] + per_brow["orange_gap"]) / 2,
        }

    if exercise == "face_2":
        left = _distance(points, 65, 159)
        right = _distance(points, 295, 386)
        brow = _brow_features(points, image_size)
        return {"brow_height": (left + right) / (2 * face_width),
                "blue_frown": brow["blue_frown"],
                "orange_frown": brow["orange_frown"]}

    if exercise in {"face_3", "face_4", "face_6", "face_7"}:
        features = {
            "left_eye_opening": _opening(points, 159, 145, 33, 133, image_size),
            "right_eye_opening": _opening(points, 386, 374, 263, 362, image_size),
        }
        if exercise == "face_6":
            blue, blue_aperture = _squint_observation(points, 159, 145, 33, 133, image_size)
            orange, orange_aperture = _squint_observation(points, 386, 374, 263, 362, image_size)
            features.update({
                "blue_squint": blue,
                "orange_squint": orange,
                "blue_squint_aperture": blue_aperture,
                "orange_squint_aperture": orange_aperture,
            })
        if exercise == "face_3":
            blend = blendshapes or {}
            features.update({
                "blue_squeeze": (
                    0.65 * blend.get("eyeSquintLeft", 0.0)
                    + 0.35 * blend.get("cheekSquintLeft", 0.0)
                    + 0.25 * _cheek_lift(points, (111, 117), (33, 133), image_size)
                ),
                "orange_squeeze": (
                    0.65 * blend.get("eyeSquintRight", 0.0)
                    + 0.35 * blend.get("cheekSquintRight", 0.0)
                    + 0.25 * _cheek_lift(points, (340, 346), (263, 362), image_size)
                ),
            })
        return features

    mouth_width = _distance(points, 61, 291)
    if mouth_width <= EPSILON:
        raise CalibrationError("Mouth width is too small; recalibrate")
    mouth_center_y = (points[13].y + points[14].y) / 2
    corners_y = (points[61].y + points[291].y) / 2
    return {
        "mouth_width": mouth_width / face_width,
        "lip_opening": _distance(points, 13, 14) / face_width,
        "corner_lift": (mouth_center_y - corners_y) / face_width,
        **_smile_features(points, image_size),
    }


def _ratio(current: float, baseline: float) -> float:
    if baseline <= EPSILON:
        raise CalibrationError("Neutral eye or mouth opening is too small; recalibrate")
    return current / baseline


def _closure(current: float, baseline: float) -> float:
    return max(0.0, min(1.0, 1.0 - _ratio(current, baseline)))


def compare_features(
    exercise: str, baseline: dict[str, float], current: dict[str, float]
) -> dict[str, float]:
    """Return the legacy keys consumed by the seven active Flutter screens."""
    if exercise not in EXERCISES:
        raise ValueError("Unknown exercise")

    if exercise in {"face_1", "face_2"}:
        relative = _ratio(current["brow_height"], baseline["brow_height"])
        return {
            "brow_height_change": current["brow_height"] - baseline["brow_height"],
            "relative_lift": relative,
        }

    if exercise in {"face_3", "face_4", "face_6", "face_7"}:
        left_ratio = _ratio(current["left_eye_opening"], baseline["left_eye_opening"])
        right_ratio = _ratio(current["right_eye_opening"], baseline["right_eye_opening"])
        left_close = _closure(current["left_eye_opening"], baseline["left_eye_opening"])
        right_close = _closure(current["right_eye_opening"], baseline["right_eye_opening"])
        average = (left_close + right_close) / 2
        return {
            "left_ratio": left_ratio,
            "right_ratio": right_ratio,
            "left_close": left_close,
            "right_close": right_close,
            "blink_score": average,
            "squeeze_score": average,
            "relative_change": average,
        }

    width_change = _ratio(current["mouth_width"], baseline["mouth_width"])
    height_change = _ratio(current["lip_opening"], baseline["lip_opening"])
    corner_change = current["corner_lift"] - baseline["corner_lift"]
    # The old (left_diff - right_diff) term was identically zero because its
    # two mouth vectors were negatives of one another.
    smile_score = max(0.0, 0.6 * (width_change - 1.0) + 0.25 * corner_change + 0.15 * (1.0 - height_change))
    return {
        "width_change": width_change,
        "height_change": height_change,
        "corner_lift_change": corner_change,
        "smile_score": smile_score,
    }
