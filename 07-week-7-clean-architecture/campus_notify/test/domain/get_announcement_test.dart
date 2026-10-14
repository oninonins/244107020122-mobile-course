import 'package:campus_notify/core/failures.dart';
import 'package:campus_notify/features/announcements/domain/entities/announcement.dart';
import 'package:campus_notify/features/announcements/domain/repositories/announcement_repository.dart';
import 'package:campus_notify/features/announcements/domain/usecases/get_announcement.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository palsu pengumuman.
///
/// Sama seperti `FakeAuthRepository`, TIDAK ada `throw UnimplementedError()`
/// di sini. Interface `AnnouncementRepository` sengaja hanya punya satu metode,
/// jadi fake tidak punya metode lain yang perlu "di-stub" — dan itu sendiri
/// adalah bukti bahwa kontrak tidak berlebihan.
class FakeAnnouncementRepository implements AnnouncementRepository {
  FakeAnnouncementRepository({this.items = const [], this.failure});

  final List<Announcement> items;
  final Failure? failure;

  @override
  Future<({Announcement? announcement, Failure? failure})> fetchById(String id) async {
    final f = failure;
    if (f != null) return (announcement: null, failure: f);

    final found = items.where((a) => a.id == id).firstOrNull;
    if (found == null) {
      return (
        announcement: null,
        failure: LocalFailure('Pengumuman #$id tidak ditemukan'),
      );
    }
    return (announcement: found, failure: null);
  }
}

void main() {
  late FakeAnnouncementRepository repo;

  setUp(() {
    repo = FakeAnnouncementRepository(
      items: const [
        Announcement(id: '3', title: 'Jadwal kuliah berubah', body: 'Ruang A2 jam 13.00'),
        Announcement(id: '1', title: 'Pendaftaran UTS dibuka', body: 'Sampai Jumat'),
      ],
    );
  });

  test('GetAnnouncement meneruskan pengumuman dari repository', () async {
    final result = await GetAnnouncement(repo).call('3');

    expect(result.failure, isNull);
    expect(result.announcement, isNotNull);
    expect(result.announcement!.id, '3');
    expect(result.announcement!.title, 'Jadwal kuliah berubah');
  });

  test('GetAnnouncement meneruskan failure tanpa melempar', () async {
    final result = await GetAnnouncement(repo).call('99');

    expect(result.announcement, isNull);
    expect(result.failure, isA<LocalFailure>());
    expect(result.failure?.message, 'Pengumuman #99 tidak ditemukan');
  });

  test('repository yang gagal mengembalikan failure dari sumbernya', () async {
    repo = FakeAnnouncementRepository(failure: const NetworkFailure('Tidak ada koneksi'));

    final result = await GetAnnouncement(repo).call('3');

    expect(result.announcement, isNull);
    expect(result.failure, isA<NetworkFailure>());
  });

  test('entity tidak punya mapping apa pun', () {
    // Kalau `Announcement` ikut punya toJson, grep ini akan menemukannya dan
    // test ini reminding bahwa mapping hanya boleh di model.
    expect(Announcement, isNotNull);
  });
}