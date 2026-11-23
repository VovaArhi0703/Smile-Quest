import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled2/tasks/task_page.dart';
import 'package:untitled2/tasks/task_store.dart';

void main() {
  testWidgets('deletion asks for confirmation and cancellation keeps edits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    const accountId = 'task-delete-test';
    final store = TaskStore(accountId: accountId);
    const title = 'Тестовая задача';
    const comment = 'Исходный комментарий';
    await store.save([
      SmileTask(
        id: 'to-delete',
        kind: TaskKind.simple,
        title: title,
        sectionRoute: '/cheeks_exercises',
        exerciseRoute: '/cheeks_1',
        startDate: DateTime(2026, 11, 20),
        hour: 13,
        minute: 15,
        comment: comment,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
        home: const TasksPage(accountId: accountId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Редактировать задачу'));
    await tester.pumpAndSettle();

    final commentField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text != null,
    );
    expect(tester.widget<TextField>(commentField).controller?.text, comment);
    await tester.ensureVisible(commentField);
    final oneLineHeight = tester.getSize(commentField).height;
    const draft = 'Длинный комментарий к упражнению\nВторая строка комментария';
    await tester.enterText(commentField, draft);
    await tester.pumpAndSettle();
    expect(tester.getSize(commentField).height, greaterThan(oneLineHeight));

    final trash = find.bySemanticsLabel('Удалить задачу');
    await tester.ensureVisible(trash);
    await tester.tap(trash);
    await tester.pumpAndSettle();
    expect(find.text('Удалить задачу?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text(draft), findsOneWidget);
    expect((await store.load()).single.id, 'to-delete');

    await tester.tap(trash);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(await store.load(), isEmpty);
    expect(find.textContaining('пока нет задач'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
