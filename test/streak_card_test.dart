import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled2/game_scripts.dart';
import 'package:untitled2/widget/streak_card.dart';

Finder flame(String color) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName.endsWith('fire_$color.png'),
);

Color? dayColor(WidgetTester tester, int day) {
  final dot = tester.widget<Container>(find.byKey(ValueKey('streak-day-$day')));
  return (dot.decoration as BoxDecoration).color;
}

void main() {
  setUp(() {
    GamificationService.loginActivity.value = null;
  });

  testWidgets('the flame lights at two and dots use individual weekdays', (
    tester,
  ) async {
    const card = StreakCard();
    GamificationService.loginActivity.value = const LoginActivity(
      streak: 1,
      weekdays: {DateTime.wednesday},
    );
    await tester.pumpWidget(const MaterialApp(home: Center(child: card)));

    expect(flame('grey'), findsOneWidget);
    expect(flame('yellow'), findsNothing);
    expect(dayColor(tester, DateTime.wednesday), card.activeDotColor);
    expect(dayColor(tester, DateTime.tuesday), card.inactiveDotColor);

    GamificationService.loginActivity.value = LoginActivity.fromResponse({
      'login_streak': 2,
      'best_streak': 2,
      'weekdays': [DateTime.wednesday, DateTime.thursday, DateTime.sunday],
    });
    await tester.pump();

    expect(flame('yellow'), findsOneWidget);
    expect(flame('grey'), findsNothing);
    expect(dayColor(tester, DateTime.wednesday), card.activeDotColor);
    expect(dayColor(tester, DateTime.thursday), card.activeDotColor);
    expect(dayColor(tester, DateTime.sunday), card.activeDotColor);
    expect(dayColor(tester, DateTime.friday), card.inactiveDotColor);
  });

  testWidgets('compact card uses server record and Monday-to-Sunday order', (
    tester,
  ) async {
    const card = StreakCard(width: 74, view: StreakCardView.compact);
    GamificationService.loginActivity.value = const LoginActivity(
      streak: 1,
      best: 12,
      weekdays: {DateTime.monday, DateTime.saturday},
    );
    await tester.pumpWidget(const MaterialApp(home: Center(child: card)));

    expect(find.text('12'), findsOneWidget);
    expect(flame('grey'), findsOneWidget);
    expect(flame('yellow'), findsOneWidget);
    double previousDot = double.negativeInfinity;
    for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
      final dot = find.byKey(ValueKey('streak-day-$day'));
      final x = tester.getCenter(dot).dx;
      expect(x, greaterThan(previousDot));
      previousDot = x;
    }
    expect(dayColor(tester, DateTime.monday), card.activeDotColor);
    expect(dayColor(tester, DateTime.saturday), card.activeDotColor);
    expect(dayColor(tester, DateTime.sunday), card.inactiveDotColor);
  });
}
