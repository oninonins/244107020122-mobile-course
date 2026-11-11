import 'package:campus_notify/features/auth/data/datasources/secure_token_store.dart';
import 'package:campus_notify/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresi untuk kartu "Debug token" di dashboard.
///
/// `sessionDebugProvider` membaca secure storage, dan pembacaan itu tidak
/// otomatis berubah ketika isi penyimpanan berubah. `AuthNotifier` karena itu
/// harus memanggil `ref.invalidate`. Ada dua jalur yang mengubah penyimpanan:
/// `login()` dan `logout()`.
///
/// Versi pertama file ini menulis ke store langsung, bukan lewat `login()`,
/// sehingga `ref.invalidate` di `login()` tidak teruji. Itu ditemukan reviewer
/// sejawat pada PR #2, dan sekarang test menempuh jalur `login()`.
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

  test('alur pada laporan bug: login A, logout, login B', () async {
    // Test ini meniru langkah yang tertulis di issue #1. Dua test di atas
    // menutup separuh-separuh; yang ini menempuh alurnya utuh, karena bug asli
    // muncul justru pada kombinasi logout lalu login dengan akun berbeda.
    final store = InMemoryTokenStore();
    final container = buatContainer(store);
    final auth = container.read(authStateProvider.notifier);

    await auth.login('a@polinema.ac.id', 'rahasia123');
    final kartuA = await container.read(sessionDebugProvider.future);
    expect(kartuA.email, 'a@polinema.ac.id');

    await auth.logout();
    final kartuKosong = await container.read(sessionDebugProvider.future);
    expect(kartuKosong.email, isNull);
    expect(kartuKosong.maskedAccess, '(kosong)');

    await auth.login('b@polinema.ac.id', 'rahasia123');
    final kartuB = await container.read(sessionDebugProvider.future);
    expect(
      kartuB.email,
      'b@polinema.ac.id',
      reason: 'kartu debug tidak boleh menampilkan sesi A setelah login B',
    );
  });
}
