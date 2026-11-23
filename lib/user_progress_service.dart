import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class UserProgressService {
  static const _stringKeys = [
    'last_section_title',
    'last_section_route',
    'last_exercise_title',
    'last_exercise_route',
  ];
  static const _numberKey = 'last_exercise_number';
  static const _openedKey = 'opened_sections';

  static Future<void> restoreFromServer() async {
    if (!AppApi.instance.isSignedIn) return;
    final data = Map<String, dynamic>.from(await AppApi.instance.get('/progress'));
    final prefs = await SharedPreferences.getInstance();
    for (final key in _stringKeys) {
      await prefs.remove(key);
      if (data[key] is String) await prefs.setString(key, data[key] as String);
    }
    await prefs.remove(_numberKey);
    if (data[_numberKey] is int) await prefs.setInt(_numberKey, data[_numberKey] as int);
    await prefs.remove(_openedKey);
    if (data[_openedKey] is List) {
      await prefs.setStringList(_openedKey, List<String>.from(data[_openedKey] as List));
    }
  }

  static Future<void> syncToServer() async {
    if (!AppApi.instance.isSignedIn) return;
    final prefs = await SharedPreferences.getInstance();
    final values = <String, dynamic>{};
    for (final key in _stringKeys) {
      final value = prefs.getString(key);
      if (value != null) values[key] = value;
    }
    final number = prefs.getInt(_numberKey);
    if (number != null) values[_numberKey] = number;
    final opened = prefs.getStringList(_openedKey);
    if (opened != null) values[_openedKey] = opened;
    if (values.isNotEmpty) await AppApi.instance.patch('/progress', {'values': values});
  }
}
