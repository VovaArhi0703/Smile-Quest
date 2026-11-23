import 'package:flutter/material.dart';

import 'api_client.dart';
import 'achievement_service.dart';
import 'auth_service.dart';
import 'profile_service.dart';

class LoginActivity {
  const LoginActivity({
    this.streak = 0,
    this.best = 0,
    this.weekdays = const {},
  });

  final int streak;
  final int best;
  final Set<int> weekdays;

  factory LoginActivity.fromResponse(Map<String, dynamic> data) {
    final streak = data['login_streak'] as int? ?? 0;
    return LoginActivity(
      streak: streak,
      best: data['best_streak'] as int? ?? streak,
      weekdays: Set.unmodifiable(
        (data['weekdays'] as List? ?? const []).whereType<int>().where(
          (day) => day >= DateTime.monday && day <= DateTime.sunday,
        ),
      ),
    );
  }

  static bool isFireLit(int streak) => streak >= 2;
}

class GamificationService {
  static final _loginActivity = ValueNotifier<LoginActivity?>(null);
  static ValueNotifier<LoginActivity?> get loginActivity => _loginActivity;
  static String? _activityAccount;
  static Future<void>? _activityRequest;

  Future<void> refreshLoginActivity() async {
    final account = AppApi.instance.currentUser?.id;
    if (account != _activityAccount) {
      _activityAccount = account;
      _activityRequest = null;
      _loginActivity.value = null;
    }
    if (account == null) {
      _loginActivity.value = const LoginActivity();
      return;
    }
    final request = _activityRequest ??= _fetchLoginActivity(account);
    try {
      await request;
    } finally {
      if (identical(_activityRequest, request)) _activityRequest = null;
    }
  }

  Future<void> _fetchLoginActivity(String account) async {
    LoginActivity activity;
    try {
      activity = await _recordVisit();
    } catch (_) {
      if (AppApi.instance.currentUser?.id == account) {
        _loginActivity.value ??= const LoginActivity();
      }
      return;
    }
    if (AppApi.instance.currentUser?.id == account) {
      _loginActivity.value = activity;
    }
  }

  Future<LoginActivity> _recordVisit() async {
    try {
      final response = await AppApi.instance.post('/activity', {});
      return LoginActivity.fromResponse(Map<String, dynamic>.from(response));
    } on ApiException catch (error) {
      if (error.statusCode != 404 && error.statusCode != 405) rethrow;
      final streak = await getLoginStreak();
      return LoginActivity(
        streak: streak,
        best: streak,
        weekdays: Set.unmodifiable(await getLoginDaysForThisWeek()),
      );
    }
  }

  Future<void> rewardForLogin(BuildContext context) =>
      _award(context, 'login', '+10 XP и +5 монет за авторизацию');

  Future<void> rewardForSignup(BuildContext context) async {
    await _award(context, 'signup', '+40 XP за регистрацию');
    if (await getLoginStreak() >= 5 && context.mounted) {
      await _award(context, 'streak5', '5 дней подряд! +15 XP и +15 монет');
    }
  }

  /// Photo rewards are granted atomically by the upload endpoint.
  Future<void> applyPhotoReward(BuildContext context) async {
    await ProfileService().refreshBalance();
  }

  Future<int> getLoginStreak() async {
    if (!AppApi.instance.isSignedIn) return 0;
    final data = await AppApi.instance.get('/metrics');
    return data['login_streak'] as int? ?? 0;
  }

  Future<void> applyReward(
    BuildContext context, {
    required int xpReward,
    required int coinReward,
    required String message,
  }) async {
    final kind = switch ((xpReward, coinReward)) {
      (10, 5) => 'login',
      (40, 0) => 'signup',
      (15, 15) => 'streak5',
      _ => throw ArgumentError('Награда не поддерживается сервером'),
    };
    await _award(context, kind, message);
  }

  Future<void> _award(BuildContext context, String kind, String message) async {
    if (!AppApi.instance.isSignedIn) return;
    final result = await AppApi.instance.post('/rewards', {'kind': kind});
    if (result['awarded'] != true) return;
    ProfileService.updateBalance(Map<String, dynamic>.from(result));
    final userId = AppApi.instance.currentUser?.id;
    if (userId != null && context.mounted) {
      await AchievementService().checkAndAwardAchievements(context, userId);
      if (context.mounted) _showSnackBar(context, message);
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
