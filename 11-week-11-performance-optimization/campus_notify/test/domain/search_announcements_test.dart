import 'package:campus_notify/core/failures.dart';
import 'package:campus_notify/features/announcements/domain/entities/announcement.dart';
import 'package:campus_notify/features/announcements/domain/repositories/announcement_repository.dart';
import 'package:campus_notify/features/announcements/domain/usecases/search_announcements.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository palsu. Tidak ada database, tidak ada jaringan.
class FakeAnnouncementRepository implements AnnouncementRepository {
  FakeAnnouncementRepository({this.items = const [], this.failure});

  final List<Announcement> items;
  final Failure? failure;
  int fetchAllCalls = 0;

  @override
  Future<({Announcement? announcement, Failure? failure})> fetchById(
    String id,
  ) async {
    final found = items.where((a) => a.id == id).firstOrNull;
    if (found == null) {
      return (
        announcement: null,
        failure: LocalFailure('Pengumuman #$id tidak ditemukan'),
      );
    }
    return (announcement: found, failure: null);
  }

  @override
  Future<({List<Announcement> announcements, Failure? failure})>
  fetchAll() async {
    fetchAllCalls++;
    final f = failure;
    if (f != null) return (announcements: const <Announcement>[], failure: f);
    return (announcements: items, failure: null);
  }
}

const _seed = [
  Announcement(
    id: '1',
    title: 'Pendaftaran UTS dibuka',
    body: 'Pendaftaran UTS dibuka sampai Jumat, 22.00 WIB.',
  ),
  Announcement(
    id: '2',
    title: 'Perpustakaan tutup',
    body: 'Perpustakaan tutup 28-30 Oktober karena hari libur.',
  ),
  Announcement(
    id: '3',
    title: 'Jadwal kuliah berubah',
    body: 'Kelas Mobile pindah ke Ruang A2 jam 13.00',
  ),
];

void main() {
  group('filter murni', () {
    test('query kosong mengembalikan semua', () {
      expect(SearchAnnouncements.filter(_seed, ''), hasLength(3));
      expect(SearchAnnouncements.filter(_seed, '   '), hasLength(3));
    });

    test('mencocokkan judul', () {
      final hasil = SearchAnnouncements.filter(_seed, 'perpustakaan');
      expect(hasil, hasLength(1));
      expect(hasil.first.id, '2');
    });

    test('mencocokkan isi, bukan hanya judul', () {
      // "A2" hanya ada di body pengumuman #3. Kalau filter hanya menyentuh
      // judul, hasilnya kosong dan test ini gagal.
      final hasil = SearchAnnouncements.filter(_seed, 'A2');
      expect(hasil, hasLength(1));
      expect(hasil.first.id, '3');
    });

    test('mengabaikan huruf besar dan kecil', () {
      expect(SearchAnnouncements.filter(_seed, 'JADWAL'), hasLength(1));
      expect(SearchAnnouncements.filter(_seed, 'jadwal'), hasLength(1));
      expect(SearchAnnouncements.filter(_seed, 'JaDwAl'), hasLength(1));
    });

    test('membuang spasi di awal dan akhir', () {
      expect(SearchAnnouncements.filter(_seed, '  uts  '), hasLength(1));
    });

    test('query tidak cocok mengembalikan daftar kosong', () {
      expect(SearchAnnouncements.filter(_seed, 'zzz-tak-ada'), isEmpty);
    });

    test('daftar kosong tetap kosong', () {
      expect(SearchAnnouncements.filter(const [], 'apa saja'), isEmpty);
    });

    test('tidak mengubah daftar masukan', () {
      final asli = List<Announcement>.from(_seed);
      SearchAnnouncements.filter(asli, 'jadwal');
      expect(asli, hasLength(3), reason: 'filter tidak boleh menghapus item');
    });
  });

  group('use case', () {
    test('meneruskan hasil filter dari repository', () async {
      final repo = FakeAnnouncementRepository(items: _seed);
      final hasil = await SearchAnnouncements(repo).call('kuliah');

      expect(hasil.failure, isNull);
      expect(hasil.announcements, hasLength(1));
      expect(hasil.announcements.first.title, 'Jadwal kuliah berubah');
      expect(repo.fetchAllCalls, 1);
    });

    test('kegagalan repository diteruskan tanpa melempar', () async {
      final repo = FakeAnnouncementRepository(
        failure: const LocalFailure('Gagal membaca daftar'),
      );
      final hasil = await SearchAnnouncements(repo).call('apa saja');

      expect(hasil.announcements, isEmpty);
      expect(hasil.failure, isA<LocalFailure>());
      expect(hasil.failure?.message, 'Gagal membaca daftar');
    });
  });
}
