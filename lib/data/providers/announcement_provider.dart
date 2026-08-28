import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/announcement_model.dart';
import '../repositories/announcement_repository.dart';

final announcementsStreamProvider = StreamProvider<List<AnnouncementModel>>((ref) {
  final repo = ref.watch(announcementRepositoryProvider);
  return repo.streamAnnouncements().map((list) {
    final sortedList = List<Map<String, dynamic>>.from(list);
    sortedList.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
    return sortedList.map((e) => AnnouncementModel.fromJson(e)).toList();
  });
});
