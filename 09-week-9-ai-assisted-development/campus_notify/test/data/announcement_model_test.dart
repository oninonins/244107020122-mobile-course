import 'package:campus_notify/features/announcements/data/models/announcement_model.dart';
import 'package:campus_notify/features/announcements/data/repositories/mock_announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test untuk jalur data pengumuman.
///
/// `AnnouncementModel.fromJson` dipakai di dua jalur: `fetchById` dan `fetchAll`.
/// Sebelumnya tidak ada test yang memanggilnya langsung, sehingga bug pada
/// parsing id tidak pernah terdeteksi. Test ini menutup celah itu.
void main() {
  group('AnnouncementModel.fromJson', () {
    test('menerima id bertipe String', () {
      // Seed repository memakai id String, jadi bentuk ini yang paling sering
      // dipakai. Kalau cast-nya salah, baris ini melempar TypeError, bukan
      // gagal asersi.
      final model = AnnouncementModel.fromJson(const {
        'id': '3',
        'title': 'Jadwal kuliah berubah',
        'body': 'Kelas Mobile pindah ke Ruang A2 jam 13.00',
      });

      expect(model.id, '3');
      expect(model.title, 'Jadwal kuliah berubah');
      expect(model.body, contains('Ruang A2'));
    });

    test('menerima id bertipe int', () {
      // Bentuk ini bisa datang dari backend sungguhan yang mengirim angka.
      final model = AnnouncementModel.fromJson(const {
        'id': 7,
        'title': 'Judul',
        'body': 'Isi',
      });

      expect(model.id, '7');
    });

    test('id yang hilang menjadi string kosong, bukan melempar', () {
      final model = AnnouncementModel.fromJson(const {
        'title': 'Tanpa id',
        'body': 'Isi',
      });

      expect(model.id, '');
    });

    test('field lain yang hilang tidak melempar', () {
      final model = AnnouncementModel.fromJson(const {'id': '1'});

      expect(model.title, '');
      expect(model.body, '');
    });
  });

  group('MockAnnouncementRepository', () {
    test('fetchAll membaca seluruh seed', () async {
      final repo = MockAnnouncementRepository();
      final hasil = await repo.fetchAll();

      expect(hasil.failure, isNull);
      expect(hasil.announcements, hasLength(3));
      expect(
        hasil.announcements.map((a) => a.id),
        containsAll(['1', '2', '3']),
      );
    });

    test('fetchAll mengembalikan entity, bukan model', () async {
      final repo = MockAnnouncementRepository();
      final hasil = await repo.fetchAll();

      expect(hasil.announcements.first, isA<Object>());
      expect(hasil.announcements.first.runtimeType.toString(), 'Announcement');
    });

    test('fetchById tetap bekerja', () async {
      final repo = MockAnnouncementRepository();
      final hasil = await repo.fetchById('3');

      expect(hasil.failure, isNull);
      expect(hasil.announcement?.title, 'Jadwal kuliah berubah');
    });
  });
}
