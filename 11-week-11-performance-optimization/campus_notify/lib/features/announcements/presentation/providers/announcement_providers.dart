import 'dart:async';

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

/// Jeda sebelum kata kunci dipakai untuk menyaring.
///
/// Dibuat provider supaya test bisa menggantinya menjadi 10 ms tanpa membuat
/// seluruh suite menunggu 300 ms per kasus.
final debounceDurationProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 300),
);

/// Kata kunci yang sudah melewati jeda [debounceDurationProvider].
///
/// **Kenapa perlu.** Tanpa ini, mengetik "jadwal" berarti lima kali menyaring
/// dan lima kali rebuild daftar. Dengan jeda, hanya nilai terakhir yang
/// diteruskan, sehingga penyaringan terjadi sekali.
///
/// Nilai kosong diteruskan seketika, bukan ditunda, supaya tombol hapus terasa
/// langsung dan daftar penuh kembali tanpa jeda.
final debouncedQueryProvider = NotifierProvider<DebouncedQueryNotifier, String>(
  DebouncedQueryNotifier.new,
);

class DebouncedQueryNotifier extends Notifier<String> {
  Timer? _timer;

  @override
  String build() {
    final duration = ref.watch(debounceDurationProvider);

    ref.onDispose(() => _timer?.cancel());

    ref.listen<String>(searchQueryProvider, (previous, next) {
      _timer?.cancel();

      if (next.trim().isEmpty) {
        state = '';
        return;
      }

      _timer = Timer(duration, () => state = next);
    });

    return ref.read(searchQueryProvider);
  }
}

/// Hasil pencarian. Membaca kata kunci lalu memanggil use case.
///
/// Halaman hanya membaca provider ini, jadi ia tidak tahu apakah hasilnya
/// disaring di memori atau di basis data.
///
/// **Diubah pada Week 11.** Versi sebelumnya memanggil
/// `SearchAnnouncements.call(query)` di sini, dan use case itu memanggil
/// `fetchAll()` setiap kali. Karena provider ini menonton kata kunci, setiap
/// ketikan memicu pengambilan ulang seluruh daftar beserta parsing JSON-nya.
///
/// Sekarang daftar diambil sekali oleh [allAnnouncementsProvider], dan provider
/// ini hanya memfilter di memori lewat [SearchAnnouncements.filter] yang murni.
final searchResultsProvider =
    FutureProvider<({List<Announcement> announcements, Failure? failure})>((
      ref,
    ) async {
      final query = ref.watch(debouncedQueryProvider);
      final all = await ref.watch(allAnnouncementsProvider.future);

      if (all.failure != null) {
        return (announcements: const <Announcement>[], failure: all.failure);
      }

      return (
        announcements: SearchAnnouncements.filter(all.announcements, query),
        failure: null,
      );
    });

/// Seluruh pengumuman, diambil **sekali**.
///
/// Inilah cache-nya. Selama tidak di-invalidate, provider ini tidak memanggil
/// repository lagi, berapa pun kali kata kunci berubah. `FutureProvider` yang
/// sudah selesai menyimpan hasilnya selama provider itu hidup.
///
/// Invalidate saat data berubah, misalnya setelah menambah pengumuman baru.
final allAnnouncementsProvider =
    FutureProvider<({List<Announcement> announcements, Failure? failure})>((
      ref,
    ) {
      return ref.watch(searchAnnouncementsProvider).fetchAll();
    });
