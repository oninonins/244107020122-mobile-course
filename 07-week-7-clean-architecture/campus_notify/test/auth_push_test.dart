import 'package:campus_notify/core/failures.dart';
import 'package:campus_notify/core/format.dart';
import 'package:campus_notify/features/auth/data/datasources/secure_token_store.dart';
import 'package:campus_notify/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:campus_notify/routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firebase tidak disiapkan di sini. Yang diuji adalah logika di sekitarnya.
///
/// `routeFromMessage` di-import dari `lib/core/format.dart`, bukan ditulis ulang
/// di dalam file test. Kalau fungsinya disalin ke sini, test tetap hijau walau
/// `format.dart` rusak atau dihapus.
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

  test('token store membaca status login', () async {
    final store = InMemoryTokenStore()..access = 'mock-access';
    expect(await store.readAccess() != null, isTrue);
    store.access = null;
    expect(await store.readAccess() != null, isFalse);
  });

  test('refresh ditolak -> kegagalan dikembalikan, bukan dilempar', () async {
    final repo = MockAuthRepository()..refreshAlwaysFails = true;

    // Week 6 menulis `expectLater(..., throwsA(isA<AuthFailure>()))`. Sekarang
    // kegagalan masuk lewat record, jadi tidak ada exception yang bisa bocor
    // sampai widget.
    final result = await repo.refresh('refresh:mhs@polinema.ac.id|1');
    expect(result.session, isNull);
    expect(result.failure, isA<AuthFailure>());
    expect(result.failure?.message, 'Refresh token ditolak server');
  });

  test('refresh tanpa token -> kegagalan lokal', () async {
    final repo = MockAuthRepository();
    final result = await repo.refresh('');
    expect(result.session, isNull);
    expect(result.failure, isA<AuthFailure>());
  });

  test('refresh berhasil -> session dikembalikan sebagai entity', () async {
    final repo = MockAuthRepository();
    final result = await repo.refresh('refresh:mhs@polinema.ac.id|1');
    expect(result.failure, isNull);
    expect(result.session, isNotNull);
    expect(result.session!.access, startsWith('mock-access.'));
  });

  test('sesi dibersihkan memaksa login ulang', () async {
    final store = InMemoryTokenStore();
    await store.save(access: 'mock-access', refresh: 'refresh:x|1');
    await store.clear();
    expect(await store.readAccess(), isNull);
    expect(await store.readRefresh(), isNull);
  });
}
