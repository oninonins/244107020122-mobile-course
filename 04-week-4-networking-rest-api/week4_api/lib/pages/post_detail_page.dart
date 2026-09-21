import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/network_errors.dart';
import '../data/providers.dart';

/// Halaman detail satu post (rute `/post/:id`).
///
/// Menggunakan [postDetailProvider] yang membaca data dari list yang sudah
/// dimuat (halaman list/paged) atau mengambil lewat repository bila halaman
/// dibuka langsung. State berupa `AsyncValue` sehingga loading dan error
/// ditangani deklaratif.
class PostDetailPage extends ConsumerWidget {
  const PostDetailPage({super.key, required this.postId});

  /// id post yang ditampilkan, diambil dari path parameter rute.
  final int postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(postDetailProvider(postId));

    return Scaffold(
      appBar: AppBar(title: Text('Post #$postId')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(friendlyErrorMessage(err), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                // Coba lagi cukup meng-invalidate provider detail agar
                // di-fetch ulang (list sudah dimuat pun tetap aman).
                FilledButton(
                  onPressed: () => ref.invalidate(postDetailProvider(postId)),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (post) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Judul ditampilkan penuh (tanpa ellipsis) di halaman detail.
              Text(
                post.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(height: 32),
              // Body ditampilkan lengkap, tidak dipotong.
              Text(post.body, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}