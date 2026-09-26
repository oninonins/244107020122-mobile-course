import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../widgets/unsaved_badge.dart';

/// Halaman detail satu catatan.
///
/// Read-only: membaca langsung dari repository lokal melalui
/// noteDetailProvider (bukan dari state halaman list).
class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({super.key, required this.noteId});

  final int noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(noteDetailProvider(noteId));
    final timeStyle = Theme.of(context).textTheme.bodySmall;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Catatan')),
      body: note.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat catatan: $error')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Catatan tidak ditemukan.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (data.dirty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: UnsavedBadge(),
                  ),
                ),
              Text(data.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(data.body, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              Text(
                'Diperbarui ${_formatTime(data.updatedAt)}',
                style: timeStyle,
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$dd/$mo/${local.year} $hh:$mm';
  }
}