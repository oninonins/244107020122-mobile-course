import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kontrak penyimpanan token. Token hanya boleh keluar-masuk lewat kelas ini.
abstract interface class TokenStore {
  Future<void> save({required String access, required String refresh});

  Future<String?> readAccess();

  Future<String?> readRefresh();

  Future<void> clear();
}

/// Implementasi produksi di atas `flutter_secure_storage`
/// (iOS Keychain / Android Keystore).
///
/// Jangan pernah ganti ini dengan SharedPreferences: SharedPreferences
/// disimpan sebagai teks biasa di disk tanpa enkripsi.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const accessKey = 'access_token';
  static const refreshKey = 'refresh_token';

  @override
  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: accessKey, value: access);
    await _storage.write(key: refreshKey, value: refresh);
  }

  @override
  Future<String?> readAccess() => _storage.read(key: accessKey);

  @override
  Future<String?> readRefresh() => _storage.read(key: refreshKey);

  @override
  Future<void> clear() => _storage.deleteAll();
}

/// Implementasi in-memory untuk unit test, agar logika auth bisa diuji
/// tanpa Keychain/Keystore.
class InMemoryTokenStore implements TokenStore {
  String? access;
  String? refresh;

  @override
  Future<void> save({required String access, required String refresh}) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}
