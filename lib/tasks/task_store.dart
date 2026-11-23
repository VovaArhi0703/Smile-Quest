import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum TaskKind { simple, period, deadline }

class TaskRepeat {
  const TaskRepeat({
    this.days = const {},
    this.daysOff = const {},
    this.exerciseReminders = false,
    this.intervalHours = 3,
    this.sets = 2,
  });

  /// ISO weekdays, with Monday represented by DateTime.monday (1).
  final Set<int> days;
  final Set<int> daysOff;
  final bool exerciseReminders;
  final int intervalHours;
  final int sets;

  Map<String, Object> _toJson() => {
    'days': days.toList()..sort(),
    'daysOff': daysOff.toList()..sort(),
    'exerciseReminders': exerciseReminders,
    'intervalHours': intervalHours,
    'sets': sets,
  };

  static TaskRepeat _fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return const TaskRepeat();
    return TaskRepeat(
      days: _weekdays(value['days']),
      daysOff: _weekdays(value['daysOff']),
      exerciseReminders: value['exerciseReminders'] == true,
      intervalHours: _positiveInt(value['intervalHours']) ?? 3,
      sets: _positiveInt(value['sets']) ?? 2,
    );
  }

  static Set<int> _weekdays(Object? value) {
    if (value is! List) return const {};
    return Set.unmodifiable(
      value.whereType<int>().where(
        (day) => day >= DateTime.monday && day <= DateTime.sunday,
      ),
    );
  }

  static int? _positiveInt(Object? value) =>
      value is int && value > 0 ? value : null;
}

class SmileTask {
  const SmileTask({
    required this.id,
    required this.kind,
    required this.title,
    this.sectionRoute = '',
    this.exerciseRoute = '',
    this.comment = '',
    this.startDate,
    this.endDate,
    this.hour,
    this.minute,
    this.repeat = const TaskRepeat(),
    this.completed = false,
  });

  final String id;
  final TaskKind kind;
  final String title;
  final String sectionRoute;
  final String exerciseRoute;
  final String comment;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? hour;
  final int? minute;
  final TaskRepeat repeat;
  final bool completed;

  SmileTask withCompleted(bool value) => SmileTask(
    id: id,
    kind: kind,
    title: title,
    sectionRoute: sectionRoute,
    exerciseRoute: exerciseRoute,
    comment: comment,
    startDate: startDate,
    endDate: endDate,
    hour: hour,
    minute: minute,
    repeat: repeat,
    completed: value,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'sectionRoute': sectionRoute,
    'exerciseRoute': exerciseRoute,
    'comment': comment,
    'startDate': _writeDate(startDate),
    'endDate': _writeDate(endDate),
    'hour': hour,
    'minute': minute,
    'repeat': repeat._toJson(),
    'completed': completed,
  };

  static SmileTask? tryFromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['id'];
    final title = value['title'];
    final kind = TaskKind.values.where((kind) => kind.name == value['kind']);
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        kind.isEmpty) {
      return null;
    }
    return SmileTask(
      id: id,
      kind: kind.first,
      title: title,
      sectionRoute: _text(value['sectionRoute']),
      exerciseRoute: _text(value['exerciseRoute']),
      comment: _text(value['comment']),
      startDate: _readDate(value['startDate']),
      endDate: _readDate(value['endDate']),
      hour: _timePart(value['hour'], 23),
      minute: _timePart(value['minute'], 59),
      repeat: TaskRepeat._fromJson(value['repeat']),
      completed: value['completed'] == true,
    );
  }

  static String _text(Object? value) => value is String ? value : '';

  static int? _timePart(Object? value, int max) =>
      value is int && value >= 0 && value <= max ? value : null;

  static String? _writeDate(DateTime? value) =>
      value == null
          ? null
          : DateTime(
            value.year,
            value.month,
            value.day,
          ).toIso8601String().split('T').first;

  static DateTime? _readDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

abstract interface class TaskSyncApi {
  Future<List<SmileTask>> fetch();

  Future<List<SmileTask>> sync({
    required Iterable<SmileTask> imports,
    required Iterable<SmileTask> upserts,
    required Iterable<String> deletes,
  });
}

/// A local task cache with a durable queue of unacknowledged account edits.
class TaskStore {
  TaskStore({required String? accountId, TaskSyncApi? remote})
    : _remote = accountId == null ? null : remote,
      _queueChanges = accountId != null,
      _key =
          accountId == null
              ? 'smile_quest.tasks.v1.guest'
              : 'smile_quest.tasks.v1.account.${Uri.encodeComponent(accountId)}';

  static final _transactions = <String, Future<void>>{};
  static final _syncs = <String, Future<void>>{};

  final String _key;
  final TaskSyncApi? _remote;
  final bool _queueChanges;

  bool get canSync => _remote != null;

  Future<List<SmileTask>> load() => _transaction(
    (preferences) async => _read(preferences).tasks.values.toList(),
  );

  Future<void> save(List<SmileTask> tasks) => _transaction((preferences) async {
    final state = _read(preferences);
    final updated = {for (final task in tasks) task.id: task};
    for (final id in state.tasks.keys.toList()) {
      if (!updated.containsKey(id)) state.remove(id, sync: _queueChanges);
    }
    for (final task in updated.values) {
      if (!_sameTask(state.tasks[task.id], task)) {
        state.upsert(task, sync: _queueChanges);
      }
    }
    state.tasks
      ..clear()
      ..addAll(updated);
    await _write(preferences, state);
  });

  Future<List<SmileTask>> upsert(SmileTask task) =>
      _change((state) => state.upsert(task, sync: _queueChanges));

