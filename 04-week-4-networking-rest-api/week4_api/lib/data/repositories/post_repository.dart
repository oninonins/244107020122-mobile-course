import 'package:dio/dio.dart';
import '../models/post.dart';

class PostRepository {
  PostRepository(this._dio);
  final Dio _dio;

  Future<List<Post>> fetchPosts() async {
    final response = await _dio.get<List>('/posts');
    final data = response.data ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Post.fromJson)
        .toList();
  }

  Future<List<Post>> fetchPostsPage({
    required int page,
    int limit = 10,
  }) async {
    final response = await _dio.get<List>(
      '/posts',
      queryParameters: {'_page': page, '_limit': limit},
    );
    final data = response.data ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Post.fromJson)
        .toList();
  }

  /// Mengambil satu post berdasarkan id: `GET /posts/{id}`.
  /// Dipakai oleh halaman detail ketika list belum dimuat
  /// (misalnya halaman langsung dibuka via URL / deep link).
  Future<Post> fetchPost(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/posts/$id');
    final data = response.data;
    if (data == null) {
      // Safety net: response kosong tidak boleh menghasilkan objek default
      // yang menyesatkan, jadi dilempar sebagai error jaringan.
      throw StateError('Response post $id kosong.');
    }
    return Post.fromJson(data);
  }
}