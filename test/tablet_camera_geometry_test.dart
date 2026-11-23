import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:untitled2/brow_frame_encoder.dart';
import 'package:untitled2/brow_visual_tracker.dart';
import 'package:untitled2/tablet_camera_geometry.dart';

void main() {
  test(
    'Android front and back camera rotations match each device orientation',
    () {
      const orientations = DeviceOrientation.values;
      const front = [270, 0, 90, 180];
      const back = [270, 180, 90, 0];
      for (var i = 0; i < orientations.length; i++) {
        expect(
          tabletFrameRotation(
            sensorOrientation: 270,
            orientation: orientations[i],
            frontFacing: true,
            android: true,
          ),
          front[i],
        );
        expect(
          tabletFrameRotation(
            sensorOrientation: 270,
            orientation: orientations[i],
            frontFacing: false,
            android: true,
          ),
          back[i],
        );
        expect(
          tabletFrameRotation(
            sensorOrientation: 90,
            orientation: orientations[i],
            frontFacing: true,
            android: false,
          ),
          0,
        );
      }
      expect(portraitViewportCrop(640, 480), (
        x: 140,
        y: 0,
        width: 360,
        height: 480,
      ));
      expect(portraitViewportCrop(480, 640), (
        x: 0,
        y: 0,
        width: 480,
        height: 640,
      ));
    },
  );

  for (final rotation in [0, 90, 180, 270]) {
    test(
      'server JPEG and landmark tracker sample the same visible crop at $rotation degrees',
      () async {
        const width = 64;
        const height = 48;
        final bytes = Uint8List(width * height * 4);
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final value = 30 + x * 2 + y;
            final offset = (y * width + x) * 4;
            bytes[offset] = bytes[offset + 1] = bytes[offset + 2] = value;
            bytes[offset + 3] = 255;
          }
        }
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
        final encoded = await compute(encodeTabletBrowFrame, (frame, rotation));
        final jpeg = img.decodeJpg(base64Decode(encoded!))!;
        final tracked =
            sampleBrowLuma(
              frame,
              sensorOrientation: rotation,
              rotateToPortrait: true,
              cropToPortrait: true,
            )!;
        expect(jpeg.width / jpeg.height, closeTo(3 / 4, 0.001));
        expect(tracked.width, jpeg.width);
        expect(tracked.height, jpeg.height);
        var difference = 0.0;
        for (var y = 0; y < tracked.height; y++) {
          for (var x = 0; x < tracked.width; x++) {
            difference += (tracked.at(x, y) - jpeg.getPixel(x, y).r).abs();
          }
        }
        expect(difference / (tracked.width * tracked.height), lessThan(4));
      },
    );
  }
}
