import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled2/main.dart';
import 'package:untitled2/tasks/task_page.dart';
import 'package:untitled2/tasks/task_store.dart';

void main() {
  const accountId = 'tasks-flow-test';
  setUpAll(() => initializeDateFormatting('ru_RU'));

  testWidgets(
    'opens the task categories and saves a selected exercise as a task',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MyApp());
      navigatorKey.currentState!.pushNamed('/tasks');
      await tester.pumpAndSettle();
      expect(find.byType(TasksPage), findsOneWidget);
      expect(find.textContaining(RegExp(r'пока нет\s+задач')), findsOneWidget);

      await tester.tap(find.text('Создать задачу').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Выбери категорию задачи'), findsOneWidget);
      final dayTask = find.textContaining(RegExp(r'Задача\s+на день'));
      expect(dayTask, findsOneWidget);
      expect(
        find.textContaining(RegExp(r'Задача с\s+периодом')),
        findsOneWidget,
      );

      await tester.tap(dayTask);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выбрать упражнение'));
      await tester.pumpAndSettle();
      expect(find.text('Введите текст'), findsOneWidget);
      expect(find.text('Сбросить'), findsOneWidget);
      final picker = find.byType(BottomSheet);
      expect(tester.getSize(picker).height, 542);
      final search = find.descendant(
        of: picker,
        matching: find.byType(TextField),
      );
      await tester.enterText(search, 'артикуляция');
      await tester.pump();
      expect(find.text('Артикуляция «У–О–А–И» 2.0'), findsNothing);

      const exercise = 'Надуть обе щеки';
      await tester.enterText(search, 'надуть обе');
      await tester.pump();
      expect(find.text(exercise), findsOneWidget);
      await tester.tap(find.text('Сбросить'));
      await tester.pumpAndSettle();
      expect(find.text(exercise), findsNothing);

      final cheeks = find.text('Упражнения для щёк');
      await tester.ensureVisible(cheeks);
      await tester.tap(cheeks);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(exercise));
      await tester.tap(find.text(exercise));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text(exercise), findsOneWidget);
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();

      final saved = (await TaskStore(accountId: null).load()).single;
      expect(saved.kind, TaskKind.simple);
      expect(saved.title, exercise);
      expect(saved.sectionRoute, '/cheeks_exercises');
      expect(saved.exerciseRoute, '/cheeks_1');
      expect(find.text(exercise), findsOneWidget);
    },
  );

  testWidgets('completion persists and moves the task to Выполненные', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = TaskStore(accountId: accountId);
    const exercise = 'Движение челюстью вправо и влево 2.0';
    await store.save([
      const SmileTask(
        id: 'complete-me',
        kind: TaskKind.simple,
        title: exercise,
        sectionRoute: '/jaw_exercises',
        exerciseRoute: '/jaw_2',
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(home: TasksPage(accountId: accountId)),
    );
    await tester.pumpAndSettle();
    expect(find.text(exercise), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('task-complete-complete-me')));
    await tester.pumpAndSettle();
    expect(find.text(exercise), findsNothing);
    expect((await store.load()).single.completed, isTrue);

    await tester.tap(find.text('Выполненные'));
    await tester.pumpAndSettle();
    expect(find.text(exercise), findsOneWidget);
  });

  testWidgets(
    'editing a saved task preserves its retired exercise and schedule',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = TaskStore(accountId: accountId);
      await store.save([
        SmileTask(
          id: 'period-task',
          kind: TaskKind.period,
          title: 'Тренировка на неделю',
          sectionRoute: '/lips_exercises',
          exerciseRoute: '/lips_12',
          comment: 'Начать в понедельник',
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 8),
          hour: 14,
          minute: 30,
          repeat: const TaskRepeat(days: {DateTime.monday, DateTime.thursday}),
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: TasksPage(accountId: accountId)),
      );
      await tester.pumpAndSettle();
      expect(find.text('01.10-08.10'), findsOneWidget);
      await tester.tap(find.text('Тренировка на неделю'));
      await tester.pumpAndSettle();
      expect(find.text('14:30'), findsOneWidget);
      expect(find.text('Пн, Чт'), findsOneWidget);
      expect(find.text('Артикуляция «У–О–А–И» 2.0'), findsWidgets);

      await tester.tap(find.bySemanticsLabel('Редактировать задачу'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Новый план');
      await tester.tap(find.text('Добавить').hitTestable().last);
      await tester.pumpAndSettle();

      final saved = (await store.load()).single;
      expect(saved.title, 'Тренировка на неделю');
      expect(saved.sectionRoute, '/lips_exercises');
      expect(saved.exerciseRoute, '/lips_12');
      expect(saved.comment, 'Новый план');
      expect(saved.startDate, DateTime(2026, 10, 1));
      expect(saved.endDate, DateTime(2026, 10, 8));
      expect(saved.hour, 14);
      expect(saved.minute, 30);
      expect(saved.repeat.days, {DateTime.monday, DateTime.thursday});
      expect(find.text('Тренировка на неделю'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
