"""Oral gesture signals from the visible facial mesh.

These signals are calibrated to each player. Model depth and blendshapes are
estimates of appearance and cannot establish contact or measure force.
"""

from __future__ import annotations

from math import hypot, isfinite, sqrt
from statistics import fmean, median
from typing import Callable, Sequence


_RIGHT_EYE = (33, 133)
_LEFT_EYE = (263, 362)
_FOREHEAD = 10
_NOSE_BRIDGE = 168
_NOSE_BASE = 2
_ANCHORS = (*_RIGHT_EYE, *_LEFT_EYE, _FOREHEAD, _NOSE_BRIDGE, _NOSE_BASE)

_CHEEK_RIGHT = (187, 205, 206)
_CHEEK_LEFT = (411, 425, 426)
_CHIN = (152, 199)
_LIP_INNER_PAIRS = ((13, 14), (82, 87), (312, 317))
_LIP_CORNERS = (61, 291)
_LIP_OUTER_CENTER = (0, 17)
_LIPS = (
    *_LIP_CORNERS, *_LIP_OUTER_CENTER,
    *(index for pair in _LIP_INNER_PAIRS for index in pair),
)

_CHEEK_KEYS = (
    "cheek_volume", "cheek_balance", "cheek_right", "cheek_left",
    "cheek_puff", "lip_opening", "lip_center_opening",
)
_JAW_KEYS = (
    "jaw_open", "jaw_side", "jaw_forward", "chin_drop", "chin_side",
    "lip_opening", "lip_center_opening",
)
_LIP_KEYS = (
    "lip_pucker", "lip_smile", "lip_x", "lip_y", "upper_lip_roll",
    "lower_lip_roll", "upper_lip_raise", "lower_lip_drop", "lip_opening",
    "lip_center_opening", "lip_rounding", "lip_width",
)

ORAL_EXERCISES = {
    **dict.fromkeys(("cheeks_1", "cheeks_2", "cheeks_3", "cheeks_4", "cheeks_5"), _CHEEK_KEYS),
    **dict.fromkeys(("jaw_1", "jaw_2", "jaw_3"), _JAW_KEYS),
    **dict.fromkeys(("lips_1", "lips_2", "lips_3", "lips_6", "lips_7", "lips_8", "lips_9"), _LIP_KEYS),
}

_ORAL_LANDMARKS = {
    "cheeks": frozenset((*_CHEEK_RIGHT, *_CHEEK_LEFT, *_LIPS)),
    "jaw": frozenset((*_CHIN, *_LIPS, _NOSE_BASE)),
    "lips": frozenset((*_LIPS, _NOSE_BASE)),
}

_Vec3 = tuple[float, float, float]
_LocalPoint = Callable[[int], _Vec3]


def oral_landmarks(exercise: str) -> frozenset[int]:
    """Mouth, cheek, or chin points used by the selected exercise."""
    if exercise not in ORAL_EXERCISES:
        raise ValueError("Unknown oral exercise")
    return _ORAL_LANDMARKS[exercise.split("_")[0]]


def _subtract(a: _Vec3, b: _Vec3) -> _Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _scale(value: _Vec3, factor: float) -> _Vec3:
    return (value[0] * factor, value[1] * factor, value[2] * factor)


def _dot(a: _Vec3, b: _Vec3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a: _Vec3, b: _Vec3) -> _Vec3:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def _midpoint(a: _Vec3, b: _Vec3) -> _Vec3:
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)


def _local_frame(
    points: Sequence, image_size: tuple[int, int] | None, indices: frozenset[int],
) -> _LocalPoint:
    """Project to head axes so translation, scale and modest rotation cancel."""
    width, height = image_size or (1, 1)
    if width <= 0 or height <= 0:
        raise ValueError("Invalid image dimensions")
    if len(points) <= max(indices):
        raise ValueError("Face landmarks are incomplete")

    screen = {}
    for index in indices:
        point = points[index]
        if not (0.01 <= point.x <= 0.99 and 0.01 <= point.y <= 0.99 and isfinite(point.z)):
            raise ValueError("Keep your entire face in the frame")
        # MediaPipe's z is scaled as x, even on portrait frames.
        screen[index] = (point.x * width, point.y * height, point.z * width)

    right_eye = _midpoint(*(screen[index] for index in _RIGHT_EYE))
    left_eye = _midpoint(*(screen[index] for index in _LEFT_EYE))
    across = _subtract(left_eye, right_eye)
    if hypot(across[0], across[1]) < (35 if image_size is not None else 0.05):
        raise ValueError("Face is too far from the camera")
    span = sqrt(_dot(across, across))
    horizontal = _scale(across, 1 / span)
    forehead_to_bridge = _subtract(screen[_NOSE_BRIDGE], screen[_FOREHEAD])
    vertical = _subtract(
        forehead_to_bridge, _scale(horizontal, _dot(forehead_to_bridge, horizontal)),
    )
    height = sqrt(_dot(vertical, vertical))
    if height < span * 0.18:
        raise ValueError("Look toward the camera")
    down = _scale(vertical, 1 / height)
    depth = _cross(horizontal, down)
    if depth[2] < 0.72:
        raise ValueError("Look toward the camera")

    origin = screen[_NOSE_BASE]

    def local(index: int) -> _Vec3:
        offset = _subtract(screen[index], origin)
        return (
            _dot(offset, horizontal) / span,
            _dot(offset, down) / span,
            _dot(offset, depth) / span,
        )

    return local


