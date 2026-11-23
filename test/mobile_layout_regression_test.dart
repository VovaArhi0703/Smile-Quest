import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled2/main.dart';
import 'support/ui_fonts.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU');
    await loadUiTestFonts();
  });

  // Captured before adding the tablet layouts. Phone rendering must stay the
  // same while the tablet branch is developed independently.
  for (final entry
      in {
        'welcome': '/welcome',
        'sign_in': '/',
        'sign_up': '/signup',
        'home': '/home',
        'profile': '/profile_first',
        'exercise_map': '/face_exercises',
        'exercise': '/face_2_v2_exercises',
        'tasks': '/tasks',
      }.entries) {
    testWidgets('phone layout is unchanged: ${entry.key}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const RepaintBoundary(key: ValueKey('mobile-capture'), child: MyApp()),
      );
      navigatorKey.currentState!.pushNamed(entry.value);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('mobile-capture')),
        matchesGoldenFile('goldens/mobile_${entry.key}.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
