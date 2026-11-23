import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled2/camera_frame.dart';

void main() {
  test('YUV420 conversion honors row and pixel stride', () {
    final frame = CameraImage.fromPlatformInterface(CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
      width: 2,
      height: 2,
      planes: [
        CameraImagePlane(
          bytes: Uint8List.fromList([80, 80, 0, 0, 80, 80, 0, 0]),
          bytesPerRow: 4,
        ),
        CameraImagePlane(
          bytes: Uint8List.fromList([90, 0, 0, 0]),
          bytesPerRow: 4,
          bytesPerPixel: 2,
        ),
        CameraImagePlane(
          bytes: Uint8List.fromList([240, 0, 0, 0]),
          bytesPerRow: 4,
          bytesPerPixel: 2,
        ),
      ],
    ));

    final pixel = cameraImageToRgb(frame)!.getPixel(1, 1);
    expect(pixel.r, greaterThan(230));
    expect(pixel.g, lessThan(20));
    expect(pixel.b, lessThan(20));
    final reduced = cameraImageToRgb(frame, maxSide: 1)!;
    expect(reduced.width, 1);
    expect(reduced.height, 1);
    expect(reduced.getPixel(0, 0).r, greaterThan(230));
  });

  test('BGRA conversion honors padded rows', () {
    final frame = CameraImage.fromPlatformInterface(CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.bgra8888, raw: 1111970369),
      width: 2,
      height: 1,
      planes: [
        CameraImagePlane(
          bytes: Uint8List.fromList([3, 2, 1, 255, 30, 20, 10, 255, 0, 0, 0, 0]),
          bytesPerRow: 12,
          bytesPerPixel: 4,
        ),
      ],
    ));

    final image = cameraImageToRgb(frame)!;
    expect(image.getPixel(0, 0).r, 1);
    expect(image.getPixel(0, 0).g, 2);
    expect(image.getPixel(0, 0).b, 3);
    expect(image.getPixel(1, 0).r, 10);
    expect(image.getPixel(1, 0).g, 20);
    expect(image.getPixel(1, 0).b, 30);
  });
}
