import 'package:flutter/services.dart';

/// Mirrors the pinned Android camera plugin's getVideoOrientation calculation.
/// AVFoundation already rotates image stream buffers before delivering them.
int tabletFrameRotation({
  required int sensorOrientation,
  required DeviceOrientation orientation,
  required bool frontFacing,
  required bool android,
}) {
  if (!android) return 0;
  final deviceRotation = switch (orientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };
  return (sensorOrientation +
          (frontFacing ? deviceRotation : -deviceRotation)) %
      360;
}

typedef CameraViewportCrop = ({int x, int y, int width, int height});

/// The same centered 3:4 crop used by BoxFit.cover in the tablet preview.
CameraViewportCrop portraitViewportCrop(int width, int height) {
  final cropWidth =
      width / height > 3 / 4 ? (height * 3 / 4).round().clamp(1, width) : width;
  final cropHeight =
      width / height < 3 / 4
          ? (width * 4 / 3).round().clamp(1, height)
          : height;
  return (
    x: (width - cropWidth) ~/ 2,
    y: (height - cropHeight) ~/ 2,
    width: cropWidth,
    height: cropHeight,
  );
}
