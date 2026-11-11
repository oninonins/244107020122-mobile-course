import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures.dart';
import '../../data/repositories/mock_announcement_repository.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../../domain/usecases/get_announcement.dart';
import '../../domain/usecases/search_announcements.dart';

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

final searchAnnouncementsProvider = Provider<SearchAnnouncements>((ref) {
  return SearchAnnouncements(ref.watch(announcementRepositoryProvider));
});

/// Kata kunci yang sedang diketik pengguna.
///
/// Dipisah dari hasil pencarian supaya kolom teks bisa menampilkan isinya
/// segera, sementara daftar hasil dihitung ulang di belakang.
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;

  void clear() => state = '';
}

/// Hasil pencarian. Membaca kata kunci lalu memanggil use case.
///
/// Halaman hanya membaca provider ini, jadi ia tidak tahu apakah hasilnya
/// disaring di memori atau di basis data.
final searchResultsProvider =
    FutureProvider<({List<Announcement> announcements, Failure? failure})>((
      ref,
    ) {
      final query = ref.watch(searchQueryProvider);
      return ref.watch(searchAnnouncementsProvider).call(query);
    });
