import 'package:flutter/material.dart';
import 'package:untitled2/exercise_sections/exercise_template.dart';

class Face4 extends StatelessWidget {
  const Face4({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExerciseTemplate(
      categoryTitle: 'Упражнения для мимических мышц',
      exerciseTitle: 'Поморгать',
      exerciseGoal:
          'Тренировка мышц век, увлажнение роговицы, улучшение координации.',
      navigationRoute: '/face_4_exercises',
      alternateRoute: '/face_4_v2_exercises',
      alternateTitle: 'Поморгать 2.0',
    );
  }
}
