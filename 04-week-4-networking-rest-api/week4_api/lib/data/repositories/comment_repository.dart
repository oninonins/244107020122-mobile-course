import 'dart:async';
import 'package:dio/dio.dart';
import '../models/comment.dart';

/// Repository untuk mengambil data komentar dari JSONPlaceholder.
/// Memisahkan logika HTTP (Dio) dari lapisan UI/state management,
/// sehingga provider/test cukup bergantung pada repository ini.
class CommentRepository {
  // Dio disuntikkan lewat konstruktor (dependency injection),
  // memudahkan penggantian dengan mock di unit test.
  CommentRepository(this._dio);

  final Dio _dio;

  /// Mengambil daftar komentar milik satu post.
  ///
  /// Mengirim request `GET /comments?postId={postId}`.
  /// Eksekusi dibungkus `.timeout(10 detik)` sebagai bentuk timeout
  /// eksplisit di level repository — jaminan berhenti walau konfigurasi
  /// Dio di tempat lain berubah. Jika melewati batas, melempar
  /// `TimeoutException` (nanti dipetakan jadi pesan ramah).
  Future<List<Comment>> fetchComments({required int postId}) async {
    // `get<List>` artinya kita mengharapkan response body berupa array JSON
    // (JSONPlaceholder `/comments` memang mengembalikan List).
    final response = await _dio
        .get<List>(
          '/comments',
          // postId dikirim sebagai query parameter -> ?postId={id}
          queryParameters: {'postId': postId},
        )
        .timeout(const Duration(seconds: 10));

    // response.data bisa null bila server menjawab tanpa body.
    final data = response.data ?? [];

    // Hanya elemen yang benar-benar Map yang diproses (menghindari error
    // type casting), lalu tiap map diubah menjadi objek Comment.
    return data
        .whereType<Map<String, dynamic>>()
        .map(Comment.fromJson)
        .toList();
  }
}