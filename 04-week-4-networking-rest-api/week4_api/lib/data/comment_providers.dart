import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/comment.dart';
import 'providers.dart';
import 'repositories/comment_repository.dart';

/// Provider untuk instance [CommentRepository].
/// Depend hanya ke [dioProvider] yang sudah dibuat di `providers.dart`.
final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => CommentRepository(ref.watch(dioProvider)),
);

/// Notifier async untuk daftar komentar sebuah post.
///
/// Riverpod 3 mengirim argumen family lewat KONSTRUKTOR (bukan via `arg`),
/// jadi [postId] disimpan sebagai field instance.
class CommentListNotifier extends AsyncNotifier<List<Comment>> {
  CommentListNotifier(this.postId);

  /// id post yang komentarnya akan dimuat (argumen family).
  final int postId;

  /// Inisialisasi state secara async.
  ///
  /// Saat provider pertama kali di-watch, method ini dijalankan.
  /// Jika melempar error (mis. DioException / TimeoutException), Riverpod
  /// otomatis mengubah state menjadi `AsyncError` — tanpa try-catch manual.
  @override
  Future<List<Comment>> build() async {
    final repository = ref.watch(commentRepositoryProvider);
    return repository.fetchComments(postId: postId);
  }

  /// Memuat ulang data (untuk tombol refresh / pull-to-refresh).
  /// Pola yang sama dengan PostListNotifier.refresh di providers.dart.
  Future<void> refresh() async {
    // Kembalikan ke state loading supaya UI menampilkan indikator.
    state = const AsyncLoading();
    try {
      final repository = ref.read(commentRepositoryProvider);
      // Sukses -> AsyncData berisi daftar komentar.
      state = AsyncData(await repository.fetchComments(postId: postId));
    } catch (e, st) {
      // Gagal -> AsyncError; UI membacanya lewat `when(error:)`.
      state = AsyncError(e, st);
    }
  }
}

/// Provider family: `commentListProvider(postId)` menghasilkan state
/// `AsyncValue<List<Comment>>` untuk post dengan id tertentu.
final commentListProvider =
    AsyncNotifierProvider.family<CommentListNotifier, List<Comment>, int>(
  CommentListNotifier.new,
  // Nonaktifkan retry otomatis agar error langsung final (AsyncError)
  // dan mudah diuji/diperlihatkan ke pengguna. Pola sama dengan
  // `postListProvider` di providers.dart.
  retry: (retryCount, error) => null,
);

/// Pemetaan error menjadi pesan ramah pengguna.
/// Logika lengkap dipinjam dari `friendlyErrorMessage` yang sudah ada
/// di providers.dart (menangani timeout, connection error, 404, 500, DLL)
/// sehingga tidak ada duplikasi antar repository.
String friendlyCommentErrorMessage(Object error) =>
    friendlyErrorMessage(error);