import 'dart:async';

import 'package:dio/dio.dart';

import 'models/post.dart';
import 'repositories/cached_posts_repository.dart';
import 'repositories/note_repository.dart';
import 'repositories/posts_remote_repository.dart';

/// Alur cache-first untuk data API.
///
/// Dua fungsi ini menjawab seketika dari cache lalu memperbarui cache
/// di background, sehingga UI tidak menunggu jaringan saat offline.
/// Dipisah dari repository agar repository tetap fokus pada CRUD.

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

/// Sinkronisasi catatan kotor (dirty) ke server.
///
/// Codelab ini belum punya backend tulis, jadi server disimulasikan
/// dengan delay. Yang dinilai adalah mekanismenya, bukan servernya:
/// di project nyata, di sinilah tiap catatan dirty dikirim via REST API
/// dan ditandai bersih hanya bila server menjawab 2xx.
Future<int> syncNotes(NoteRepository repo) async {
  final dirtyCount = await repo.countDirty();
  if (dirtyCount == 0) return 0;

  // Simulasi upload: kirim tiap catatan dirty ke server di sini.
  await Future.delayed(const Duration(seconds: 1));

  // Semua catatan terkirim, tandai bersih.
  await repo.markAllSynced();
  return dirtyCount;
}