/// Sesi hasil login yang berhasil: access token berumur pendek + refresh
/// token berumur panjang.
class AuthSession {
  const AuthSession({required this.access, required this.refresh});

  final String access;
  final String refresh;
}

/// Error autentikasi yang aman ditampilkan ke pengguna.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Kontrak untuk setiap backend auth.
///
/// Titik tukar ke Firebase Auth ada di kelas ini: cukup ganti implementasi
/// `login` dengan `FirebaseAuth.instance.signInWithEmailAndPassword` (atau
/// GoogleSignIn) dan ID token hasilnya dipakai sebagai [AuthSession.access].
/// Repository, token store, dan interceptor Dio tidak berubah sama sekali.
abstract interface class AuthRepository {
  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> refresh(String refreshToken);
}

/// Mock backend agar codelab berjalan tanpa server sungguhan.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.accessLifetime = const Duration(minutes: 15)});

  /// Umur access token. Diperpendek saat demo agar alur 401 -> refresh ->
  /// request ulang bisa diverifikasi dengan cepat.
  final Duration accessLifetime;

  /// Simulasi refresh token yang ditolak server.
  bool refreshAlwaysFails = false;

  final List<String> issuedRefreshTokens = [];

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!email.contains('@') || password.length < 6) {
      throw const AuthFailure('Email atau kata sandi tidak valid');
    }
    return _issue(email: email);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (refreshToken.isEmpty) {
      throw const AuthFailure('Refresh token hilang');
    }
    if (refreshAlwaysFails) {
      throw const AuthFailure('Refresh token ditolak server');
    }
    final email = refreshToken.split('|').first.replaceFirst('refresh:', '');
    return _issue(email: email);
  }

  AuthSession _issue({required String email}) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final refresh = 'refresh:$email|$stamp';
    issuedRefreshTokens.add(refresh);
    return AuthSession(
      // Simulasi JWT: header.payload.signature. Jangan di-parse manual di
      // produksi, verifikasi tetap di server.
      access: 'mock-access.$stamp.sig',
      refresh: refresh,
    );
  }
}

/// Memotong token agar aman ditampilkan di halaman debug dan screenshot
/// laporan.
String maskToken(String? token, {int visible = 12}) {
  if (token == null || token.isEmpty) return '(kosong)';
  if (token.length <= visible) return '$token...';
  return '${token.substring(0, visible)}...';
}
