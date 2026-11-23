import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:untitled2/brow_frame_encoder.dart';

void main() {
  test('encodes and rotates a camera frame in a worker isolate', () async {
    final frame = CameraImage.fromPlatformInterface(CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.bgra8888, raw: 1111970369),
      width: 2,
      height: 1,
      planes: [
        CameraImagePlane(
          bytes: Uint8List.fromList([3, 2, 1, 255, 30, 20, 10, 255]),
          bytesPerRow: 8,
          bytesPerPixel: 4,
        ),
      ],
    ));

    final encoded = await compute(encodeBrowFrame, (frame, 90, true));
    final jpeg = img.decodeJpg(base64Decode(encoded!))!;
    expect(jpeg.width, 1);
    expect(jpeg.height, 2);
  });
}
