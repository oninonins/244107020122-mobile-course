import 'package:flutter/material.dart';

import '../data/local/note.dart';
import 'unsaved_badge.dart';

/// Baris daftar catatan.
///
/// Menampilkan judul, cuplikan isi, waktu diperbarui, dan badge
/// "belum tersinkron" bila catatan masih bertanda dirty.
class NoteTile extends StatelessWidget {
  const NoteTile({super.key, required this.note, this.onTap});

  final Note note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${note.body.replaceAll('\n', ' ')}\n${_formatTime(note.updatedAt)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: note.dirty ? const UnsavedBadge() : null,
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