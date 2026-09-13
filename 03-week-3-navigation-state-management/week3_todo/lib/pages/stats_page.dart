// Halaman statistik dengan state asinkron (Riverpod AsyncValue).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/stats_provider.dart';

/// [ConsumerWidget] adalah widget yang bisa membaca provider Riverpod.
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `ref.watch` membuat widget otomatis rebuild setiap kali status
    // provider berubah (loading → data / error).
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      // `.when(...)` memecah AsyncValue menjadi tiga kasus, sehingga UI wajib
      // menangani semuanya dan tidak akan pernah blank saat proses terjadi.
      body: statsAsync.when(
        // 1. Loading — proses masih berjalan → spinner.
        loading: () => const Center(child: CircularProgressIndicator()),

        // 2. Error — tampilkan pesan + tombol retry agar pengguna bisa coba lagi.
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat: $err'),
              const SizedBox(height: 12),
              FilledButton(
                // `retry()` memuat ulang: loading → sukses / error lagi.
                onPressed: () => ref.read(statsProvider.notifier).retry(),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),

        // 3. Sukses — data siap → daftar 3 item statistik.
        data: (stats) => ListView.builder(
          itemCount: stats.length,
          itemBuilder: (context, index) => ListTile(
            leading: const Icon(Icons.bar_chart),
            title: Text(stats[index]),
          ),
        ),
      ),
    );
  }
}