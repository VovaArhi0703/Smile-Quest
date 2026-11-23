import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import 'camera_frame.dart';
import 'tablet_camera_geometry.dart';

typedef BrowFrameInput =
    (CameraImage frame, int sensorOrientation, bool rotateToPortrait);

/// Runs in a worker isolate so camera conversion does not block the preview.
String? encodeBrowFrame(BrowFrameInput input) {
  final (frame, sensorOrientation, rotateToPortrait) = input;
  final rgb = cameraImageToRgb(frame, maxSide: 480);
  if (rgb == null) return null;
  final oriented =
      rotateToPortrait ? img.copyRotate(rgb, angle: sensorOrientation) : rgb;
  return base64Encode(img.encodeJpg(oriented, quality: 65));
}

/// Tablet frames follow device orientation and the visible portrait viewport.
/// The existing phone encoder above is intentionally unchanged.
String? encodeTabletBrowFrame((CameraImage, int) input) {
  final (frame, rotation) = input;
  final rgb = cameraImageToRgb(frame, maxSide: 480);
  if (rgb == null) return null;
  final oriented = rotation == 0 ? rgb : img.copyRotate(rgb, angle: rotation);
  final crop = portraitViewportCrop(oriented.width, oriented.height);
  final visible = img.copyCrop(
    oriented,
    x: crop.x,
    y: crop.y,
    width: crop.width,
    height: crop.height,
  );
  return base64Encode(img.encodeJpg(visible, quality: 65));
}
