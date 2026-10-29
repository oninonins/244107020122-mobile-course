import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/repositories/api_key_store.dart';

/// Penyimpanan API key di Keychain (iOS) atau Keystore (Android).
///
/// Key hanya lewat kelas ini, dan tidak pernah ditulis ke kode sumber, file
/// `.env`, atau log. `SharedPreferences` tidak dipakai karena menyimpan nilai
/// sebagai teks biasa di disk.
class SecureApiKeyStore implements ApiKeyStore {
  SecureApiKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'openrouter_api_key';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> save(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await clear();
      return;
    }
    await _storage.write(key: _key, value: trimmed);
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Penyimpanan in-memory untuk unit test, supaya logika OCR bisa diuji tanpa
/// Keychain atau Keystore.
class InMemoryApiKeyStore implements ApiKeyStore {
  InMemoryApiKeyStore([this.apiKey]);

  String? apiKey;

  @override
  Future<String?> read() async => apiKey;

  @override
  Future<void> save(String value) async => apiKey = value.trim();

  @override
  Future<void> clear() async => apiKey = null;
}