def _lip_opening(point: _LocalPoint) -> float:
    return max(0.0, float(median(
        point(bottom)[1] - point(top)[1] for top, bottom in _LIP_INNER_PAIRS
    )))


def _lip_center_opening(point: _LocalPoint) -> float:
    top, bottom = _LIP_INNER_PAIRS[0]
    return max(0.0, point(bottom)[1] - point(top)[1])


def _score(blend: dict[str, float], key: str, *, required: bool = False) -> float:
    score = blend.get(key)
    if score is None and not required:
        return 0.0
    if score is None or not isfinite(score) or not 0 <= score <= 1:
        raise ValueError("Facial expression score is unavailable for this frame")
    return score


def _cheek_features(point: _LocalPoint, blend: dict[str, float]) -> dict[str, float]:
    # Lateral expansion and anterior displacement of each cheek are useful
    # together. The shared puff blendshape cannot tell which cheek is active.
    right = fmean(-point(i)[0] - 0.7 * point(i)[2] for i in _CHEEK_RIGHT)
    left = fmean(point(i)[0] - 0.7 * point(i)[2] for i in _CHEEK_LEFT)
    puff = _score(blend, "cheekPuff")
    return {
        "cheek_volume": (right + left) / 2 + 0.18 * puff,
        "cheek_balance": right - left,
        "cheek_right": right,
        "cheek_left": left,
        "cheek_puff": puff,
        "lip_opening": _lip_opening(point),
        "lip_center_opening": _lip_center_opening(point),
    }


def _jaw_features(point: _LocalPoint, blend: dict[str, float]) -> dict[str, float]:
    chin_x, chin_y, chin_z = _midpoint(*(point(index) for index in _CHIN))
    return {
        # Chin displacement allows a cycle to be seen with lips together.
        "jaw_open": chin_y + 0.25 * _score(blend, "jawOpen"),
        "jaw_side": -chin_x + 0.15 * (_score(blend, "jawRight") - _score(blend, "jawLeft")),
        "chin_drop": chin_y,
        "chin_side": -chin_x,
        # This is a monocular depth cue, useful only as a calibrated estimate.
        "jaw_forward": -chin_z + 0.15 * _score(blend, "jawForward"),
        "lip_opening": _lip_opening(point),
        "lip_center_opening": _lip_center_opening(point),
    }


def _lip_features(
    point: _LocalPoint, blend: dict[str, float], *, require_roll: bool = False,
) -> dict[str, float]:
    right, left = (point(index) for index in _LIP_CORNERS)
    upper, lower = (point(index) for index in _LIP_OUTER_CENTER)
    center_x, center_y, _ = _midpoint(upper, lower)
    width = left[0] - right[0]
    corner_lift = center_y - (left[1] + right[1]) / 2
    pucker = _score(blend, "mouthPucker")
    funnel = _score(blend, "mouthFunnel")
    smile = (_score(blend, "mouthSmileLeft") + _score(blend, "mouthSmileRight")) / 2
    upper_up = (_score(blend, "mouthUpperUpLeft") + _score(blend, "mouthUpperUpRight")) / 2
    lower_down = (
        _score(blend, "mouthLowerDownLeft") + _score(blend, "mouthLowerDownRight")
    ) / 2
    return {
        "lip_pucker": 0.25 * pucker + 0.12 * funnel - width,
        "lip_rounding": max(pucker, funnel),
        "lip_width": width,
        "lip_smile": width + 0.65 * corner_lift + 0.2 * smile,
        # The preview may be mirrored. Directions here are anatomical.
        "lip_x": -center_x,
        "lip_y": -center_y,
        "upper_lip_roll": _score(blend, "mouthRollUpper", required=require_roll),
        "lower_lip_roll": _score(blend, "mouthRollLower", required=require_roll),
        "upper_lip_raise": -upper[1] + 0.20 * upper_up,
        "lower_lip_drop": lower[1] + 0.20 * lower_down,
        "lip_opening": _lip_opening(point),
        "lip_center_opening": _lip_center_opening(point),
    }


def oral_features(
    exercise: str, points: Sequence, image_size: tuple[int, int] | None,
    blendshapes: dict[str, float] | None,
) -> dict[str, float]:
    """Return the observation features used by the corresponding 2.0 screen."""
    selected = oral_landmarks(exercise)
    point = _local_frame(points, image_size, selected.union(_ANCHORS))
    blend = blendshapes or {}
    if exercise.startswith("cheeks_"):
        return _cheek_features(point, blend)
    if exercise.startswith("jaw_"):
        return _jaw_features(point, blend)
    return _lip_features(point, blend, require_roll=exercise == "lips_6")
