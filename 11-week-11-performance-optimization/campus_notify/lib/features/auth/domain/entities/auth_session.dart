/// Sesi hasil login yang berhasil: access token berumur pendek + refresh token
/// berumur panjang.
///
/// Ini adalah ENTITY, bukan model. Tidak ada mapping JSON maupun parsing apa
/// pun di sini - semuanya ada di `data/models/auth_session_model.dart`.
///
/// Kenapa dibedakan? Karena bentuk data di luar (JSON dari backend, baris
/// SQLite, header HTTP) bisa berubah kapan saja, sedangkan "sesi yang berisi
/// access dan refresh" adalah konsep bisnis yang tidak berubah. Kalau parser ikut
/// menempel di entity, setiap kali backend menambah satu field, logika bisnis
/// ikut berubah.
class AuthSession {
  const AuthSession({required this.access, required this.refresh});

  /// Token berumur pendek, dikirim pada setiap request sebagai
  /// `Authorization: Bearer <access>`.
  final String access;

  /// Token berumur panjang, hanya dipakai untuk meminta access token baru saat
  /// yang lama kedaluwarsa.
  final String refresh;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSession &&
          other.access == access &&
          other.refresh == refresh;

  @override
  int get hashCode => Object.hash(access, refresh);

  @override
  String toString() => 'AuthSession(refresh: #${refresh.hashCode})';
}
