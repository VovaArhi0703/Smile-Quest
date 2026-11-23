import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'photo_view.dart';

final ValueNotifier<int> photoChangeRevision = ValueNotifier(0);

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

Future<List<Map<String, dynamic>>> _loadPhotoRows({
  required DateTime startInclusive,
  required DateTime endExclusive,
  String? section,
  String? exercise,
}) async {
  if (!AppApi.instance.isSignedIn) return [];
  final rows = await AppApi.instance.get('/photos', {
    'start': startInclusive.toUtc().toIso8601String(),
    'end': endExclusive.toUtc().toIso8601String(),
    if (section != null && section.isNotEmpty) 'section': section,
    if (exercise != null && exercise.isNotEmpty) 'exercise': exercise,
  });
  return List<Map<String, dynamic>>.from(
    (rows as List).map((e) => Map<String, dynamic>.from(e as Map)),
  );
}

Future<List<Photo>> fetchPhotosRange({
  required DateTime startInclusive,
  required DateTime endExclusive,
  String? section,
  String? exercise,
}) async {
  final rows = await _loadPhotoRows(
    startInclusive: startInclusive,
    endExclusive: endExclusive,
    section: section,
    exercise: exercise,
  );
  return rows.map(Photo.fromJson).toList();
}

Future<Map<DateTime, int>> fetchMonthDayCounts({
  required DateTime monthAnchor,
  String? section,
  String? exercise,
}) async {
  final start = DateTime(monthAnchor.year, monthAnchor.month, 1);
  final end = DateTime(monthAnchor.year, monthAnchor.month + 1, 1);
  final rows = await _loadPhotoRows(
    startInclusive: start,
    endExclusive: end,
    section: section,
    exercise: exercise,
  );
  final counts = <DateTime, int>{};
  for (final row in rows) {
    final date = DateTime.tryParse(row['date_taken'].toString())?.toLocal();
    if (date == null) continue;
    final day = _startOfDay(date);
    counts[day] = (counts[day] ?? 0) + 1;
  }
  return counts;
}
