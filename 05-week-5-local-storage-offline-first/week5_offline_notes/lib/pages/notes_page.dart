import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../widgets/note_tile.dart';

/// Halaman utama: daftar catatan lokal.
///
/// Sumber data hanya lewat provider (notesListProvider), bukan
/// repository atau database secara langsung.
class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan'),
        actions: [
          IconButton(
            tooltip: 'Sinkronkan catatan kotor',
            icon: const Icon(Icons.sync),
            onPressed: () => _syncNow(context, ref),
          ),
        ],
      ),
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat catatan: $error')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Belum ada catatan.'))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final note = items[index];
                  return NoteTile(
                    note: note,
                    onTap: () => context.go('/note/${note.id}'),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNote(context, ref),
        tooltip: 'Tambah catatan',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Catatan baru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Judul catatan'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    final value = title?.trim() ?? '';
    if (value.isEmpty) return;
    await ref.read(notesListProvider.notifier).addNote(title: value);
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final count = await ref.read(syncNotesProvider.notifier).syncNow();
    // Setelah markAllSynced, muat ulang daftar agar badge hilang.
    ref.invalidate(notesListProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count catatan disinkronkan')),
    );
  }
}