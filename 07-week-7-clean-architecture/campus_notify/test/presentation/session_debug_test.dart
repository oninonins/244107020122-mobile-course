import 'package:campus_notify/features/auth/data/datasources/secure_token_store.dart';
import 'package:campus_notify/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresi untuk kartu "Debug token" di dashboard.
///
/// `sessionDebugProvider` membaca secure storage. Pembacaan itu tidak otomatis
/// ikut berubah ketika isi penyimpanan berubah, jadi `AuthNotifier` harus
/// memberi tahu lewat `ref.invalidate`. Ada dua jalur yang mengubah penyimpanan:
/// `login()` dan `logout()`. Keduanya diuji terpisah di sini.
///
/// Catatan dari review sejawat: versi pertama file ini menulis ke store secara
/// langsung, bukan lewat `login()`. Akibatnya `ref.invalidate` di `login()`
/// tidak teruji, dan test tetap hijau walau baris itu dihapus. Test pertama di
/// bawah sekarang menempuh jalur `login()` supaya kesalahan itu tidak terulang.
void main() {
  ProviderContainer buatContainer(InMemoryTokenStore store) {
    final container = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('login() membuat kartu debug membaca ulang penyimpanan', () async {
    final store = InMemoryTokenStore();
    final container = buatContainer(store);

    // Login pertama lewat AuthNotifier, bukan dengan menulis store langsung.
    // Ini yang membuat `ref.invalidate` di `login()` benar-benar teruji.
    final pertama = await container
        .read(authStateProvider.notifier)
        .login('mhs@polinema.ac.id', 'rahasia123');
    expect(pertama.session, isNotNull);

    final debug1 = await container.read(sessionDebugProvider.future);
    expect(debug1.email, 'mhs@polinema.ac.id');

    // Login lagi dengan akun berbeda, tanpa logout di antaranya.
    final kedua = await container
        .read(authStateProvider.notifier)
        .login('lain@polinema.ac.id', 'rahasia123');
    expect(kedua.session, isNotNull);

    final debug2 = await container.read(sessionDebugProvider.future);
    expect(
      debug2.email,
      'lain@polinema.ac.id',
      reason: 'tanpa invalidate di login(), nilai cache sesi pertama bertahan',
    );
    // Access token sengaja tidak dibandingkan: token mock berbagi prefix
    // `mock-access.`, sehingga hasil masking-nya identik. Email adalah pembeda
    // yang andal karena berasal dari refresh token.
  });

  test('logout() mengosongkan kartu debug', () async {
    final store = InMemoryTokenStore();
    final container = buatContainer(store);

    await container
        .read(authStateProvider.notifier)
        .login('mhs@polinema.ac.id', 'rahasia123');
    await container.read(sessionDebugProvider.future);

    await container.read(authStateProvider.notifier).logout();

    final setelahLogout = await container.read(sessionDebugProvider.future);
    expect(setelahLogout.maskedAccess, '(kosong)');
    expect(setelahLogout.email, isNull);
  });
}