import 'package:dio/dio.dart';

import '../../../../core/failures.dart';

/// Memetakan kegagalan jaringan menjadi [Failure] yang ramah pengguna,
/// sehingga UI tidak pernah menampilkan `DioException` mentah.
///
/// Lives di `data` karena ia tahu bentuk `DioException`. `core/` dan `domain/`
/// tidak boleh tahu apa pun tentang Dio — itulah alasan fungsi ini tidak
/// dipindahkan ke sana, meski kelihatannya "cuma utils".
Failure? readableApiFailure(Object error) {
  if (error is! DioException) {
    if (error is FormatException) {
      return const NetworkFailure('Format data dari server tidak dikenali.');
    }
    return const NetworkFailure('Terjadi kesalahan. Silakan coba lagi.');
  }

  // Kalau server sempat menjawab, status code adalah sinyal paling spesifik,
  // apa pun tipe transport yang akhirnya terjadi.
  final status = error.response?.statusCode;
  if (status != null) {
    return switch (status) {
      401 => const NetworkFailure('Sesi Anda habis. Silakan login kembali.'),
      403 => const NetworkFailure('Anda tidak punya akses ke data ini.'),
      404 => const NetworkFailure('Data tidak ditemukan.'),
      >= 500 => const NetworkFailure('Server sedang bermasalah. Coba lagi nanti.'),
      _ => NetworkFailure('Permintaan gagal (HTTP $status).'),
    };
  }

  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout =>
      const NetworkFailure('Koneksi lambat. Coba lagi sebentar.'),
    DioExceptionType.connectionError =>
      const NetworkFailure('Tidak ada koneksi ke server. Cek jaringan Anda.'),
    DioExceptionType.badCertificate =>
      const NetworkFailure('Sertifikat server tidak valid.'),
    DioExceptionType.cancel =>
      const NetworkFailure('Permintaan dibatalkan.'),
    DioExceptionType.badResponse || DioExceptionType.unknown =>
      const NetworkFailure('Terjadi masalah jaringan. Periksa koneksi Anda.'),
  };
}

/// Versi teks dari [readableApiFailure] untuk kebutuhan non-UI.
String readableApiError(Object error) =>
    readableApiFailure(error)?.message ?? 'Terjadi kesalahan.';