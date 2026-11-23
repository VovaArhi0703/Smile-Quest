import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled2/exercise_sections/exercise_template.dart';
import 'package:untitled2/exercise_sections/face_exercises/face_1_exercises.dart';
import 'package:untitled2/exercise_sections/lips_exercises.dart';
import 'package:untitled2/local_exercise_test_app.dart';
import 'package:untitled2/main.dart';

void main() {
  const restored = [
    'cheeks_1',
    'cheeks_2',
    'cheeks_3',
    'cheeks_4',
    'cheeks_5',
    'jaw_1',
    'jaw_2',
    'jaw_3',
    'lips_1',
    'lips_2',
    'lips_3',
    'lips_6',
    'lips_7',
    'face_8',
  ];

  Future<void> openApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
  }

  testWidgets('restored cards start their original exercise screens', (
    tester,
  ) async {
    await openApp(tester);
    final routes = tester.widget<MaterialApp>(find.byType(MaterialApp)).routes;
    for (final id in restored) {
      expect(routes, isNot(contains('/${id}_v2_exercises')));
      navigatorKey.currentState!.pushNamed('/$id');
      await tester.pumpAndSettle();

      final template = tester.widget<ExerciseTemplate>(
        find.byType(ExerciseTemplate),
      );
      expect(template.alternateRoute, isNull);
      expect(find.text(template.exerciseTitle), findsOneWidget);
      expect(find.textContaining('2.0'), findsNothing);
      final start = find.text('Начать упражнение');
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();

      expect(find.text('Упражнение пока в разработке'), findsOneWidget);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a saved link to a removed card opens the lips section', (
    tester,
  ) async {
    await openApp(tester);
    final routes = tester.widget<MaterialApp>(find.byType(MaterialApp)).routes;
    for (var number = 8; number <= 12; number++) {
      expect(routes, isNot(contains('/lips_${number}_v2_exercises')));
      navigatorKey.currentState!.pushNamed('/lips_$number');
      await tester.pumpAndSettle();
      expect(find.byType(LipsExercisesPage), findsOneWidget);
      expect(find.byType(ExerciseTemplate), findsNothing);
      expect(find.text('Артикуляция «У–О–А–И» 2.0'), findsNothing);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the earlier frown 2.0 still opens from the original card', (
    tester,
  ) async {
    await openApp(tester);
    navigatorKey.currentState!.pushNamed('/face_2');
    await tester.pumpAndSettle();

    final alternate = find.text('Нахмурить брови 2.0');
    await tester.ensureVisible(alternate);
    await tester.tap(alternate);
    await tester.pumpAndSettle();

    final exercise = tester.widget<Face1Exercises>(find.byType(Face1Exercises));
    expect(exercise.frown, isTrue);
    expect(find.text('0/10'), findsOneWidget);
    expect(find.text('Включить камеру'), findsOneWidget);
  });

  testWidgets('test menu keeps the earlier 2.0 exercise choices', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const LocalExerciseTestApp());
    expect(find.text('Нахмурить брови 2.0'), findsOneWidget);
    expect(find.text('Улыбка 2.0'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(14));
  });
}
