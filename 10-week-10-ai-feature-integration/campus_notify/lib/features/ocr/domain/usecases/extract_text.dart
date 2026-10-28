import 'dart:typed_data';

import '../../../../core/failures.dart';
import '../entities/ocr_result.dart';
import '../repositories/ocr_repository.dart';

/// Operasi bisnis: memvalidasi gambar sebelum dikirim ke layanan AI.
///
/// ## Kenapa use case ini perlu ada
///
/// Karena ia memegang aturan yang tidak boleh dilanggar:
///
/// 1. Gambar harus salah satu format yang didukung model vision.
/// 2. Ukuran gambar dibatasi. Kiriman besar membuang kuota dan bisa ditolak
///    penyedia, dan pada model gratis batasnya lebih ketat.
/// 3. Gambar kosong tidak boleh dikirim sama sekali.
///
/// Tanpa use case, ketiga aturan itu harus ditulis ulang di setiap halaman yang
/// memakai OCR, dan tidak bisa diuji tanpa widget.
///
/// ## Batas yang dipakai
///
/// Sama seperti Week 7: use case dibuat bila ada aturan bisnis atau lebih dari
/// satu sumber data. Validasi di sini nyata, bukan formalitas.
class ExtractText {
  const ExtractText(this._repository);

  final OcrRepository _repository;

  /// Batas ukuran gambar setelah dikompres.
  ///
  /// 4 MB cukup untuk foto papan pengumuman pada `maxWidth: 1280` dan
  /// `imageQuality: 60`. Di atas itu, kemungkinan besar pengguna memilih file
  /// asli dari galeri tanpa kompresi.
  static const int maxBytes = 4 * 1024 * 1024;

  static const Set<String> allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// Memeriksa gambar tanpa memanggil jaringan.
  ///
  /// Dipisah dari [call] supaya halaman bisa memberi pesan lebih awal, sebelum
  /// indikator loading muncul.
  static Failure? validate({
    required Uint8List imageBytes,
    required String mimeType,
  }) {
    if (imageBytes.isEmpty) {
      return const ValidationFailure('Gambar kosong. Pilih gambar lain.');
    }
    if (!allowedMimeTypes.contains(mimeType)) {
      return const ValidationFailure(
        'Format gambar tidak didukung. Gunakan JPG, PNG, atau WEBP.',
      );
    }
    if (imageBytes.length > maxBytes) {
      final mb = (imageBytes.length / (1024 * 1024)).toStringAsFixed(1);
      return ValidationFailure('Gambar terlalu besar ($mb MB). Maksimal 4 MB.');
    }
    return null;
  }

  Future<({OcrResult? result, Failure? failure})> call({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final invalid = validate(imageBytes: imageBytes, mimeType: mimeType);
    if (invalid != null) {
      return (result: null, failure: invalid);
    }

    return _repository.extractText(imageBytes: imageBytes, mimeType: mimeType);
  }
}
