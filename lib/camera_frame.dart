import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Converts the camera plugin's YUV420 (Android) or BGRA8888 (iOS) stream.
img.Image? cameraImageToRgb(CameraImage frame, {int? maxSide}) {
  try {
    final width = frame.width;
    final height = frame.height;
    final scale = maxSide == null
        ? 1.0
        : (maxSide / (width > height ? width : height)).clamp(0.0, 1.0);
    final outputWidth = (width * scale).round().clamp(1, width);
    final outputHeight = (height * scale).round().clamp(1, height);
    final rgb = Uint8List(outputWidth * outputHeight * 3);

    if (frame.format.group == ImageFormatGroup.yuv420 &&
        frame.planes.length == 3) {
      final yPlane = frame.planes[0];
      final uPlane = frame.planes[1];
      final vPlane = frame.planes[2];
      final uStride = uPlane.bytesPerPixel ?? 1;
      final vStride = vPlane.bytesPerPixel ?? 1;

      for (var row = 0; row < outputHeight; row++) {
        final sourceRow = row * height ~/ outputHeight;
        for (var col = 0; col < outputWidth; col++) {
          final sourceCol = col * width ~/ outputWidth;
          final y = yPlane.bytes[sourceRow * yPlane.bytesPerRow + sourceCol].toDouble();
          final u = uPlane.bytes[(sourceRow ~/ 2) * uPlane.bytesPerRow +
                  (sourceCol ~/ 2) * uStride] -
              128.0;
          final v = vPlane.bytes[(sourceRow ~/ 2) * vPlane.bytesPerRow +
                  (sourceCol ~/ 2) * vStride] -
              128.0;
          final offset = (row * outputWidth + col) * 3;
          rgb[offset] = (y + 1.402 * v).round().clamp(0, 255);
          rgb[offset + 1] =
              (y - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
          rgb[offset + 2] = (y + 1.772 * u).round().clamp(0, 255);
        }
      }
    } else if (frame.format.group == ImageFormatGroup.bgra8888 &&
        frame.planes.length == 1) {
      final plane = frame.planes.single;
      if ((plane.bytesPerPixel ?? 4) != 4) return null;
      for (var row = 0; row < outputHeight; row++) {
        final sourceRow = row * height ~/ outputHeight;
        for (var col = 0; col < outputWidth; col++) {
          final sourceCol = col * width ~/ outputWidth;
          final source = sourceRow * plane.bytesPerRow + sourceCol * 4;
          final target = (row * outputWidth + col) * 3;
          rgb[target] = plane.bytes[source + 2];
          rgb[target + 1] = plane.bytes[source + 1];
          rgb[target + 2] = plane.bytes[source];
        }
      }
    } else {
      return null;
    }

    return img.Image.fromBytes(
      width: outputWidth,
      height: outputHeight,
      bytes: rgb.buffer,
      numChannels: 3,
    );
  } catch (_) {
    return null;
  }
}
