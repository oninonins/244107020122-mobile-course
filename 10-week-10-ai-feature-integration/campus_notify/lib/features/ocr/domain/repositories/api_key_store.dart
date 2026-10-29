/// Kontrak penyimpanan API key.
///
/// Kunci AI tidak pernah ditulis di kode sumber dan tidak pernah ikut
/// di-commit. Pengguna memasukkannya sendiri lewat layar pengaturan, lalu
/// disimpan di `flutter_secure_storage`.
abstract interface class ApiKeyStore {
  Future<String?> read();

  Future<void> save(String apiKey);

  Future<void> clear();
}
