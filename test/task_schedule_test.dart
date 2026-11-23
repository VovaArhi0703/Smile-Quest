import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:untitled2/tasks/task_schedule.dart';
import 'package:untitled2/tasks/task_store.dart';

Future<void> openDialog(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => open(context),
              child: const Text('Открыть'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
}

Finder dialogPanel(String label) =>
    find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Material &&
                widget.shape is RoundedRectangleBorder &&
                widget.clipBehavior == Clip.antiAlias,
          ),
        )
        .first;

void main() {
  testWidgets(
    'repeat saves weekdays and exercise parameters while reading older exclusions',
    (tester) async {
      TaskRepeat? result;
      await openDialog(tester, (context) async {
        result = await showTaskRepeat(
          context,
          initialRepeat: const TaskRepeat(
            days: {DateTime.monday},
            daysOff: {DateTime.wednesday, DateTime.friday},
          ),
        );
      });

      expect(find.text('Выбрать выходные'), findsNothing);
      expect(find.text('Добавить'), findsOneWidget);
      expect(tester.getSize(dialogPanel('Повтор')), const Size(343, 293.25));
      await tester.tap(find.text('Вт'));
      await tester.tap(find.text('Ср'));
      await tester.tap(find.bySemanticsLabel('Повторение упражнения').last);
      await tester.pumpAndSettle();
      expect(find.text('Интервал'), findsOneWidget);
      expect(find.text('Подходов'), findsOneWidget);
      expect(tester.getSize(dialogPanel('Повтор')), const Size(343, 344.25));
      await tester.tap(find.text('3 часа'));
      await tester.pumpAndSettle();
      final wheel = tester.widget<ListWheelScrollView>(
        find.byType(ListWheelScrollView),
      );
      (wheel.controller! as FixedExtentScrollController).jumpToItem(4);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('5 часов'), findsOneWidget);
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();

      expect(result!.days, {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
      });
      expect(result!.daysOff, {DateTime.friday});
      expect(result!.exerciseReminders, isTrue);
      expect(result!.intervalHours, 5);
      expect(result!.sets, 2);
    },
  );

  testWidgets('hour and minute wheels save the selected time', (tester) async {
    TimeOfDay? result;
    await openDialog(tester, (context) async {
      result = await showTaskTime(
        context,
        initialTime: const TimeOfDay(hour: 8, minute: 25),
      );
    });
    final wheels =
        tester
            .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
            .toList();
    final selectTime = find.text('Сохранить');
    expect(tester.getSize(dialogPanel('Сохранить')), const Size(256, 300));
    expect(
      tester.getTopLeft(selectTime).dy,
      greaterThan(
        tester.getBottomRight(find.byType(ListWheelScrollView).first).dy,
      ),
    );
    (wheels[0].controller! as FixedExtentScrollController).jumpToItem(18);
    (wheels[1].controller! as FixedExtentScrollController).jumpToItem(53);
    await tester.pumpAndSettle();
    await tester.tap(selectTime);
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 18, minute: 53));
  });

  testWidgets('calendar chooses a cross-month range in reverse', (
    tester,
  ) async {
    DateTimeRange? result;
    await openDialog(tester, (context) async {
      result = await showTaskCalendar(
        context,
        isRange: true,
        startDate: DateTime(2025, 8, 20),
        endDate: DateTime(2025, 8, 26),
      );
    });
    expect(find.text('Август 2025'), findsOneWidget);
    expect(find.text('20 - 26'), findsOneWidget);
    expect(find.text('Скрыть'), findsOneWidget);
    expect(tester.getSize(dialogPanel('Август 2025')), const Size(343, 354));
    await tester.tap(find.bySemanticsLabel('Следующий месяц'));
    await tester.pumpAndSettle();
    expect(find.text('Сентябрь 2025'), findsOneWidget);
    await tester.tap(find.text('9'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Предыдущий месяц'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    expect(find.text('25.08 - 9.09'), findsOneWidget);
    await tester.tap(find.text('Выбрать'));
    await tester.pumpAndSettle();
    expect(result!.start, DateTime(2025, 8, 25));
    expect(result!.end, DateTime(2025, 9, 9));
  });

  testWidgets(
    'calendar hides without selecting and fits long dates on a narrow screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var closed = false;
      await openDialog(tester, (context) async {
        final result = await showTaskCalendar(
          context,
          isRange: true,
          startDate: DateTime(2025, 9, 26),
          endDate: DateTime(2025, 10, 2),
        );
        expect(result, isNull);
        closed = true;
      }, textScale: 1.8);
      expect(find.text('Сентябрь 2025'), findsOneWidget);
      expect(find.text('26.09 - 2.10'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Скрыть'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    },
  );
}
