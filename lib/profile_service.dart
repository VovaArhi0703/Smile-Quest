import 'package:flutter/foundation.dart';

import 'api_client.dart';

class ProfileBalance {
  const ProfileBalance(this.coins, this.xp, this.level);

  final int coins;
  final int xp;
  final int level;
}

class UserProfileData {
  final String lastName;
  final String firstName;
  final String middleName;
  final String email;
  final String id;
  final String avatarUrl;
  final String petName;
  final String petAge;
  final int coins;
  final int xp;
  final int level;

  UserProfileData({
    required this.lastName,
    required this.firstName,
    required this.middleName,
    required this.email,
    required this.id,
    required this.avatarUrl,
    this.petName = '',
    this.petAge = '',
    required this.coins,
    required this.xp,
    required this.level,
  });
}

class ProfileService {
  static final ValueNotifier<ProfileBalance?> balance = ValueNotifier(null);

  static void updateBalance(Map<String, dynamic> values) {
    final coins = values['coins'];
    final xp = values['xp'];
    final level = values['level'];
    if (coins is num && xp is num && level is num) {
      balance.value = ProfileBalance(coins.toInt(), xp.toInt(), level.toInt());
    }
  }

  Future<void> refreshBalance() async {
    await fetchUserProfile();
  }

  Future<UserProfileData?> loadProfileWithAvatar() async {
    final profile = await fetchUserProfile();
    if (profile == null) return null;
    final nameParts = (profile['full_name'] ?? '').toString().trim().split(' ');
    return UserProfileData(
      lastName: nameParts.isNotEmpty ? nameParts[0] : '',
      firstName: nameParts.length > 1 ? nameParts[1] : '',
      middleName: nameParts.length > 2 ? nameParts.sublist(2).join(' ') : '',
      email: profile['email'] ?? '',
      id: profile['id'] ?? '',
      avatarUrl: profile['avatar_url'] ?? 'assets/avatars/avatar_1.png',
      petName: profile['pet_name'] ?? '',
      petAge: profile['pet_age'] ?? '',
      coins: profile['coins'] ?? 0,
      xp: profile['xp'] ?? 0,
      level: profile['level'] ?? 1,
    );
  }

  Future<String?> getFirstName() async {
    final profile = await loadProfileWithAvatar();
    return profile?.firstName;
  }

  Future<List?> getStates() async {
    final profile = await loadProfileWithAvatar();
    if (profile == null) return null;
    return [profile.coins, profile.xp, profile.level];
  }

  Future<void> saveProfileData(UserProfileData data) async {
    await AppApi.instance.patch('/profile', {
      'full_name':
          '${data.lastName} ${data.firstName} ${data.middleName}'.trim(),
      'avatar_url': data.avatarUrl,
      'pet_name': data.petName,
      'pet_age': data.petAge,
    });
  }

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    if (!AppApi.instance.isSignedIn) return null;
    final profile = Map<String, dynamic>.from(
      await AppApi.instance.get('/profile'),
    );
    updateBalance(profile);
    return profile;
  }

  Future<void> saveUserProfile({
    required String fullName,
    String? avatarUrl,
    int? coins,
    int? xp,
    int? level,
  }) async {
    if (!AppApi.instance.isSignedIn)
      throw Exception('Пользователь не авторизован');
    await AppApi.instance.patch('/profile', {
      'full_name': fullName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
  }
}
