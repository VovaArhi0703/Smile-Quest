import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Android emulator default. Set EXERCISE_WS_URL for a device or deployment.
const exerciseWebSocketUrl = String.fromEnvironment(
  'EXERCISE_WS_URL',
  defaultValue: 'ws://10.0.2.2:8000/ws',
);

/// Opens only the seven camera exercises without Supabase in a debug build.
const localExerciseTestMode =
    !kReleaseMode && bool.fromEnvironment('LOCAL_EXERCISE_TEST');

final Expando<Future<void>> _readyToSend = Expando<Future<void>>();

WebSocketChannel connectExerciseSocket(BuildContext context) {
  final uri = Uri.parse(exerciseWebSocketUrl);
  if (kReleaseMode && uri.scheme != 'wss') {
    throw StateError('EXERCISE_WS_URL must use wss:// in release builds');
  }

  final channel = WebSocketChannel.connect(uri);
  final ready = channel.ready.then((_) {
    if (!localExerciseTestMode) {
      final token = AppApi.instance.accessToken;
      if (token != null) {
        channel.sink.add(jsonEncode({'mode': 'auth', 'token': token}));
      }
    }
  });
  _readyToSend[channel] = ready;
  // Register an error handler immediately; sendInit may be tapped later.
  unawaited(ready.then<void>((_) {}, onError: (Object error) {
    if (context.mounted) showExerciseSocketConnectionError(context);
  }));
  return channel;
}

Future<bool> waitExerciseSocket(WebSocketChannel channel) async {
  try {
    await (_readyToSend[channel] ?? channel.ready);
    return true;
  } catch (_) {
    return false;
  }
}

void showExerciseSocketConnectionError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Нет соединения с сервером упражнений')),
  );
}

bool showExerciseSocketError(BuildContext context, dynamic message) {
  if (message is! Map || message['error'] == null) return false;
  final code = message['error'];
  final errorText = switch (code) {
    'unauthorized' => 'Войдите в аккаунт, чтобы выполнять упражнения',
    'baseline_required' => 'Сначала выполните калибровку',
    'unknown_exercise' => 'Это упражнение пока недоступно',
    'invalid_frame' => 'Не удалось распознать лицо. Проверьте освещение и положение камеры',
    _ => 'Ошибка сервера упражнений. Попробуйте ещё раз',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText)));
  return true;
}
