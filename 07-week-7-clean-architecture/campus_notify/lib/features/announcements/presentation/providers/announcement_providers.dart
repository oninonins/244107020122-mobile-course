import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures.dart';
import '../../data/repositories/mock_announcement_repository.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../../domain/usecases/get_announcement.dart';

/// Source data pengumuman. Ditaruh di provider supaya test bisa menimpanya
/// dengan fake tanpa menyentuh data layer.
final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return MockAnnouncementRepository();
});

/// Use case menerima abstraksi, bukan implementasi.
final getAnnouncementProvider = Provider<GetAnnouncement>((ref) {
  return GetAnnouncement(ref.watch(announcementRepositoryProvider));
});

/// State untuk UI. Halaman hanya membaca ini; ia tidak tahu dari mana pengumuman
/// datang.
///
/// Kegagalan diteruskan sebagai `Failure`, bukan dilempar, jadi halaman cukup
/// membaca `failure.message` tanpa memeriksa tipe apa pun.
final announcementProvider =
    FutureProvider.family<
      ({Announcement? announcement, Failure? failure}),
      String
    >((ref, id) {
      return ref.watch(getAnnouncementProvider).call(id);
    });
