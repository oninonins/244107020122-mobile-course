import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../routes.dart';
import '../providers/announcement_providers.dart';

/// Halaman tujuan deep link notifikasi.
///
/// Isi teksnya TIDAK lagi ditulis langsung di sini. Semula `'Jadwal kuliah
/// berubah'` dan `'Kelas Mobile pindah ke Ruang A2 jam 13.00'` ada sebagai
/// string di dalam widget; sekarang diambil lewat use case dari
/// `MockAnnouncementRepository`.
///
/// Teksnya sengaja dibuat identik — pemindahan ini tidak boleh mengubah apa pun
/// yang dilihat pengguna.
class AnnouncementPage extends ConsumerWidget {
  const AnnouncementPage({super.key, required this.id});

  /// Berasal dari `/pengumuman/:id`, termasuk id yang dibawa `data.route`
  /// pada payload FCM.
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(announcementProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text('Pengumuman #$id')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (result) {
            final announcement = result.announcement;
            if (announcement == null) {
              return Center(
                child: Text(
                  result.failure?.message ?? 'Pengumuman tidak tersedia.',
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(announcement.body),
                const Spacer(),
                Text(
                  'Halaman ini dibuka dari deep link notifikasi '
                  '(data.route = ${Routes.announcementDetail(id)}).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
