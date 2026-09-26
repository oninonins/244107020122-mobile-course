import 'package:flutter/material.dart';

/// Badge kecil bertuliskan "belum tersinkron".
/// Dipakai pada baris dan halaman detail catatan yang masih dirty.
class UnsavedBadge extends StatelessWidget {
  const UnsavedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'belum tersinkron',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}