import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';
import 'tablet_camera_geometry.dart';

/// A small, portrait-oriented luminance image used only for the dot overlay.
/// The server remains the source of truth for calibration and repetitions.
class BrowLumaFrame {
  const BrowLumaFrame(this.width, this.height, this.pixels);

  final int width;
  final int height;
  final Uint8List pixels;

  int at(int x, int y) => pixels[y * width + x];
}

BrowLumaFrame? sampleBrowLuma(
  CameraImage frame, {
  required int sensorOrientation,
  required bool rotateToPortrait,
  int maxSide = 240,
  bool cropToPortrait = false,
}) {
  if (maxSide < 1) return null;
  final isYuv =
      frame.format.group == ImageFormatGroup.yuv420 && frame.planes.length == 3;
  final isBgra =
      frame.format.group == ImageFormatGroup.bgra8888 &&
      frame.planes.length == 1;
  if (!isYuv && !isBgra) return null;

  final rotation = rotateToPortrait ? sensorOrientation % 360 : 0;
  if (rotation != 0 && rotation != 90 && rotation != 180 && rotation != 270) {
    return null;
  }
  final sourceWidth = frame.width;
  final sourceHeight = frame.height;
  final rotatedWidth = rotation % 180 == 0 ? sourceWidth : sourceHeight;
  final rotatedHeight = rotation % 180 == 0 ? sourceHeight : sourceWidth;
  final crop =
      cropToPortrait
          ? portraitViewportCrop(rotatedWidth, rotatedHeight)
          : (x: 0, y: 0, width: rotatedWidth, height: rotatedHeight);
  final scale = (maxSide /
          (crop.width > crop.height ? crop.width : crop.height))
      .clamp(0.0, 1.0);
  final width = (crop.width * scale).round().clamp(1, crop.width);
  final height = (crop.height * scale).round().clamp(1, crop.height);
  final pixels = Uint8List(width * height);
  final plane = frame.planes.first;

  try {
    for (var y = 0; y < height; y++) {
      final ry = crop.y + y * crop.height ~/ height;
      for (var x = 0; x < width; x++) {
        final rx = crop.x + x * crop.width ~/ width;
        final (sx, sy) = switch (rotation) {
          90 => (ry, sourceHeight - 1 - rx),
          180 => (sourceWidth - 1 - rx, sourceHeight - 1 - ry),
          270 => (sourceWidth - 1 - ry, rx),
          _ => (rx, ry),
        };
        if (isYuv) {
          pixels[y * width + x] = plane.bytes[sy * plane.bytesPerRow + sx];
        } else {
          final offset = sy * plane.bytesPerRow + sx * 4;
          final b = plane.bytes[offset];
          final g = plane.bytes[offset + 1];
          final r = plane.bytes[offset + 2];
          pixels[y * width + x] = (77 * r + 150 * g + 29 * b) >> 8;
        }
      }
    }
  } catch (_) {
    return null;
  }
  return BrowLumaFrame(width, height, pixels);
}

/// Follows visible brow and eye texture from the server's frame to the latest
/// camera frame. This never changes the measurements sent to BrowExerciseLogic.
class BrowVisualTracker {
  BrowVisualTracker({this.eyeMode = false, this.mouthMode = false});

  final bool eyeMode;
  final bool mouthMode;
  BrowLumaFrame? _reference;
  Map<int, Offset> _serverPoints = const {};

  static const _blueBrows = [53, 52, 65];
  static const _blueEyes = [160, 159, 158, 33, 133];
  static const _orangeBrows = [283, 282, 295];
  static const _orangeEyes = [387, 386, 385, 263, 362];
  static const _blueClosurePoints = [159, 145, 33, 133];
  static const _orangeClosurePoints = [386, 374, 263, 362];
  static const _mouthPoints = [13, 61, 291];
  static const _mouthEyePoints = [33, 133, 263, 362];

  void reset() {
    _reference = null;
    _serverPoints = const {};
  }

  void setObservation(Map<int, Offset> points, BrowLumaFrame? frame) {
    _serverPoints = points;
    _reference = frame;
  }

