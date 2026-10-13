import 'package:flutter/material.dart';

import '../routes.dart';

class AnnouncementPage extends StatelessWidget {
  const AnnouncementPage({super.key, required this.id});

  /// Berasal dari `/pengumuman/:id`, termasuk id yang dibawa `data.route`
  /// pada payload FCM.
  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pengumuman #$id')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jadwal kuliah berubah',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Kelas Mobile pindah ke Ruang A2 jam 13.00'),
            const Spacer(),
            Text(
              'Halaman ini dibuka dari deep link notifikasi '
              '(data.route = ${Routes.announcementDetail(id)}).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
