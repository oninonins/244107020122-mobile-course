import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures.dart';
import '../../../../core/format.dart';
import '../../data/datasources/secure_token_store.dart';
import '../../data/repositories/mock_auth_repository.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/token_store.dart';
import '../../domain/usecases/login.dart';

/// SATU-SATUNYA tempat `new` repository dan data source terjadi di fitur auth.
///
/// Widget dan notifier di seluruh project hanya membaca provider di file ini;
/// tidak ada satu pun yang menginstansiasi repository sendiri. `overrideWithValue`
/// di test bekerja justru karena titik `new`-nya terkumpul di satu tempat.
///
/// Di-override di test dengan [InMemoryTokenStore].
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Sumber token. Mengganti provider ini dengan implementasi Firebase Auth
/// adalah satu-satunya perubahan yang diperlukan untuk auth sungguhan.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => MockAuthRepository(),
);

/// Use case menerima abstraksi, bukan implementasi.
final loginProvider = Provider<Login>((ref) {
  return Login(ref.watch(authRepositoryProvider));
});

/// `true` bila access token tersimpan, yaitu guard route mengizinkan pengguna
/// masuk. Dijalankan saat startup supaya pengguna yang kembali tidak diminta
/// login lagi.
final authStateProvider = AsyncNotifierProvider<AuthNotifier, bool>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final token = await ref.watch(tokenStoreProvider).readAccess();
    return token != null;
  }

  /// Melakukan login lalu menyimpan sesinya ke token store.
  ///
  /// Mengembalikan record berisi `failure` yang sudah ramah pengguna, sehingga
  /// `login_page.dart` cukup membaca `.message`. Week 6 masih menulis
  /// `error is AuthFailure ? error.message : ...` di dalam halaman; sekarang
  /// presentation tidak perlu tahu bahwa `AuthFailure` pernah ada.
  Future<({AuthSession? session, Failure? failure})> login(
    String email,
    String password,
  ) async {
    state = const AsyncLoading();

    final result = await ref
        .read(loginProvider)
        .call(email: email, password: password);
    if (result.session == null) {
      state = const AsyncData(false);
      return (session: null, failure: result.failure);
    }

    await ref
        .read(tokenStoreProvider)
        .save(access: result.session!.access, refresh: result.session!.refresh);

    state = const AsyncData(true);

    // Isi secure storage baru berubah. Kartu Debug token membaca penyimpanan
    // itu lewat provider terpisah, jadi harus dihitung ulang di sini.
    ref.invalidate(sessionDebugProvider);

    // Token FCM TIDAK didaftarkan di sini. Aturan "daftar ulang setelah login"
    // milik fitur notifications, dan memanggilnya dari sini akan membuat
    // `auth` dan `notifications` saling mengimpor. Penggabungannya dilakukan
    // di `main.dart` lewat `deviceRegistrationOnLoginProvider`.

    return result;
  }

  /// Menghapus token dan memaksa guard route mengarahkan pengguna ke `/login`.
  ///
  /// Sengaja tidak dibuat sebagai use case: operasinya satu baris tanpa aturan
  /// bisnis. Membuat kelas `Logout` hanya untuk membungkus ini adalah
  /// over-engineering — lihat `docs/ai-challenge.md` tabel keputusan.
  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    // Tanpa ini kartu Debug token tetap menampilkan sesi yang baru dihapus.
    ref.invalidate(sessionDebugProvider);
    ref.invalidateSelf();
  }
}

/// Ringkasan sesi untuk kartu debug, dalam bentuk yang aman ditampilkan.
///
/// View model milik presentation: bukan entity domain, dan membuat
/// `home_page.dart` tidak perlu menyentuh secure storage.
class SessionDebug {
  const SessionDebug({
    required this.maskedAccess,
    required this.maskedRefresh,
    required this.email,
  });

  final String maskedAccess;
  final String maskedRefresh;
  final String? email;
}

/// Dibaca ulang setiap sesi berganti.
///
/// Provider ini membaca secure storage, dan pembacaan itu tidak otomatis ikut
/// berubah ketika isi penyimpanan berubah. Karena itu `AuthNotifier` memanggil
/// `ref.invalidate(sessionDebugProvider)` pada login berhasil dan pada logout.
///
/// Tanpa itu hasil pembacaan pertama bertahan selamanya, sehingga setelah
/// logout lalu login dengan akun lain kartu Debug token masih menampilkan token
/// sesi sebelumnya. Perilaku itu dikunci oleh
/// `test/presentation/session_debug_test.dart`.
final sessionDebugProvider = FutureProvider<SessionDebug>((ref) async {
  final store = ref.watch(tokenStoreProvider);
  final access = await store.readAccess();
  final refresh = await store.readRefresh();
  return SessionDebug(
    maskedAccess: maskToken(access),
    maskedRefresh: maskToken(refresh),
    email: emailFromRefresh(refresh),
  );
});
