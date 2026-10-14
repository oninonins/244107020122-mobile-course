import '../../../../core/failures.dart';
import '../entities/auth_session.dart';

/// Kontrak sumber token autentikasi.
///
/// Dipisah dari `MockAuthRepository` yang mendasarikannya. Alasannya langsung ke
/// prinsip Dependency Inversion: whoever yang butuh "memberi tahu status login"
/// — notifier, router guard, interceptor Dio — harus bergantung pada kontrak
/// ini, bukan pada kelas mock.
///
/// Titik tukar ke Firebase Auth ada di sini: cukup tulis implementasi baru
/// (mis. `FirebaseAuthRepository`) tanpa mengubah satu baris pun di
/// presentation maupun interceptor.
abstract interface class AuthRepository {
  /// Meminta sesi baru.
  ///
  /// Mengembalikan record, bukan melempar exception. Kegagalan dikembalikan
  /// sebagai [Failure] supaya tidak ada `try/catch` yang bocor sampai widget,
  /// dan supaya `login_page.dart` tidak perlu `error is AuthFailure`.
  ///
  /// Pola `Either<Failure, T>` dari `fpdart`/`dartz` adalah bentuk yang sama
  /// dengan nama berbeda — yang dipakai di sini adalah record bawaan Dart,
  /// tanpa dependency tambahan.
  Future<({AuthSession? session, Failure? failure})> login({
    required String email,
    required String password,
  });

  /// Menukar refresh token menjadi sesi baru saat access token kedaluwarsa.
  Future<({AuthSession? session, Failure? failure})> refresh(String refreshToken);
}