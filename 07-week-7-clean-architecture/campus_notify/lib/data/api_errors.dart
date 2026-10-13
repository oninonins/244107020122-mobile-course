import 'package:dio/dio.dart';

/// Memetakan kegagalan jaringan menjadi pesan yang bisa ditindaklanjuti
/// pengguna, sehingga UI tidak pernah menampilkan [DioException] mentah.
String readableApiError(Object error) {
  if (error is! DioException) {
    if (error is FormatException) {
      return 'Format data dari server tidak dikenali.';
    }
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }

  // Kalau server sempat menjawab, status code adalah sinyal paling spesifik,
  // apa pun tipe transport yang akhirnya terjadi.
  final status = error.response?.statusCode;
  if (status != null) {
    return switch (status) {
      401 => 'Sesi Anda habis. Silakan login kembali.',
      403 => 'Anda tidak punya akses ke data ini.',
      404 => 'Data tidak ditemukan.',
      >= 500 => 'Server sedang bermasalah. Coba lagi nanti.',
      _ => 'Permintaan gagal (HTTP $status).',
    };
  }

  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout =>
      'Koneksi lambat. Coba lagi sebentar.',
    DioExceptionType.connectionError =>
      'Tidak ada koneksi ke server. Cek jaringan Anda.',
    DioExceptionType.badCertificate => 'Sertifikat server tidak valid.',
    DioExceptionType.cancel => 'Permintaan dibatalkan.',
    DioExceptionType.badResponse || DioExceptionType.unknown =>
      'Terjadi masalah jaringan. Periksa koneksi Anda.',
  };
}