  Map<int, Offset> track(BrowLumaFrame? current) {
    final reference = _reference;
    if (reference == null ||
        current == null ||
        reference.width != current.width ||
        reference.height != current.height ||
        _serverPoints.isEmpty) {
      return _serverPoints;
    }

    if (mouthMode) {
      final eyeShift = _groupShift(reference, current, _mouthEyePoints);
      final mouthShift =
          _groupShift(reference, current, _mouthPoints) ?? eyeShift;
      final result = <int, Offset>{};
      for (final entry in _serverPoints.entries) {
        final shift = _mouthPoints.contains(entry.key) ? mouthShift : eyeShift;
        result[entry.key] = Offset(
          (entry.value.dx + (shift?.dx ?? 0) / reference.width).clamp(0.0, 1.0),
          (entry.value.dy + (shift?.dy ?? 0) / reference.height).clamp(
            0.0,
            1.0,
          ),
        );
      }
      return result;
    }

    if (eyeMode) {
      final blueShift = _groupShift(reference, current, _blueClosurePoints);
      final orangeShift = _groupShift(reference, current, _orangeClosurePoints);
      final result = <int, Offset>{};
      for (final entry in _serverPoints.entries) {
        final shift =
            _blueClosurePoints.contains(entry.key) ? blueShift : orangeShift;
        result[entry.key] = Offset(
          (entry.value.dx + (shift?.dx ?? 0) / reference.width).clamp(0.0, 1.0),
          (entry.value.dy + (shift?.dy ?? 0) / reference.height).clamp(
            0.0,
            1.0,
          ),
        );
      }
      return result;
    }

    final blueEye = _groupShift(reference, current, _blueEyes);
    final orangeEye = _groupShift(reference, current, _orangeEyes);
    final global = _medianShift([
      if (blueEye != null) blueEye,
      if (orangeEye != null) orangeEye,
    ]);
    final blueBrow =
        _groupShift(reference, current, _blueBrows) ?? blueEye ?? global;
    final orangeBrow =
        _groupShift(reference, current, _orangeBrows) ?? orangeEye ?? global;
    if ([
      blueEye,
      orangeEye,
      blueBrow,
      orangeBrow,
    ].every((shift) => shift == null || shift == Offset.zero)) {
      return _serverPoints;
    }
    final result = <int, Offset>{};
    for (final entry in _serverPoints.entries) {
      final shift =
          _blueBrows.contains(entry.key)
              ? blueBrow
              : _orangeBrows.contains(entry.key)
              ? orangeBrow
              : _blueEyes.contains(entry.key)
              ? blueEye ?? global
              : orangeEye ?? global;
      result[entry.key] = Offset(
        (entry.value.dx + (shift?.dx ?? 0) / reference.width).clamp(0.0, 1.0),
        (entry.value.dy + (shift?.dy ?? 0) / reference.height).clamp(0.0, 1.0),
      );
    }
    return result;
  }

  Offset? _groupShift(
    BrowLumaFrame reference,
    BrowLumaFrame current,
    List<int> indices,
  ) {
    final shifts = <Offset>[];
    for (final index in indices) {
      final point = _serverPoints[index];
      if (point == null) continue;
      final shift = _match(
        reference,
        current,
        (point.dx * reference.width).round(),
        (point.dy * reference.height).round(),
      );
      if (shift != null) shifts.add(shift);
    }
    return _medianShift(shifts);
  }

  static Offset? _medianShift(List<Offset> shifts) {
    if (shifts.isEmpty) return null;
    final xs = shifts.map((s) => s.dx).toList()..sort();
    final ys = shifts.map((s) => s.dy).toList()..sort();
    return Offset(xs[xs.length ~/ 2], ys[ys.length ~/ 2]);
  }

  static Offset? _match(
    BrowLumaFrame reference,
    BrowLumaFrame current,
    int x,
    int y,
  ) {
    const radius = 3;
    const search = 12;
    if (x < radius + search ||
        y < radius + search ||
        x >= reference.width - radius - search ||
        y >= reference.height - radius - search) {
      return null;
    }

    // Flat skin patches have no useful motion signal.
    var sum = 0;
    var sumSquares = 0;
    for (var py = -radius; py <= radius; py++) {
      for (var px = -radius; px <= radius; px++) {
        final value = reference.at(x + px, y + py);
        sum += value;
        sumSquares += value * value;
      }
    }
    if (sumSquares * 49 - sum * sum < 49 * 49 * 65) return null;

    final sourcePixels = reference.pixels;
    final targetPixels = current.pixels;
    var unchanged = 0;
    for (var py = -radius; py <= radius; py++) {
      final row = (y + py) * reference.width + x;
      for (var px = -radius; px <= radius; px++) {
        unchanged += (sourcePixels[row + px] - targetPixels[row + px]).abs();
      }
    }
    var best = unchanged;
    var bestX = 0;
    var bestY = 0;
    for (var dy = -search; dy <= search; dy++) {
      for (var dx = -search; dx <= search; dx++) {
        if (dx == 0 && dy == 0) continue;
        var difference = 0;
        final penalty = (dx.abs() + dy.abs()) * 2;
        candidate:
        for (var py = -radius; py <= radius; py++) {
          final sourceRow = (y + py) * reference.width + x;
          final targetRow = (y + dy + py) * current.width + x + dx;
          for (var px = -radius; px <= radius; px++) {
            difference +=
                (sourcePixels[sourceRow + px] - targetPixels[targetRow + px])
                    .abs();
            if (difference + penalty >= best) break candidate;
          }
        }
        // Prefer the shorter shift when patches look nearly identical.
        final cost = difference + penalty;
        if (cost < best) {
          best = cost;
          bestX = dx;
          bestY = dy;
        }
      }
    }
    if (best > 49 * 24 ||
        (bestX != 0 || bestY != 0) && best >= unchanged * 0.93) {
      return null;
    }
    return Offset(bestX.toDouble(), bestY.toDouble());
  }
}
