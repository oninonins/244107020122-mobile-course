import '../../domain/entities/auth_session.dart';

/// Representasi data luar dari sesi autentikasi.
///
/// Dipisah dari [AuthSession] karena hanya kelas ini yang boleh tahu bentuk
/// JSON atau Map-nya. Kalau nanti backend mengubah nama field
/// (`access_token` -> `accessToken`), file yang berubah hanya ini — entity dan
/// seluruh domain tetap utuh.
///
/// Memakai `extends AuthSession` (bukan `implements`) supaya setiap model
/// otomatis adalah entity yang sah; pemanggil di lapisan atas tidak perlu tahu
/// bedanya. Yang perlu dijaga: methods mapping TIDAK boleh override apa pun dari
/// entity, karena itu membuat model menyimpan logika domain.
class AuthSessionModel extends AuthSession {
  const AuthSessionModel({required super.access, required super.refresh});

  /// Bentuk JSON seperti yang dikirim backend sungguhan.
  factory AuthSessionModel.fromJson(Map<String, Object?> json) {
    return AuthSessionModel(
      access: (json['access_token'] as String?) ?? '',
      refresh: (json['refresh_token'] as String?) ?? '',
    );
  }

  Map<String, Object?> toJson() => {
    'access_token': access,
    'refresh_token': refresh,
  };

  /// Konversi ke bentuk yang dipahami domain.
  ///
  /// Dipanggil tepat di batas `data -> domain`. Kalau ini terlupa, error yang
  /// muncul adalah `The argument type 'AuthSessionModel' can't be assigned to
  /// parameter type 'AuthSession'` — bukan error yang sulit ditelusuri kalau
  /// sudah terbenam di beberapa lapis widget.
  AuthSession toEntity() => AuthSession(access: access, refresh: refresh);
}
