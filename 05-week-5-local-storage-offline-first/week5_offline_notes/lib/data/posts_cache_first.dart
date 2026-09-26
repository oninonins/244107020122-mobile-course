import 'dart:async';

import 'package:dio/dio.dart';

import 'models/post.dart';
import 'repositories/cached_posts_repository.dart';
import 'repositories/posts_remote_repository.dart';

/// Alur cache-first untuk data API.
///
/// Dua fungsi ini dipisah agar mudah diuji dan dipakai dari provider:
/// [loadPostsCacheFirst] menjawab seketika dari cache, sementara
/// [refreshPostsInBackground] memperbarui cache di background tanpa
/// memblokir return pertama.

/// 1. Segera kembalikan cache agar UI tidak blank saat offline.
/// 2. Di background: fetch Dio lalu simpan ke `cached_posts`.
Future<List<Post>> loadPostsCacheFirst({
  required CachedPostsRepository cache,
  required PostsRemoteRepository remote,
  void Function()? onRefreshed,
}) async {
  final cached = await cache.readCachedPosts();
  unawaited(
    refreshPostsInBackground(
      cache: cache,
      remote: remote,
      onRefreshed: onRefreshed,
    ),
  );
  return cached;
}

/// Mengambil posts dari jaringan lalu menyimpannya sebagai cache baru.
/// Kegagalan jaringan (DioException) sengaja ditelan: aplikasi tetap
/// memakai cache lama, dan tidak ada error yang bocor ke UI.
Future<void> refreshPostsInBackground({
  required CachedPostsRepository cache,
  required PostsRemoteRepository remote,
  void Function()? onRefreshed,
}) async {
  try {
    final posts = await remote.fetchPosts();
    await cache.saveCachedPosts(posts);
  } on DioException {
    return;
  }
  // Setelah cache segar tersimpan, beri tahu provider (lewat callback)
  // agar state dibangun ulang dan UI menampilkan data terbaru.
  onRefreshed?.call();
}