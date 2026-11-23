import 'dart:io';

import 'package:flutter/services.dart';

/// Real Cyrillic glyph metrics instead of the test runner's square Ahem font.
/// This font is test-only and does not change the app's typography.
Future<void> loadUiTestFonts() async {
  final bytes = await File('test/fonts/Roboto.ttf').readAsBytes();
  for (final family in [
    'Roboto',
    'SF Pro',
    'SF Pro Display',
    'SF Pro Rounded',
  ]) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}
