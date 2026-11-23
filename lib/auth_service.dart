import 'package:flutter/material.dart';

import 'api_client.dart';
import 'achievement_service.dart';
import 'user_progress_service.dart';

Future<List<int>> getLoginDaysForThisWeek() async {
  if (!AppApi.instance.isSignedIn) return [];
  final data = await AppApi.instance.get('/login-days');
  final now = DateTime.now();
  final monday = DateTime.utc(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  final days = <int>[];
  for (final raw in data['days'] as List) {
    final day = DateTime.tryParse('${raw}T00:00:00Z');
    if (day != null && !day.isBefore(monday) && day.isBefore(monday.add(const Duration(days: 7)))) {
      days.add(day.weekday);
    }
  }
  return days;
}

class AuthService {
  static Future<bool> signUp({
    required BuildContext context,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String middleName,
  }) async {
    try {
      await AppApi.instance.signUp(
        email,
        password,
        '$lastName $firstName $middleName'.trim(),
      );
      await UserProgressService.restoreFromServer();
      return true;
    } on ApiException catch (e) {
      if (context.mounted) _showMessage(context, e.message);
      return false;
    } catch (e) {
      if (context.mounted) _showMessage(context, 'Сервер недоступен: $e');
      return false;
    }
  }

  static Future<void> signInWithEmail({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    try {
      await AppApi.instance.signIn(email, password);
      await UserProgressService.restoreFromServer();
      final userId = AppApi.instance.currentUser?.id;
      if (userId != null && context.mounted) {
        await AchievementService().checkAndAwardAchievements(context, userId);
      }
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    } on ApiException catch (e) {
      if (context.mounted) _showMessage(context, e.message);
    } catch (e) {
      if (context.mounted) _showMessage(context, 'Сервер недоступен: $e');
    }
  }

  static void checkUserSession(BuildContext context) {
    if (AppApi.instance.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pushReplacementNamed(context, '/home');
      });
    }
  }

  static Future<void> updateLoginMetrics() async {
    // The data API records a login atomically when a session is created.
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
