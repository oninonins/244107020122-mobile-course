import '../../../../core/failures.dart';
import '../models/announcement_model.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';

/// Sumber pengumuman dari seed JSON lokal.
///
/// Isinya persis sama dengan yang sebelumnya ditulis langsung di dalam
/// `announcement_page.dart`. Memindahkannya ke sini **tidak mengubah apa pun yang
/// dilihat pengguna** — itu syarat wajib refactor Clean Architecture.
///
/// Bentuknya sengaja `List<Map<String, Object?>>`, bukan `List<Announcement>`,
/// supaya `AnnouncementModel.fromJson` benar-benar dijalankan pada jalur yang
/// dipakai aplikasi. Kalau langsung menyimpan entity, kelas model akan jadi
/// kode mati yang hanya formalitas.
class MockAnnouncementRepository implements AnnouncementRepository {
  MockAnnouncementRepository({List<Map<String, Object?>>? seed})
    : _seed = seed ?? defaultSeed;

  final List<Map<String, Object?>> _seed;

  @override
  Future<({Announcement? announcement, Failure? failure})> fetchById(
    String id,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final row = _seed.where((json) => json['id'] == id).firstOrNull;
    if (row == null) {
      return (
        announcement: null,
        failure: LocalFailure('Pengumuman #$id tidak ditemukan'),
      );
    }

    return (
      announcement: AnnouncementModel.fromJson(row).toEntity(),
      failure: null,
    );
  }

  @override
  Future<({List<Announcement> announcements, Failure? failure})>
  fetchAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    try {
      final items = _seed
          .map((json) => AnnouncementModel.fromJson(json).toEntity())
          .toList();
      return (announcements: items, failure: null);
    } on Object catch (e) {
      // Kegagalan parsing dikembalikan sebagai Failure, bukan dilempar, supaya
      // satu baris data yang rusak tidak menjatuhkan seluruh halaman.
      return (
        announcements: const <Announcement>[],
        failure: LocalFailure('Gagal membaca daftar pengumuman: $e'),
      );
    }
  }

  /// Data bawaan: isi identik dengan teks yang tadinya hardcoded di widget.
  static const List<Map<String, Object?>> defaultSeed = [
    {
      'id': '1',
      'title': 'Pendaftaran UTS dibuka',
      'body': 'Pendaftaran UTS dibuka sampai Jumat, 22.00 WIB.',
    },
    {
      'id': '2',
      'title': 'Perpustakaan tutup',
      'body': 'Perpustakaan tutup 28-30 Oktober karena hari libur.',
    },
    {
      'id': '3',
      'title': 'Jadwal kuliah berubah',
      'body': 'Kelas Mobile pindah ke Ruang A2 jam 13.00',
    },
  ];
}
