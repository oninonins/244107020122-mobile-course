import 'package:dio/dio.dart';

import '../models/post.dart';

/// Mengambil data posts dari server (JSONPlaceholder).
/// Lapisan ini satu-satunya yang berhubungan langsung dengan Dio
/// untuk endpoint posts; UI tidak pernah memanggilnya secara langsung.
class PostsRemoteRepository {
  PostsRemoteRepository(this._dio);

  final Dio _dio;

  /// Mengambil seluruh posts: `GET /posts`.
  /// Exception dari Dio (mis. offline) diteruskan ke pemanggil,
  /// dan tidak dipakai dalam perbandingan jumlah hasil.
  Future<List<Post>> fetchPosts() async {
    final response = await _dio.get<List>('/posts');
    final data = response.data ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Post.fromJson)
        .toList();
  }
}