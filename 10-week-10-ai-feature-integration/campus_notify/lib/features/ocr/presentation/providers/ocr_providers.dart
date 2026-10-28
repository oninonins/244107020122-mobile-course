import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures.dart';
import '../../data/datasources/secure_api_key_store.dart';
import '../../data/repositories/openrouter_ocr_repository.dart';
import '../../data/repositories/openrouter_quota_repository.dart';
import '../../domain/entities/ai_quota.dart';
import '../../domain/entities/ocr_result.dart';
import '../../domain/repositories/ai_quota_repository.dart';
import '../../domain/repositories/api_key_store.dart';
import '../../domain/repositories/ocr_repository.dart';
import '../../domain/usecases/extract_text.dart';

/// SATU-SATUNYA tempat `new` untuk kelas OCR.
///
/// Widget tidak pernah menginstansiasi repository sendiri, sama seperti aturan
/// di fitur auth dan announcements.
///
/// Di-override di test dengan [InMemoryApiKeyStore].
final apiKeyStoreProvider = Provider<ApiKeyStore>((ref) => SecureApiKeyStore());

/// Model yang dipakai. Bisa diganti saat demo kalau model gratis sedang tidak
/// tersedia.
///
/// Memakai [NotifierProvider], bukan `StateProvider`, karena Riverpod 3
/// menghapus `StateProvider`.
final ocrModelProvider = NotifierProvider<OcrModelNotifier, String>(
  OcrModelNotifier.new,
);

class OcrModelNotifier extends Notifier<String> {
  @override
  String build() => defaultOcrModel;

  void set(String model) =>
      state = model.trim().isEmpty ? defaultOcrModel : model.trim();
}

final ocrRepositoryProvider = Provider<OcrRepository>((ref) {
  return buildOcrRepository(
    keyStore: ref.watch(apiKeyStoreProvider),
    model: ref.watch(ocrModelProvider),
  );
});

final extractTextProvider = Provider<ExtractText>((ref) {
  return ExtractText(ref.watch(ocrRepositoryProvider));
});

final quotaRepositoryProvider = Provider<AiQuotaRepository>((ref) {
  return buildQuotaRepository(keyStore: ref.watch(apiKeyStoreProvider));
});

/// Sisa kuota akun. Di-invalidate saat pengguna menekan tombol cek kuota.
final aiQuotaProvider = FutureProvider<({AiQuota? quota, Failure? failure})>((
  ref,
) {
  return ref.watch(quotaRepositoryProvider).fetch();
});

/// Status penyimpanan API key, untuk menampilkan peringatan di halaman.
///
/// Hanya mengembalikan `true` atau `false`, bukan key-nya. Key tidak pernah
/// masuk ke state yang bisa dirender atau di-log.
final hasApiKeyProvider = FutureProvider<bool>((ref) async {
  final key = await ref.watch(apiKeyStoreProvider).read();
  return key != null && key.isNotEmpty;
});

/// State halaman pindai.
class OcrState {
  const OcrState({this.result, this.failure, this.busy = false});

  final OcrResult? result;
  final Failure? failure;
  final bool busy;

  OcrState copyWith({
    OcrResult? result,
    Failure? failure,
    bool? busy,
    bool clearOutput = false,
  }) {
    return OcrState(
      result: clearOutput ? null : (result ?? this.result),
      failure: clearOutput ? null : (failure ?? this.failure),
      busy: busy ?? this.busy,
    );
  }
}

final ocrControllerProvider = NotifierProvider<OcrController, OcrState>(
  OcrController.new,
);

class OcrController extends Notifier<OcrState> {
  @override
  OcrState build() => const OcrState();

  /// Memproses gambar. Kegagalan dikembalikan lewat state, bukan dilempar.
  Future<void> scan({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    state = state.copyWith(busy: true, clearOutput: true);

    final result = await ref
        .read(extractTextProvider)
        .call(imageBytes: bytes, mimeType: mimeType);

    state = OcrState(result: result.result, failure: result.failure);
  }

  void reset() => state = const OcrState();
}