  Future<List<SmileTask>> delete(String id) =>
      _change((state) => state.remove(id, sync: _queueChanges));

  Future<List<SmileTask>> _change(void Function(_TaskState) change) =>
      _transaction((preferences) async {
        final state = _read(preferences);
        change(state);
        await _write(preferences, state);
        return state.tasks.values.toList();
      });

  Future<void> sync() async {
    final remote = _remote;
    if (remote == null) return;
    await _syncs.putIfAbsent(_key, () async {
      try {
        await _sync(remote);
      } finally {
        _syncs.remove(_key);
      }
    });
  }

  Future<void> _sync(TaskSyncApi remote) async {
    var remaining = await _transaction(
      (preferences) async => _read(preferences),
    );
    do {
      final imports = {
        for (final id in remaining.imports.take(200)) id: remaining.tasks[id]!,
      };
      final edits = Map.fromEntries(
        remaining.edits.entries.where((entry) => entry.value != null).take(200),
      );
      final deletes =
          remaining.edits.entries
              .where((entry) => entry.value == null)
              .take(200)
              .map((entry) => entry.key)
              .toSet();
      final tasks =
          imports.isEmpty && edits.isEmpty && deletes.isEmpty
              ? await remote.fetch()
              : await remote.sync(
                imports: imports.values,
                upserts: edits.values.whereType<SmileTask>(),
                deletes: deletes,
              );
      remaining = await _transaction((preferences) async {
        final latest = _read(preferences);
        latest.imports.removeAll(imports.keys);
        for (final entry in edits.entries) {
          if (_sameTask(latest.edits[entry.key], entry.value)) {
            latest.edits.remove(entry.key);
          }
        }
        for (final id in deletes) {
          if (latest.edits[id] == null) latest.edits.remove(id);
        }
        final merged = {for (final task in tasks) task.id: task};
        for (final id in latest.imports) {
          merged.putIfAbsent(id, () => latest.tasks[id]!);
        }
        for (final entry in latest.edits.entries) {
          final task = entry.value;
          if (task == null) {
            merged.remove(entry.key);
          } else {
            merged[entry.key] = task;
          }
        }
        latest.tasks
          ..clear()
          ..addAll(merged);
        await _write(preferences, latest);
        return latest;
      });
    } while (remaining.imports.isNotEmpty || remaining.edits.isNotEmpty);
  }

  Future<T> _transaction<T>(
    Future<T> Function(SharedPreferences preferences) operation,
  ) async {
    final previous = _transactions[_key] ?? Future<void>.value();
    final result = previous.then(
      (_) async => operation(await SharedPreferences.getInstance()),
    );
    final finished = result.then<void>((_) {}, onError: (_, _) {});
    _transactions[_key] = finished;
    try {
      return await result;
    } finally {
      if (identical(_transactions[_key], finished)) {
        _transactions.remove(_key);
      }
    }
  }

  _TaskState _read(SharedPreferences preferences) {
    final stored = preferences.getString(_key);
    if (stored != null) {
      try {
        final decoded = jsonDecode(stored);
        if (decoded is List) {
          final tasks = _TaskState.readTasks(decoded);
          return _TaskState(
            tasks: tasks,
            imports: _queueChanges ? tasks.keys.toSet() : {},
          );
        }
        if (decoded is Map<String, dynamic>) {
          return _TaskState.fromJson(decoded);
        }
      } on FormatException {
        // Discard an unreadable cache and continue from the next server fetch.
      }
    }
    return _TaskState();
  }

  Future<void> _write(SharedPreferences preferences, _TaskState state) async {
    final data = jsonEncode(state.toJson());
    try {
      if (await preferences.setString(_key, data)) return;
      throw StateError('Не удалось сохранить задачи.');
    } catch (_) {
      await preferences.reload();
      rethrow;
    }
  }
}

bool _sameTask(SmileTask? a, SmileTask? b) =>
    jsonEncode(a?.toJson()) == jsonEncode(b?.toJson());

class _TaskState {
  _TaskState({
    Map<String, SmileTask>? tasks,
    Set<String>? imports,
    Map<String, SmileTask?>? edits,
  }) : tasks = tasks ?? {},
       imports = imports ?? {},
       edits = edits ?? {};

  factory _TaskState.fromJson(Map<String, dynamic> data) {
    final tasks = readTasks(data['tasks']);
    final imports = data['imports'];
    final edits = data['edits'];
    return _TaskState(
      tasks: tasks,
      imports:
          imports is List
              ? imports.whereType<String>().where(tasks.containsKey).toSet()
              : {},
      edits: {
        if (edits is Map<String, dynamic>)
          for (final entry in edits.entries)
            if (entry.value == null || tasks.containsKey(entry.key))
              entry.key: entry.value == null ? null : tasks[entry.key],
      },
    );
  }

  final Map<String, SmileTask> tasks;
  final Set<String> imports;
  final Map<String, SmileTask?> edits;

  void upsert(SmileTask task, {required bool sync}) {
    tasks[task.id] = task;
    if (sync) {
      imports.remove(task.id);
      edits[task.id] = task;
    }
  }

  void remove(String id, {required bool sync}) {
    tasks.remove(id);
    imports.remove(id);
    if (sync) edits[id] = null;
  }

  Map<String, Object> toJson() => {
    'tasks': [for (final task in tasks.values) task.toJson()],
    'imports': imports.toList(),
    'edits': {
      for (final entry in edits.entries)
        entry.key: entry.value != null ? true : null,
    },
  };

  static Map<String, SmileTask> readTasks(Object? value) => {
    if (value is List)
      for (final record in value)
        if (SmileTask.tryFromJson(record) case final task?) task.id: task,
  };
}
