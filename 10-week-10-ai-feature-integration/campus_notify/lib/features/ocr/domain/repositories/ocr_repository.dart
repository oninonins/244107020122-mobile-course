import 'dart:typed_data';

import '../../../../core/failures.dart';
import '../entities/ocr_result.dart';

/// Kontrak ekstraksi teks dari gambar.
///
/// Menerima `Uint8List`, bukan `File` atau `XFile`. Alasannya: `XFile` berasal
/// dari `image_picker` yang merupakan package Flutter, dan `File` berasal dari
/// `dart:io`. Kalau salah satunya masuk ke kontrak ini, `domain` ikut bergantung
/// pada Flutter dan aturan dependensi Week 7 langsung rusak.
///
/// `Uint8List` berasal dari `dart:typed_data`, jadi aman.
abstract interface class OcrRepository {
  /// Mengembalikan record, tidak melempar.
  ///
  /// Semua kegagalan dipetakan ke [Failure] di lapisan `data`, sehingga
  /// presentation cukup membaca `.message` tanpa `try/catch`.
  Future<({OcrResult? result, Failure? failure})> extractText({
    required Uint8List imageBytes,
    required String mimeType,
  });
}
