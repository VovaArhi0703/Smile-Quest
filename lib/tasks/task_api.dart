import '../api_client.dart';
import 'task_store.dart';

class AppTaskSyncApi implements TaskSyncApi {
  AppTaskSyncApi._(this._api, this._accountId);

  static AppTaskSyncApi? forAccount(String? accountId) {
    final api = AppApi.instance;
    return accountId != null &&
            api.isSignedIn &&
            api.currentUser?.id == accountId
        ? AppTaskSyncApi._(api, accountId)
        : null;
  }

  final AppApi _api;
  final String _accountId;

  @override
  Future<List<SmileTask>> fetch() => _send(() => _api.get('/tasks'));

  @override
  Future<List<SmileTask>> sync({
    required Iterable<SmileTask> imports,
    required Iterable<SmileTask> upserts,
    required Iterable<String> deletes,
  }) => _send(
    () => _api.post('/tasks/sync', {
      'imports': [for (final task in imports) task.toJson()],
      'upserts': [for (final task in upserts) task.toJson()],
      'deletes': deletes.toList(),
    }),
  );

  Future<List<SmileTask>> _send(Future<dynamic> Function() request) async {
    final token = _api.accessToken;
    if (token == null || _api.currentUser?.id != _accountId) {
      throw StateError('Сессия пользователя изменилась.');
    }
    final data = await request();
    if (_api.accessToken != token || _api.currentUser?.id != _accountId) {
      throw StateError('Сессия пользователя изменилась.');
    }
    final tasks = data is Map ? data['tasks'] : null;
    if (tasks is! List) {
      throw const FormatException('Некорректный список задач.');
    }
    return [
      for (final record in tasks)
        SmileTask.tryFromJson(record) ??
            (throw const FormatException('Некорректная задача.')),
    ];
  }
}
