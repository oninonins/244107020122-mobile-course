import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models/post.dart';
import 'posts_cache_first.dart';
import 'repositories/cached_posts_repository.dart';
import 'repositories/note_repository.dart';
import 'repositories/posts_remote_repository.dart';
import 'sync.dart';

final dioProvider = Provider<Dio>((ref) => createDio());

final postsRemoteRepositoryProvider = Provider<PostsRemoteRepository>(
  (ref) => PostsRemoteRepository(ref.watch(dioProvider)),
);

final cachedPostsRepositoryProvider = Provider<CachedPostsRepository>(
  (ref) => CachedPostsRepository(),
);

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(),
);

/// Provider cache-first untuk daftar posts.
///
/// Saat pertama kali dibangun, data langsung dijawab dari cache lokal
/// (agar UI tidak blank saat offline). Refresh di background berjalan
/// tanpa memblokir; ketika selesai, provider di-invalidate sehingga
/// state dibangun ulang dari cache yang sudah terbarui.
final postsCacheFirstProvider =
    AsyncNotifierProvider<PostsCacheFirstNotifier, List<Post>>(
        PostsCacheFirstNotifier.new);

class PostsCacheFirstNotifier extends AsyncNotifier<List<Post>> {
  @override
  Future<List<Post>> build() {
    final cache = ref.watch(cachedPostsRepositoryProvider);
    final remote = ref.watch(postsRemoteRepositoryProvider);
    return loadPostsCacheFirst(
      cache: cache,
      remote: remote,
      onRefreshed: () {
        ref.invalidateSelf();
      },
    );
  }
}

/// Provider sinkronisasi catatan dirty.
///
/// State awal null (belum pernah disinkronkan). Nilai int? menyimpan
/// hasil [SyncNotesNotifier.syncNow], yaitu jumlah catatan yang
/// berhasil disinkronkan (0 bila tidak ada catatan dirty).
final syncNotesProvider =
    AsyncNotifierProvider<SyncNotesNotifier, int?>(SyncNotesNotifier.new);

class SyncNotesNotifier extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async => null;

  /// Menjalankan sinkronisasi catatan dirty.
  /// Saat berjalan, [syncNotes] mensimulasikan upload lalu menandai
  /// semua catatan bersih; hasilnya adalah jumlah catatan terkirim.
  Future<int> syncNow() async {
    final repo = ref.read(noteRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard<int?>(
      () async => await syncNotes(repo),
    );
    // Riverpod 3: pakai .value (valueOrNull sudah dihapus).
    return state.value ?? 0;
  }
}