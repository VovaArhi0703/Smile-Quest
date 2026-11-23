import 'package:flutter/material.dart';

import 'api_client.dart';
import 'achievement_popup.dart';

class AchievementService {
  Future<List<String>> getUnlockedAchievements() async {
    if (!AppApi.instance.isSignedIn) return [];
    final response = await AppApi.instance.get('/achievements');
    return List<String>.from(response['ids'] as List);
  }

  Future<void> checkAndAwardAchievements(BuildContext context, String userId) async {
    if (AppApi.instance.currentUser?.id != userId) return;
    final response = await AppApi.instance.post('/achievements/check', {});
    if (!context.mounted) return;
    const info = {
      'novice': ('Новичок', 'Вы заходили в приложение 3 раза!', 'assets/image/novice.png', 100),
      'photographer': ('Фотограф', 'Вы загрузили 5 фотографий!', 'assets/image/photographer.png', 150),
      'master': ('Мастер упражнений', 'Вы достигли 5 уровня!', 'assets/image/master.png', 200),
    };
    for (final id in response['new'] as List) {
      final item = info[id];
      if (item == null || !context.mounted) continue;
      showDialog(
        context: context,
        builder: (_) => AchievementPopup(
          title: item.$1,
          description: item.$2,
          imagePath: item.$3,
          coins: item.$4,
        ),
      );
    }
  }
}
