import 'package:go_router/go_router.dart';
import 'pages/paged_post_page.dart';
import 'pages/post_detail_page.dart';

/// Konfigurasi routing aplikasi memakai GoRouter (URL-based).
///
///   `/`          -> halaman utama dengan daftar post berpaginasi.
///   `/post/:id`  -> halaman detail satu post; `id` diambil dari path.
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PagedPostPage(),
    ),
    GoRoute(
      path: '/post/:id',
      builder: (context, state) {
        // Path parameter selalu string; dikonversi ke int untuk provider.
        final id = int.parse(state.pathParameters['id']!);
        return PostDetailPage(postId: id);
      },
    ),
  ],
);