/// Hasil ekstraksi teks dari sebuah gambar.
///
/// Ini ENTITY, bukan model. Tidak ada parsing JSON di sini. Bentuk respons
/// OpenRouter dipetakan di `data/repositories/openrouter_ocr_repository.dart`.
class OcrResult {
  const OcrResult({
    required this.text,
    required this.model,
    this.truncated = false,
  });

  /// Teks hasil ekstraksi, sudah dirapikan.
  final String text;

  /// Model yang benar-benar menjawab. Disimpan karena model gratis bisa
  /// dialihkan ke penyedia lain oleh OpenRouter.
  final String model;

  /// Benar bila jawaban dipotong karena melewati batas panjang.
  ///
  /// Ditampilkan di UI sebagai peringatan, supaya pengguna tahu teksnya tidak
  /// lengkap dan tidak menyalinnya mentah-mentah.
  final bool truncated;

  bool get isEmpty => text.trim().isEmpty;

  @override
  String toString() => 'OcrResult(model: $model, chars: ${text.length})';
}
