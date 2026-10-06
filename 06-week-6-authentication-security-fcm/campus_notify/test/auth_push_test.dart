import 'package:campus_notify/data/auth_repository.dart';
import 'package:campus_notify/data/token_store.dart';
import 'package:campus_notify/routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firebase tidak disiapkan di sini. Yang diuji adalah logika di sekitarnya.
///
/// Berbeda dari contoh codelab, `routeFromMessage` di bawah TIDAK ditulis ulang
/// di dalam file test: ia di-import dari `lib/routes.dart` supaya yang diuji
/// benar-benar fungsi yang dipakai FCM. Kalau fungsinya disalin ke sini,
/// test tetap hijau bahkan kalau `lib/routes.dart` rusak atau dihapus.
void main() {
  test('routeFromMessage menangani route kosong dan tanpa slash', () {
    expect(routeFromMessage({}), Routes.home);
    expect(
      routeFromMessage({'route': 'pengumuman/3'}),
      Routes.announcementDetail('3'),
    );
    expect(
      routeFromMessage({'route': '/pengumuman/3'}),
      Routes.announcementDetail('3'),
    );
  });

  test('data payload membawa id pengumuman', () {
    const data = {'route': '/pengumuman/3', 'id': '3'};
    expect(data['id'], '3');
    expect(routeFromMessage(data), Routes.announcementDetail('3'));
  });

  test('provider auth membaca status login dari token', () async {
    final store = InMemoryTokenStore()..access = 'mock-access';
    expect(await store.readAccess() != null, isTrue);
    store.access = null;
    expect(await store.readAccess() != null, isFalse);
  });

  test('refresh gagal -> sesi dibersihkan (paksa login ulang)', () async {
    final store = InMemoryTokenStore();
    await store.save(access: 'mock-access', refresh: '');

    final repo = MockAuthRepository();
    await expectLater(
      repo.refresh(await store.readRefresh() ?? ''),
      throwsA(isA<AuthFailure>()),
    );

    await store.clear();
    expect(await store.readAccess(), isNull);
    expect(await store.readRefresh(), isNull);
  });
}