import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

class ApiUser {
  const ApiUser(this.id, this.email);
  final String id;
  final String email;
}

class AppApi {
  AppApi._();
  static final AppApi instance = AppApi._();
  static const _storage = FlutterSecureStorage();
  final _client = http.Client();
  String? _token;
  ApiUser? currentUser;
  String? get accessToken => _token;
  bool get isSignedIn => _token != null && currentUser != null;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$dataApiUrl$path').replace(queryParameters: query);

  Future<void> restore() async {
    if (kReleaseMode && Uri.parse(dataApiUrl).scheme != 'https') {
      throw StateError('DATA_API_URL must use HTTPS in release builds');
    }
    _token = await _storage.read(key: 'api_session');
    if (_token == null) return;
    try {
      final user = await get('/auth/me');
      currentUser = ApiUser(user['id'] as String, user['email'] as String);
    } on ApiException catch (e) {
      if (e.statusCode == 401) await signOut();
    } catch (_) {
      // Keep the session for a later attempt when the API is reachable.
    }
  }

  Future<void> _setSession(Map<String, dynamic> data) async {
    final user = Map<String, dynamic>.from(data['user'] as Map);
    _token = data['token'] as String;
    currentUser = ApiUser(user['id'] as String, user['email'] as String);
    await _storage.write(key: 'api_session', value: _token);
  }

  Future<void> signUp(String email, String password, String fullName) async {
    await _setSession(await post('/auth/signup', {
      'email': email,
      'password': password,
      'full_name': fullName,
    }));
  }

  Future<void> signIn(String email, String password) async {
    await _setSession(await post('/auth/login', {
      'email': email,
      'password': password,
    }));
  }

  Future<void> signOut() async {
    if (_token != null) {
      try {
        await post('/auth/logout', {});
      } catch (_) {}
    }
    _token = null;
    currentUser = null;
    await _storage.delete(key: 'api_session');
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body: body);
  Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _send('PATCH', path, body: body);

  Future<dynamic> uploadPhoto(
      Uint8List bytes, String section, String exercise) =>
      _send('POST', '/photos', query: {
        'section': section,
        'exercise': exercise,
      }, bytes: bytes);

  Future<dynamic> _send(String method, String path,
      {Map<String, String>? query, Map<String, dynamic>? body, Uint8List? bytes}) async {
    final request = http.Request(method, _uri(path, query));
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.headers['X-Timezone-Offset'] =
        DateTime.now().timeZoneOffset.inMinutes.toString();
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    } else if (bytes != null) {
      request.headers['Content-Type'] = 'image/jpeg';
      request.bodyBytes = bytes;
    }
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 20)),
    );
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw ApiException(detail is String ? detail : 'Ошибка сервера (${response.statusCode})', response.statusCode);
    }
    return decoded;
  }
}
