import 'package:flutter_test/flutter_test.dart';
import 'package:untitled2/local_exercise_test_app.dart';

void main() {
  testWidgets('opens exercise menu without Supabase initialization', (tester) async {
    await tester.pumpWidget(const LocalExerciseTestApp());
    expect(find.text('Проверка упражнений'), findsOneWidget);
    expect(find.text('Брови вверх'), findsOneWidget);
  });
}
