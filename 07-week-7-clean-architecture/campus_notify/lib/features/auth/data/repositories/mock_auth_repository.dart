import '../../../../core/failures.dart';
import '../models/auth_session_model.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

/// Backend auth tiruan agar codelab berjalan tanpa server sungguhan.
///
/// Mengembalikan record, tidak pernah melempar. Week 6 masih memakai
/// `throw AuthFailure(...)`, dan itu bocor sampai `login_page.dart` yang harus
/// menulis `error is AuthFailure ? error.message : ...` — presentation jadi tahu
/// bentuk error dari data layer. Sekarang kegagalan dikembalikan sebagai
/// [Failure] dan presentation hanya membaca `.message`.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.accessLifetime = const Duration(minutes: 15)});

  /// Umur access token. Diperpendek saat demo agar alur 401 -> refresh ->
  /// request ulang bisa diverifikasi dengan cepat.
  final Duration accessLifetime;

  /// Simulasi refresh token yang ditolak server.
  bool refreshAlwaysFails = false;

  final List<String> issuedRefreshTokens = [];

  @override
  Future<({AuthSession? session, Failure? failure})> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Pertahanan kedua: use case `Login` sudah memvalidasi, tapi repository
    // tidak bolehTgantung pada pemanggilnya. Kalau diuji langsung tanpa use
    // case, ia tetap harus menolak.
    if (!email.contains('@') || password.length < 6) {
      return (session: null, failure: const AuthFailure('Email atau kata sandi tidak valid'));
    }

    return _issue(email: email);
  }

  @override
  Future<({AuthSession? session, Failure? failure})> refresh(String refreshToken) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (refreshToken.isEmpty) {
      return (session: null, failure: const AuthFailure('Refresh token hilang'));
    }
    if (refreshAlwaysFails) {
      return (session: null, failure: const AuthFailure('Refresh token ditolak server'));
    }

    final email = refreshToken.split('|').first.replaceFirst('refresh:', '');
    return _issue(email: email);
  }

  ({AuthSession? session, Failure? failure}) _issue({required String email}) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final refresh = 'refresh:$email|$stamp';
    issuedRefreshTokens.add(refresh);

    // Bentuk JSON-nya dibangkitkan di sini supaya `AuthSessionModel` benar-benar
    // dipakai di jalur produksi, bukan kelas mati yang cuma untuk formalitas.
    final model = AuthSessionModel(
      access: 'mock-access.$stamp.sig',
      refresh: refresh,
    );

    return (session: model.toEntity(), failure: null);
  }
}