// Provider data statistik asinkron.
//
// Pola yang dipakai: AsyncNotifier + AsyncValue.
// AsyncValue<T> memodelkan tiga kemungkinan state asinkron sekaligus:
//   - loading  (proses masih berjalan)
//   - error    (gagal, membawa exception)
//   - success  (data siap)
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [StatsNotifier] adalah [AsyncNotifier], sehingga `state`-nya selalu berupa
/// [AsyncValue<List<String>>] dan bisa menampung loading/error/sukses.
class StatsNotifier extends AsyncNotifier<List<String>> {
  // Konstruktor menerima parameter agar mudah diuji (bisa disuntik):
  // - [failureRate]  : peluang gagal (0.0–1.0), default 0.3 = 30% sesuai soal.
  // - [delay]        : simulasi lama proses jaringan, default 2 detik.
  // - [random]       : sumber angka acak; di test bisa diganti tiruan agar
  //                    hasilnya deterministik (tidak bergantung waktu nyata).
  StatsNotifier({
    this.failureRate = 0.3,
    this.delay = const Duration(seconds: 2),
    Random? random,
  }) : _random = random ?? Random();

  final double failureRate;
  final Duration delay;
  final Random _random;

  /// `build()` dipanggil otomatis oleh Riverpod saat provider pertama dibaca.
  /// Jika melempar exception, Riverpod otomatis mengubahnya menjadi [AsyncError]
  /// sehingga UI bisa membaca cabang `error` — tanpa blok try/catch manual.
  @override
  Future<List<String>> build() => _load();

  /// Dipanggil tombol "Coba lagi" di UI error.
  /// 1) Set state jadi loading dulu supaya spinner terlihat,
  /// 2) lalu [AsyncValue.guard] menjalankan `_load()` dan otomatis menangkap
  ///    exception yang muncul menjadi [AsyncError].
  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Simulasi pengambilan data statistik dari network/API:
  /// menunggu beberapa detik, kadang gagal (sesuai [failureRate]),
  /// dan jika berhasil mengembalikan 3 item statistik.
  Future<List<String>> _load() async {
    await Future.delayed(delay);

    // 30% kemungkinan gagal — di sini `nextDouble()` menghasilkan 0.0–1.0.
    if (_random.nextDouble() < failureRate) {
      throw Exception('Gagal memuat statistik');
    }

    return const [
      'Pengguna aktif: 142',
      'Order hari ini: 23',
      'Rating rata-rata: 4.7',
    ];
  }
}

/// Satu-satunya provider untuk state statistik.
/// [AsyncNotifierProvider] menciptakan dan mengelola [StatsNotifier].
final statsProvider =
    AsyncNotifierProvider<StatsNotifier, List<String>>(StatsNotifier.new);