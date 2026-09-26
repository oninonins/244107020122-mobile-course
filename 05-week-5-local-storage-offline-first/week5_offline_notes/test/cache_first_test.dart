import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/data/models/post.dart';
import 'package:week5_offline_notes/data/repositories/cached_posts_repository.dart';
import 'package:week5_offline_notes/data/repositories/posts_remote_repository.dart';
import 'package:week5_offline_notes/data/sync.dart';

class FakeCachedPostsRepository extends CachedPostsRepository {
  List<Post> toRead = [];
  List<Post>? saved;

  @override
  Future<List<Post>> readCachedPosts() async => toRead;

  @override
  Future<void> saveCachedPosts(List<Post> posts) async {
    saved = posts;
  }
}

class FakePostsRemoteRepository extends PostsRemoteRepository {
  FakePostsRemoteRepository({this.posts = const [], this.fails = false})
      : super(Dio());

  List<Post> posts;
  bool fails;

  @override
  Future<List<Post>> fetchPosts() async {
    if (fails) {
      throw DioException(requestOptions: RequestOptions(path: '/posts'));
    }
    return posts;
  }
}

void main() {
  test('loadPostsCacheFirst mengembalikan cache seketika lalu refresh', () async {
    final cache = FakeCachedPostsRepository()
      ..toRead = [const Post(userId: 1, id: 1, title: 'cache', body: 'x')];
    final remote = FakePostsRemoteRepository(
      posts: [const Post(userId: 1, id: 2, title: 'fresh', body: 'y')],
    );
    final refreshed = Completer<void>();

    final result = await loadPostsCacheFirst(
      cache: cache,
      remote: remote,
      onRefreshed: refreshed.complete,
    );

    // Nilai balik langsung dari cache.
    expect(result.single.id, 1);
    // Background refresh selesai dan menyimpan hasil jaringan.
    await refreshed.future;
    expect(cache.saved!.single.id, 2);
  });

  test('refreshPostsInBackground menelan kegagalan jaringan', () async {
    final cache = FakeCachedPostsRepository();
    final remote = FakePostsRemoteRepository(fails: true);

    await refreshPostsInBackground(cache: cache, remote: remote);

    // Cache lama tidak tertimpa saat offline.
    expect(cache.saved, isNull);
  });
}