import 'package:flutter/material.dart';

import 'exercise_sections/face_exercises/face_1_exercises.dart';
import 'exercise_sections/face_exercises/face_2_exercises.dart';
import 'exercise_sections/face_exercises/face_3_exercises.dart';
import 'exercise_sections/face_exercises/face_4_exercises.dart';
import 'exercise_sections/face_exercises/face_6_exercises.dart';
import 'exercise_sections/face_exercises/face_7_exercises.dart';
import 'exercise_sections/lips_exercises/lips_4_exercises.dart';

/// Developer-only entry point for camera testing before the database exists.
class LocalExerciseTestApp extends StatelessWidget {
  const LocalExerciseTestApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Smile Quest: проверка упражнений',
    initialRoute: '/home',
    routes: {
      '/home': (context) => const _ExerciseList(),
      '/face_1': (context) => const Face1Exercises(),
      '/face_1_v2': (context) => const Face1Exercises.appInterface(),
      '/face_2': (context) => const Face2Exercises(),
      '/face_2_v2': (context) => const Face1Exercises.frown(),
      '/face_3': (context) => const Face3Exercises(),
      '/face_3_v2': (context) => const Face1Exercises.eyeClose(),
      '/face_4': (context) => const Face4Exercises(),
      '/face_4_v2': (context) => const Face1Exercises.blink(),
      '/face_6': (context) => const Face6Exercises(),
      '/face_6_v2': (context) => const Face1Exercises.squint(),
      '/face_7': (context) => const Face7Exercises(),
      '/face_7_v2': (context) => const Face1Exercises.wink(),
      '/lip_4': (context) => const Lips4Exercises(),
      '/lip_4_v2': (context) => const Face1Exercises.smile(),
    },
  );
}

class _ExerciseList extends StatelessWidget {
  const _ExerciseList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Проверка упражнений')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Локальный тест без базы данных. Запустите сервер упражнений на компьютере и выполните adb reverse tcp:8000 tcp:8000.',
        ),
        const SizedBox(height: 16),
        for (final exercise in const [
          ('Брови вверх', '/face_1'),
          ('Поднятие бровей 2.0', '/face_1_v2'),
          ('Нахмурить брови', '/face_2'),
          ('Нахмурить брови 2.0', '/face_2_v2'),
          ('Зажмурить глаза', '/face_3'),
          ('Закрыть глаза 2.0', '/face_3_v2'),
          ('Моргание', '/face_4'),
          ('Поморгать 2.0', '/face_4_v2'),
          ('Прищур', '/face_6'),
          ('Прищур 2.0', '/face_6_v2'),
          ('Подмигивание', '/face_7'),
          ('Подмигивание 2.0', '/face_7_v2'),
          ('Улыбка', '/lip_4'),
          ('Улыбка 2.0', '/lip_4_v2'),
        ])
          ListTile(
            title: Text(exercise.$1),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(exercise.$2),
          ),
      ],
    ),
  );
}
