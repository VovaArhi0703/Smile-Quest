"""Visual signals for small facial movements that have a direct model output."""

from math import hypot, isfinite
from typing import Mapping, Sequence


DETAIL_EXERCISES = {"face_8": ("nose_wrinkle_left", "nose_wrinkle_right")}

# Eye corners provide a reference for position, independent of the eyelids.
EYE_CORNERS = (33, 133, 362, 263)
NOSE_TIP = 1
NOSE_LANDMARKS = (NOSE_TIP, 6, 49, 64, 98, 278, 294, 327)


def detail_landmarks(exercise: str) -> frozenset[int]:
    if exercise == "face_8":
        return frozenset(NOSE_LANDMARKS)
    raise ValueError("Unknown detail exercise")


def detail_features(
    exercise: str,
    points: Sequence,
    image_size: tuple[int, int],
    blendshapes: Mapping[str, float] | None = None,
) -> dict[str, float]:
    if exercise != "face_8":
        raise ValueError("Unknown detail exercise")
    _check_nose_view(points, image_size)
    if blendshapes is None:
        raise ValueError("Nose movement is unavailable for this frame")

    # These scores represent movement at each side of the nose. A smile,
    # upper lip lift or eye squint on its own is not a nose wrinkle.
    left = blendshapes.get("noseSneerLeft")
    right = blendshapes.get("noseSneerRight")
    if left is None or right is None or not all(
        isfinite(value) and 0 <= value <= 1 for value in (left, right)
    ):
        raise ValueError("Nose movement is unavailable for this frame")
    return {"nose_wrinkle_left": float(left), "nose_wrinkle_right": float(right)}


def _check_nose_view(points: Sequence, image_size: tuple[int, int]) -> None:
    width, height = image_size
    required = (*EYE_CORNERS, *NOSE_LANDMARKS)
    if width <= 0 or height <= 0 or len(points) <= max(required):
        raise ValueError("Nose landmarks are incomplete")
    if any(not (0 <= points[index].x <= 1 and 0 <= points[index].y <= 1)
           for index in required):
        raise ValueError("Keep the nose and both eyes inside the frame")

    def eye_center(a: int, b: int) -> tuple[float, float]:
        return ((points[a].x + points[b].x) * width / 2,
                (points[a].y + points[b].y) * height / 2)

    left_x, left_y = eye_center(33, 133)
    right_x, right_y = eye_center(362, 263)
    dx, dy = right_x - left_x, right_y - left_y
    eye_span = hypot(dx, dy)
    if eye_span < 35:
        raise ValueError("Move closer so the nose is visible")

    nose_x = points[NOSE_TIP].x * width - (left_x + right_x) / 2
    nose_y = points[NOSE_TIP].y * height - (left_y + right_y) / 2
    horizontal = (nose_x * dx + nose_y * dy) / eye_span**2
    vertical = (nose_y * dx - nose_x * dy) / eye_span**2
    if abs(horizontal) > 0.28 or vertical < 0.15:
        raise ValueError("Face the camera so both sides of the nose are visible")
