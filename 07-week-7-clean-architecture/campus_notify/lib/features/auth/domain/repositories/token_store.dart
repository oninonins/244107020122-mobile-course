/// Kontrak penyimpanan token.
///
/// Token hanya boleh keluar-masuk lewat kelas ini, dan interface-nya tinggal di
/// `domain` supaya tidakifier tidak perlu tahu bahwa di baliknya ada Keychain
/// atau Keystore.
///
/// Catatan keamanan: ini satu-satunya alasan penyimpanan memakai
/// `flutter_secure_storage`. Jangan pernah menggantinya dengan
/// `SharedPreferences` — nilainya disimpan sebagai teks biasa di disk tanpa
/// enkripsi, dan refresh token yang bocor berarti orang tersebut bisa
/// mengambil alih identitas pengguna, bukan sekadar membaca data.
abstract interface class TokenStore {
  Future<void> save({required String access, required String refresh});

  Future<String?> readAccess();

  Future<String?> readRefresh();

  Future<void> clear();
}