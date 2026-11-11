import 'package:campus_notify/core/failures.dart';
import 'package:campus_notify/features/announcements/domain/entities/announcement.dart';
import 'package:campus_notify/features/announcements/domain/repositories/announcement_repository.dart';
import 'package:campus_notify/features/announcements/presentation/providers/announcement_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository yang menghitung berapa kali `fetchAll` dipanggil.
///
/// Inilah alat ukur optimasi Week 11. Tanpa penghitung, "terasa lebih cepat"
/// tidak bisa dibedakan dari placebo.
class CountingAnnouncementRepository implements AnnouncementRepository {
  CountingAnnouncementRepository({
    this.items = const [],
    this.delay = Duration.zero,
  });

  final List<Announcement> items;
  final Duration delay;
  int fetchAllCalls = 0;

  @override
  Future<({Announcement? announcement, Failure? failure})> fetchById(
    String id,
  ) async {
    final found = items.where((a) => a.id == id).firstOrNull;
    if (found == null) {
      return (announcement: null, failure: const LocalFailure('Tidak ada'));
    }
    return (announcement: found, failure: null);
  }

  @override
  Future<({List<Announcement> announcements, Failure? failure})>
  fetchAll() async {
    fetchAllCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return (announcements: items, failure: null);
  }
}

const _seed = [
  Announcement(
    id: '1',
    title: 'Pendaftaran UTS dibuka',
    body: 'Sampai Jumat, 22.00 WIB.',
  ),
  Announcement(
    id: '2',
    title: 'Perpustakaan tutup',
    body: 'Tutup 28-30 Oktober karena hari libur.',
  ),
  Announcement(
    id: '3',
    title: 'Jadwal kuliah berubah',
    body: 'Kelas Mobile pindah ke Ruang A2 jam 13.00',
  ),
];

ProviderContainer _container(CountingAnnouncementRepository repo) {
  final container = ProviderContainer(
    overrides: [
      announcementRepositoryProvider.overrideWithValue(repo),
      // Jeda dipendekkan supaya test tidak menunggu 300 ms per kasus.
      debounceDurationProvider.overrideWithValue(
        const Duration(milliseconds: 10),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'fetchAll hanya dipanggil sekali walau kata kunci berubah berkali-kali',
    () async {
      final repo = CountingAnnouncementRepository(items: _seed);
      final container = _container(repo);

      // Pemanasan: daftar diambil sekali.
      await container.read(searchResultsProvider.future);
      final setelahPemanasan = repo.fetchAllCalls;

      // Ganti kata kunci lima kali. Pada versi sebelum optimasi, tiap perubahan
      // memanggil use case yang memanggil fetchAll lagi.
      for (final q in ['u', 'ut', 'uts', 'uts ', 'uts']) {
        container.read(searchQueryProvider.notifier).set(q);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await container.read(searchResultsProvider.future);
      }

      expect(
        repo.fetchAllCalls,
        setelahPemanasan,
        reason: 'mengganti kata kunci tidak boleh memicu fetchAll lagi',
      );
    },
  );

  test('penyaringan tetap benar setelah daftar di-cache', () async {
    final repo = CountingAnnouncementRepository(items: _seed);
    final container = _container(repo);

    await container.read(searchResultsProvider.future);

    container.read(searchQueryProvider.notifier).set('uts');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final hasil = await container.read(searchResultsProvider.future);

    expect(hasil.announcements, hasLength(1));
    expect(hasil.announcements.first.id, '1');
    expect(repo.fetchAllCalls, 1);
  });

  test('pencarian isi tetap bekerja pada jalur cache', () async {
    final repo = CountingAnnouncementRepository(items: _seed);
    final container = _container(repo);

    await container.read(searchResultsProvider.future);
    container.read(searchQueryProvider.notifier).set('A2');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final hasil = await container.read(searchResultsProvider.future);

    // "A2" hanya ada di body pengumuman #3.
    expect(hasil.announcements, hasLength(1));
    expect(hasil.announcements.first.id, '3');
  });

  group('debounce', () {
    test('ketikan beruntun hanya menyaring sekali', () async {
      final repo = CountingAnnouncementRepository(items: _seed);
      final container = _container(repo);
      await container.read(searchResultsProvider.future);

      // Mengetik cepat tanpa menunggu jeda di antara huruf.
      for (final q in ['j', 'ja', 'jad', 'jadw', 'jadwal']) {
        container.read(searchQueryProvider.notifier).set(q);
      }

      // Sebelum jeda selesai, kata kunci yang dipakai masih yang lama.
      expect(container.read(debouncedQueryProvider), '');

      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Setelah jeda, hanya nilai terakhir yang diteruskan.
      expect(container.read(debouncedQueryProvider), 'jadwal');
    });

    test('query kosong diteruskan seketika, tanpa menunggu jeda', () async {
      final repo = CountingAnnouncementRepository(items: _seed);
      final container = _container(repo);
      await container.read(searchResultsProvider.future);

      container.read(searchQueryProvider.notifier).set('uts');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(container.read(debouncedQueryProvider), 'uts');

      // Tombol hapus harus terasa langsung.
      container.read(searchQueryProvider.notifier).clear();
      expect(container.read(debouncedQueryProvider), '');
    });
  });

  test('kegagalan repository tetap diteruskan lewat cache', () async {
    final repo = _FailingRepository();
    final container = ProviderContainer(
      overrides: [
        announcementRepositoryProvider.overrideWithValue(repo),
        debounceDurationProvider.overrideWithValue(
          const Duration(milliseconds: 10),
        ),
      ],
    );
    addTearDown(container.dispose);

    final hasil = await container.read(searchResultsProvider.future);

    expect(hasil.announcements, isEmpty);
    expect(hasil.failure, isA<LocalFailure>());
  });
}

class _FailingRepository implements AnnouncementRepository {
  @override
  Future<({Announcement? announcement, Failure? failure})> fetchById(
    String id,
  ) async {
    return (announcement: null, failure: const LocalFailure('Gagal'));
  }

  @override
  Future<({List<Announcement> announcements, Failure? failure})>
  fetchAll() async {
    return (
      announcements: const <Announcement>[],
      failure: const LocalFailure('Gagal membaca daftar'),
    );
  }
}
