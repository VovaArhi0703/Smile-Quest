import 'package:flutter/material.dart';
import 'package:untitled2/exercise_sections/exercise_template.dart';

class Lips4 extends StatelessWidget {
  const Lips4({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExerciseTemplate(
      categoryTitle: 'Упражнения для губ',
      exerciseTitle: 'Улыбка',
      exerciseGoal:
          'Тренировка мышц губ и уголков рта, развитие симметричной улыбки.',
      navigationRoute: '/lips_4_exercises',
      alternateRoute: '/lips_4_v2_exercises',
      alternateTitle: 'Улыбка 2.0',
    );
  }
}
