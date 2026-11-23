import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'achievement_service.dart';
import 'api_client.dart';
import 'game_scripts.dart';
import 'photo_compress.dart';
import 'photo_service.dart';

class PhotoUploadService {
  static Future<String> uploadPhoto(
    BuildContext context,
    Uint8List imageBytes,
    String section,
    String exercise,
  ) async {
    final userId = AppApi.instance.currentUser?.id;
    if (userId == null) throw Exception('Пользователь не авторизован');
    final compressed = await compressPhoto(
      imageBytes,
      minWidth: 1200,
      minHeight: 1200,
      quality: 80,
    );
    final result = await AppApi.instance.uploadPhoto(
      compressed,
      section,
      exercise,
    );
    photoChangeRevision.value++;
    if (context.mounted) {
      try {
        await GamificationService().applyPhotoReward(context);
        if (context.mounted) {
          await AchievementService().checkAndAwardAchievements(context, userId);
        }
      } catch (_) {
        // The photo was saved; a temporary rewards refresh failure must not
        // encourage the user to upload it a second time.
      }
    }
    return result['id'] as String;
  }
}
