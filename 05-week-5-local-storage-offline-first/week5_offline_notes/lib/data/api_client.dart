import 'package:dio/dio.dart';

/// Membuat satu instance [Dio] yang konfigurasinya terpusat.
///
/// Base URL dan timeout dipusatkan di sini agar semua repository
/// memakai pengaturan yang sama dan mudah diubah di satu tempat.
Dio createDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    LogInterceptor(requestBody: true, responseBody: false),
  );
  return dio;
}