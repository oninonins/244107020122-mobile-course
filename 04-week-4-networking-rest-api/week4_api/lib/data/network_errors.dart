import 'dart:async';
import 'package:dio/dio.dart';

/// Memetakan error dari lapisan jaringan menjadi pesan yang ramah
/// bagi pengguna (Bahasa Indonesia).
///
/// Fungsinya dipisahkan di file tersendiri agar bisa dipakai ulang oleh
/// semua halaman (paged maupun non-paged) tanpa harus mengimpor file
/// provider yang berat. Hanya berisi logika murni, tanpa dependency lain.
String friendlyErrorMessage(Object error) {
  // TimeoutException dilempar oleh `Future.timeout` (dipakai di
  // CommentRepository.fetchComments). Beda dari DioException.timeout.
  if (error is TimeoutException) {
    return 'Waktu permintaan habis (timeout). Periksa internet Anda lalu coba lagi.';
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi lambat atau timeout. Periksa internet Anda lalu coba lagi.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Periksa internet Anda.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 404) return 'Data tidak ditemukan (404).';
        if (code == 401 || code == 403) {
          return 'Akses ditolak ($code). Periksa kredensial Anda.';
        }
        return 'Server bermasalah ($code). Coba lagi nanti.';
      default:
        return 'Terjadi kesalahan jaringan. Coba lagi.';
    }
  }
  return 'Terjadi kesalahan tak terduga: $error';
}