import 'package:go_router/go_router.dart';

import 'pages/note_detail_page.dart';
import 'pages/notes_page.dart';

/// Konfigurasi routing aplikasi memakai GoRouter (URL-based).
///
///   `/`          -> halaman utama dengan daftar catatan.
///   `/note/:id`  -> halaman detail satu catatan; `id` diambil dari path.
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const NotesPage(),
    ),
    GoRoute(
      path: '/note/:id',
      builder: (context, state) {
        // Path parameter selalu string; dikonversi ke int untuk provider.
        final id = int.parse(state.pathParameters['id']!);
        return NoteDetailPage(noteId: id);
      },
    ),
  ],
);