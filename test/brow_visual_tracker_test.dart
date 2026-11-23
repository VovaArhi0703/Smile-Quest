import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:untitled2/brow_visual_tracker.dart';

void main() {
  test('luma rotation matches the JPEG encoder orientation', () {
    const width = 3;
    const height = 2;
    final values = [40, 70, 100, 130, 160, 190];
    final bytes = Uint8List.fromList(
      values.expand((value) => [value, value, value, 255]).toList(),
    );
    final frame = CameraImage.fromPlatformInterface(
      CameraImageData(
        format: const CameraImageFormat(
          ImageFormatGroup.bgra8888,
          raw: 1111970369,
        ),
        width: width,
        height: height,
        planes: [
          CameraImagePlane(
            bytes: bytes,
            bytesPerRow: width * 4,
            bytesPerPixel: 4,
          ),
        ],
      ),
    );
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final value = values[y * width + x];
        image.setPixelRgb(x, y, value, value, value);
      }
    }
    final rotated = img.copyRotate(image, angle: 270);
    final luma =
        sampleBrowLuma(frame, sensorOrientation: 270, rotateToPortrait: true)!;
    expect(luma.width, rotated.width);
    expect(luma.height, rotated.height);
    for (var y = 0; y < luma.height; y++) {
      for (var x = 0; x < luma.width; x++) {
        expect(luma.at(x, y), rotated.getPixel(x, y).r.toInt());
      }
    }
  });

  test('moves brow dots with texture while keeping eye dots in place', () {
    const width = 180;
    const height = 180;
    final reference = Uint8List(width * height)
      ..fillRange(0, width * height, 128);
    final current = Uint8List(width * height)
      ..fillRange(0, width * height, 128);
    const brow = {53: (55, 55), 52: (80, 55), 65: (105, 55)};
    const eye = {160: (55, 90), 159: (80, 90), 158: (105, 90)};
    void stamp(Uint8List target, int x, int y, int seed) {
      for (var py = -4; py <= 4; py++) {
        for (var px = -4; px <= 4; px++) {
          target[(y + py) * width + x + px] =
              30 + ((px * 37 + py * 53 + seed * 19).abs() % 180);
        }
      }
    }

    final points = <int, Offset>{};
    for (final entry in brow.entries) {
      final (x, y) = entry.value;
      stamp(reference, x, y, entry.key);
      stamp(current, x + 4, y - 5, entry.key);
      points[entry.key] = Offset(x / width, y / height);
    }
    for (final entry in eye.entries) {
      final (x, y) = entry.value;
      stamp(reference, x, y, entry.key);
      stamp(current, x, y, entry.key);
      points[entry.key] = Offset(x / width, y / height);
    }
    final tracker =
        BrowVisualTracker()
          ..setObservation(points, BrowLumaFrame(width, height, reference));
    final result = tracker.track(BrowLumaFrame(width, height, current));
    expect(result[52]!.dx * width, closeTo(84, 0.1));
    expect(result[52]!.dy * height, closeTo(50, 0.1));
    expect(result[159]!.dx * width, closeTo(80, 0.1));
    expect(result[159]!.dy * height, closeTo(90, 0.1));
  });
}
