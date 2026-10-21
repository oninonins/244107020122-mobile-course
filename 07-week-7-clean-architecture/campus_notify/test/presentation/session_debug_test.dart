import 'package:campus_notify/features/auth/data/datasources/secure_token_store.dart';
import 'package:campus_notify/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresi untuk kartu "Debug token" di dashboard.
///
/// `sessionDebugProvider` membaca secure storage. Kalau provider itu tidak ikut
/// mendengarkan status sesi, hasil pembacaan pertama disimpan selamanya. Akibatnya
/// setelah logout lalu login dengan akun lain, kartu debug masih menampilkan
/// token sesi sebelumnya.
void main() {
  test('kartu debug menghitung ulang setelah sesi berganti', () async {
    final store = InMemoryTokenStore();
    final container = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    // Sesi pertama.
    await store.save(
      access: 'sesi-pertama',
      refresh: 'refresh:mhs@polinema.ac.id|1',
    );
    final pertama = await container.read(sessionDebugProvider.future);
    expect(pertama.email, 'mhs@polinema.ac.id');

    // Logout, lalu login lagi dengan akun berbeda.
    await container.read(authStateProvider.notifier).logout();
    await store.save(
      access: 'sesi-kedua',
      refresh: 'refresh:lain@polinema.ac.id|2',
    );

    final kedua = await container.read(sessionDebugProvider.future);
    expect(kedua.email, 'lain@polinema.ac.id');
    expect(kedua.maskedAccess, startsWith('sesi-kedua'));
  });

  test('setelah logout kartu debug tidak menyisakan token lama', () async {
    final store = InMemoryTokenStore();
    final container = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await store.save(
      access: 'sesi-pertama',
      refresh: 'refresh:mhs@polinema.ac.id|1',
    );
    await container.read(sessionDebugProvider.future);

    await container.read(authStateProvider.notifier).logout();

    final setelahLogout = await container.read(sessionDebugProvider.future);
    expect(setelahLogout.maskedAccess, '(kosong)');
    expect(setelahLogout.email, isNull);
  });
}
