import 'package:campus_notify/features/announcements/domain/entities/announcement.dart';
import 'package:campus_notify/features/announcements/domain/repositories/announcement_repository.dart';
import 'package:campus_notify/features/announcements/presentation/pages/announcement_list_page.dart';
import 'package:campus_notify/features/announcements/presentation/providers/announcement_providers.dart';
import 'package:campus_notify/core/failures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository palsu untuk widget test. Tidak ada database.
class FakeAnnouncementRepository implements AnnouncementRepository {
  FakeAnnouncementRepository({this.items = const [], this.failure});

  final List<Announcement> items;
  final Failure? failure;

  @override
  Future<({Announcement? announcement, Failure? failure})> fetchById(
    String id,
  ) async {
    final found = items.where((a) => a.id == id).firstOrNull;
    if (found == null) {
      return (announcement: null, failure: LocalFailure('Tidak ditemukan'));
    }
    return (announcement: found, failure: null);
  }

  @override
  Future<({List<Announcement> announcements, Failure? failure})>
  fetchAll() async {
    final f = failure;
    if (f != null) return (announcements: const <Announcement>[], failure: f);
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
    id: '3',
    title: 'Jadwal kuliah berubah',
    body: 'Kelas Mobile pindah ke Ruang A2 jam 13.00',
  ),
];

Widget _app(FakeAnnouncementRepository repo) => ProviderScope(
  overrides: [announcementRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(home: AnnouncementListPage()),
);

void main() {
  testWidgets('menampilkan seluruh pengumuman saat query kosong', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FakeAnnouncementRepository(items: _seed)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('announcement-1')), findsOneWidget);
    expect(find.byKey(const Key('announcement-3')), findsOneWidget);
    expect(find.byKey(const Key('search-empty')), findsNothing);
  });

  testWidgets('menyaring daftar saat pengguna mengetik', (tester) async {
    await tester.pumpWidget(_app(FakeAnnouncementRepository(items: _seed)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'A2');
    await tester.pumpAndSettle();

    // "A2" hanya ada di body pengumuman #3.
    expect(find.byKey(const Key('announcement-3')), findsOneWidget);
    expect(find.byKey(const Key('announcement-1')), findsNothing);
  });

  testWidgets('empty state muncul saat query tidak cocok', (tester) async {
    await tester.pumpWidget(_app(FakeAnnouncementRepository(items: _seed)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('search-field')),
      'zzz-tak-ada',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-empty')), findsOneWidget);
    // Teks query muncul dua kali: di kolom input dan di pesan empty state.
    // Yang diperiksa pesannya, bukan isi kolom.
    expect(
      find.text('Tidak ada pengumuman yang cocok dengan "zzz-tak-ada".'),
      findsOneWidget,
    );
  });

  testWidgets('empty state berbeda saat memang belum ada data', (tester) async {
    await tester.pumpWidget(_app(FakeAnnouncementRepository(items: const [])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-empty')), findsOneWidget);
    expect(find.text('Belum ada pengumuman.'), findsOneWidget);
  });

  testWidgets('tombol hapus mengembalikan daftar penuh', (tester) async {
    await tester.pumpWidget(_app(FakeAnnouncementRepository(items: _seed)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'uts');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('announcement-3')), findsNothing);

    await tester.tap(find.byKey(const Key('search-clear')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('announcement-3')), findsOneWidget);
  });

  testWidgets('kegagalan repository ditampilkan sebagai pesan', (tester) async {
    await tester.pumpWidget(
      _app(
        FakeAnnouncementRepository(
          failure: const LocalFailure('Gagal membaca daftar'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gagal membaca daftar'), findsOneWidget);
  });
}
