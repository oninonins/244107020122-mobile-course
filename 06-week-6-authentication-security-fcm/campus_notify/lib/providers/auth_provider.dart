import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/auth_repository.dart';
import '../data/token_store.dart';
import '../messaging/push_service.dart';

/// Di-override di test dengan [InMemoryTokenStore].
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Sumber token. Mengganti provider ini dengan implementasi Firebase Auth
/// adalah satu-satunya perubahan yang diperlukan untuk auth sungguhan.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => MockAuthRepository(),
);

/// Satu [Dio] untuk seluruh aplikasi. Interceptornya me-refresh access token
/// sekali saat 401, dan session expired memaksa guard route mengarahkan
/// pengguna ke /login.
final apiClientProvider = Provider<Dio>((ref) {
  return buildApiClient(
    store: ref.watch(tokenStoreProvider),
    auth: ref.watch(authRepositoryProvider),
    onSessionExpired: () => ref.read(authStateProvider.notifier).logout(),
  );
});

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

/// `true` bila access token tersimpan, yaitu guard route mengizinkan pengguna
/// masuk. Dijalankan saat startup supaya pengguna yang kembali tidak diminta
/// login lagi.
class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final token = await ref.watch(tokenStoreProvider).readAccess();
    return token != null;
  }

  Future<bool> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      await ref
          .read(tokenStoreProvider)
          .save(access: session.access, refresh: session.refresh);
      return true;
    });

    final loggedIn = state.hasValue && state.value == true;
    if (loggedIn) {
      // Token FCM didaftarkan ulang ke backend sekarang juga, karena
      // `POST /devices` baru boleh berjalan setelah access token tersimpan.
      // Jalur ini menutup celah: token yang diambil saat app start dikirim
      // lagi dengan header `Authorization` yang sah.
      unawaited(registerDevice(ref.read(apiClientProvider)));
    }
    return loggedIn;
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    ref.invalidateSelf();
  }
}
