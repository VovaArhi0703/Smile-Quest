"""Visible lip motion for additional Smile Quest 2.0 exercises."""

from __future__ import annotations

from statistics import fmean
from typing import Sequence

from .oral_metrics import (
    _ANCHORS,
    _CHIN,
    _LIPS,
    _LIP_CORNERS,
    _LIP_INNER_PAIRS,
    _LocalPoint,
    _lip_features,
    _lip_opening,
    _local_frame,
    _score,
)


LIP_VARIANT_EXERCISES = {
    "lips_10": ("upper_lip_lift", "lower_lip_drop", "lip_opening"),
    "lips_11": ("smile_right", "smile_left", "smile_balance", "lip_opening"),
    "lips_12": ("lip_pucker", "lip_smile", "lip_opening", "lip_width", "lip_rounding"),
}

_OVERLAYS = {
    "lips_10": frozenset((*_LIPS, *_CHIN)),
    "lips_11": frozenset(_LIPS),
    "lips_12": frozenset(_LIPS),
}


def lip_variant_landmarks(exercise: str) -> frozenset[int]:
    if exercise not in _OVERLAYS:
        raise ValueError("Unknown lip variant")
    return _OVERLAYS[exercise]


def _lip_edges(point: _LocalPoint) -> dict[str, float]:
    upper = fmean(point(top)[1] for top, _ in _LIP_INNER_PAIRS)
    lower = fmean(point(bottom)[1] for _, bottom in _LIP_INNER_PAIRS)
    chin = fmean(point(index)[1] for index in _CHIN)
    return {
        "upper_lip_lift": -upper,
        # Lowering the jaw alone moves both the chin and lower lip down.
        "lower_lip_drop": lower - chin,
        "lip_opening": _lip_opening(point),
    }


def _side_smile(point: _LocalPoint, blend: dict[str, float]) -> dict[str, float]:
    right, left = (point(index) for index in _LIP_CORNERS)
    center_x, upper_y, _ = point(13)
    smile_right = (
        0.7 * (center_x - right[0]) + 0.8 * (upper_y - right[1])
        + 0.16 * _score(blend, "mouthSmileRight")
    )
    smile_left = (
        0.7 * (left[0] - center_x) + 0.8 * (upper_y - left[1])
        + 0.16 * _score(blend, "mouthSmileLeft")
    )
    return {
        "smile_right": smile_right,
        "smile_left": smile_left,
        "smile_balance": smile_right - smile_left,
        "lip_opening": _lip_opening(point),
    }


def lip_variant_features(
    exercise: str,
    points: Sequence,
    image_size: tuple[int, int] | None,
    blendshapes: dict[str, float] | None,
) -> dict[str, float]:
    """Observe lip positions. The mesh cannot verify tooth exposure or speech."""
    indices = lip_variant_landmarks(exercise)
    point = _local_frame(points, image_size, indices.union(_ANCHORS))
    blend = blendshapes or {}
    if exercise == "lips_10":
        return _lip_edges(point)
    if exercise == "lips_11":
        return _side_smile(point, blend)
    lips = _lip_features(point, blend)
    return {key: lips[key] for key in LIP_VARIANT_EXERCISES[exercise]}
