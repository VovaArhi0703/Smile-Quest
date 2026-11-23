import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled2/tasks/task_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the whole task and its recurrence survive a reload', () async {
    final store = TaskStore(accountId: 'owner');
    final original = SmileTask(
      id: 'task-1',
      kind: TaskKind.period,
      title: 'Тренировка губ',
      sectionRoute: '/lips_exercises',
      exerciseRoute: '/lips_1',
      comment: 'После завтрака',
      startDate: DateTime(2026, 11, 20),
      endDate: DateTime(2026, 11, 28),
      hour: 9,
      minute: 30,
      repeat: const TaskRepeat(
        days: {DateTime.monday, DateTime.friday},
        daysOff: {DateTime.sunday},
        exerciseReminders: true,
        intervalHours: 4,
        sets: 3,
      ),
    );
    await store.save([original.withCompleted(true)]);

    final stored = (await TaskStore(accountId: 'owner').load()).single;
    expect(stored.id, original.id);
    expect(stored.kind, original.kind);
    expect(stored.title, original.title);
    expect(stored.sectionRoute, original.sectionRoute);
    expect(stored.exerciseRoute, original.exerciseRoute);
    expect(stored.comment, original.comment);
    expect(stored.startDate, original.startDate);
    expect(stored.endDate, original.endDate);
    expect(stored.hour, original.hour);
    expect(stored.minute, original.minute);
    expect(stored.repeat.days, original.repeat.days);
    expect(stored.repeat.daysOff, original.repeat.daysOff);
    expect(stored.repeat.exerciseReminders, isTrue);
    expect(stored.repeat.intervalHours, 4);
    expect(stored.repeat.sets, 3);
    expect(stored.completed, isTrue);
    expect(original.completed, isFalse);
  });

  test('each account and the guest have separate task lists', () async {
    const guestTask = SmileTask(
      id: 'guest',
      kind: TaskKind.simple,
      title: 'Задача гостя',
    );
    const userTask = SmileTask(
      id: 'user',
      kind: TaskKind.deadline,
      title: 'Задача пользователя',
    );
    final guest = TaskStore(accountId: null);
    final account = TaskStore(accountId: 'guest');
    await guest.save([guestTask]);
    await account.save([userTask]);

    expect((await guest.load()).single.id, 'guest');
    final stored = (await account.load()).single;
    expect(stored.id, 'user');
    expect(stored.startDate, isNull);
    expect(stored.endDate, isNull);
    expect(stored.repeat.intervalHours, 3);
    expect(stored.repeat.sets, 2);
    expect(await TaskStore(accountId: 'other-account').load(), isEmpty);
  });

  test('an invalid record does not prevent other tasks from loading', () async {
    SharedPreferences.setMockInitialValues({
      'smile_quest.tasks.v1.guest':
          '[null,{"kind":"unknown","title":"Ошибка","id":"x"},'
          '{"kind":"simple","title":"Улыбка","id":"y",'
          '"repeat":{"days":[0,1,8,1],"intervalHours":0}}]',
    });
    final stored = (await TaskStore(accountId: null).load()).single;
    expect(stored.id, 'y');
    expect(stored.repeat.days, {DateTime.monday});
    expect(stored.repeat.intervalHours, 3);
  });

  test('imports older tasks without overriding existing cloud tasks', () async {
    final legacy = [
      _task('same', 'Старый заголовок'),
      _task('new', 'Задача с телефона'),
      _task('deleted', 'Удалённая на другом устройстве'),
    ];
    SharedPreferences.setMockInitialValues({
      'smile_quest.tasks.v1.account.owner': jsonEncode(
        legacy.map((task) => task.toJson()).toList(),
      ),
    });
    final server =
        _TaskServer()
          ..tasks['same'] = _task('same', 'Название с другого телефона')
          ..tasks['cloud'] = _task('cloud', 'Задача из облака')
          ..tombstones.add('deleted');
    final store = TaskStore(accountId: 'owner', remote: server);

    await store.sync();
    expect((await store.load()).map((task) => task.title), [
      'Название с другого телефона',
      'Задача из облака',
      'Задача с телефона',
    ]);

    await TaskStore(accountId: 'owner', remote: server).sync();
    expect(server.importBatches, 1);
  });

  test('an offline deletion survives retry and intervening edits', () async {
    final edit = _task('edit', 'Сохранить правку');
    final server =
        _TaskServer()
          ..tasks['remove'] = _task('remove', 'Удалить задачу')
          ..tasks['edit'] = edit;
    final store = TaskStore(accountId: 'owner', remote: server);
    await store.sync();

    await store.delete('remove');
    server.failAfterCommit = true;
    await expectLater(store.sync(), throwsStateError);
    expect((await store.load()).single.id, 'edit');
    expect(server.tombstones, {'remove'});

    final reopened = TaskStore(accountId: 'owner', remote: server);
    final firstResponse = Completer<void>();
    final firstRequest = Completer<void>();
    server.beforeResponse = () async {
      firstRequest.complete();
      await firstResponse.future;
    };
    final syncing = reopened.sync();
    await firstRequest.future;
    await reopened.upsert(edit.withCompleted(true));
    firstResponse.complete();
    await syncing;

    expect((await reopened.load()).single.completed, isTrue);
    expect(server.tasks.keys, ['edit']);
    expect(server.tasks['edit']?.completed, isTrue);
    expect(server.deletionBatches, 2);
  });
}

SmileTask _task(String id, String title) =>
    SmileTask(id: id, title: title, kind: TaskKind.simple);

class _TaskServer implements TaskSyncApi {
  final tasks = <String, SmileTask>{};
  final tombstones = <String>{};
  Future<void> Function()? beforeResponse;
  bool failAfterCommit = false;
  int importBatches = 0;
  int deletionBatches = 0;

  @override
  Future<List<SmileTask>> fetch() async => tasks.values.toList();

  @override
  Future<List<SmileTask>> sync({
    required Iterable<SmileTask> imports,
    required Iterable<SmileTask> upserts,
    required Iterable<String> deletes,
  }) async {
    if (imports.isNotEmpty) importBatches++;
    if (deletes.isNotEmpty) deletionBatches++;
    for (final task in imports) {
      if (!tombstones.contains(task.id)) tasks.putIfAbsent(task.id, () => task);
    }
    for (final task in upserts) {
      if (!tombstones.contains(task.id)) tasks[task.id] = task;
    }
    for (final id in deletes) {
      tombstones.add(id);
      tasks.remove(id);
    }
    final result = tasks.values.toList();
    if (failAfterCommit) {
      failAfterCommit = false;
      throw StateError('Connection lost');
    }
    final wait = beforeResponse;
    beforeResponse = null;
    await wait?.call();
    return result;
  }
}
