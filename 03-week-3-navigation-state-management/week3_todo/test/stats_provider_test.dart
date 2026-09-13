// Unit test untuk StatsNotifier (provider statistik asinkron).
//
// Test memakai ProviderContainer (bukan widget) sehingga langsung menguji
// logika notifier tanpa memerlukan layar. `statsProvider.overrideWith(...)`
// dipakai untuk menyuntik notifier dengan konfigurasi deterministik:
// delay nol (agar test cepat), peluang gagal tertentu, dan sumber acak tiruan
// (agar hasil sukses/gagal dapat diprediksi).

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:week3_todo/providers/stats_provider.dart';

/// Tiruan [Random] yang mengembalikan urutan nilai `nextDouble()` yang sudah
/// ditentukan sebelumnya. Dengan ini test bisa "memprogram" kapan notifier
/// gagal (nilai < 0.3) dan kapan sukses (nilai >= 0.3).
class _ScriptedRandom implements Random {
  _ScriptedRandom(this.values);

  final List<double> values;
  int _index = 0;

  @override
  double nextDouble() => values[_index++ % values.length];

  // Dua metode di bawah tidak dipakai oleh StatsNotifier, cukup buang exception.
  @override
  bool nextBool() => throw UnimplementedError();

  @override
  int nextInt(int max) => throw UnimplementedError();
}

void main() {
  group('StatsNotifier', () {
    // Helper untuk membuat container dengan provider yang di-override.
    // addTearDown menjamin container dibuang setelah setiap test selesai.
    ProviderContainer createContainer(StatsNotifier Function() create) {
      final container = ProviderContainer(
        overrides: [statsProvider.overrideWith(create)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('state awal adalah AsyncLoading selama build belum selesai', () async {
      final container = createContainer(
        () => StatsNotifier(failureRate: 0, delay: Duration.zero),
      );

      // Read pertama memicu build; karena build bersifat async, state saat itu
      // masih AsyncLoading (isLoading true), belum AsyncData/AsyncError.
      final state = container.read(statsProvider);
      expect(state.isLoading, isTrue);

      // Biarkan future selesai supaya tidak ada timer yang masih tertunda.
      await container.read(statsProvider.future);
    });

    test('sukses: build mengembalikan 3 item statistik', () async {
      final container = createContainer(
        // failureRate 0 → dijamin tidak pernah gagal.
        () => StatsNotifier(failureRate: 0, delay: Duration.zero),
      );

      // `.future` menunggu build selesai dan melempar bila build error.
      final stats = await container.read(statsProvider.future);

      expect(stats, hasLength(3));
      expect(stats, contains('Pengguna aktif: 142'));

      // Setelah selesai, state harus AsyncData berisi daftar yang sama.
      expect(container.read(statsProvider).value, stats);
    });

    test('gagal: exception pada build menjadi AsyncError', () async {
      final container = createContainer(
        // failureRate 1 → dijamin selalu gagal.
        () => StatsNotifier(failureRate: 1, delay: Duration.zero),
      );

      // Future ditolak karena build melempar Exception.
      await expectLater(
        container.read(statsProvider.future),
        throwsA(isA<Exception>()),
      );

      final state = container.read(statsProvider);
      expect(state.hasError, isTrue);
      expect(state.error.toString(), contains('Gagal memuat statistik'));
    });

    test('retry: build pertama gagal, lalu retry() berhasil', () async {
      // Urutan acak: 0.1 (di bawah 0.3 → gagal), lalu 0.9 (berhasil).
      final container = createContainer(
        () => StatsNotifier(
          random: _ScriptedRandom([0.1, 0.9]),
          delay: Duration.zero,
        ),
      );

      // Build pertama: gagal → AsyncError.
      await expectLater(container.read(statsProvider.future), throwsException);
      expect(container.read(statsProvider).hasError, isTrue);

      // retry() menjalankan ulang _load(); nilai acak berikutnya 0.9 → sukses.
      await container.read(statsProvider.notifier).retry();

      final state = container.read(statsProvider);
      expect(state.isLoading, isFalse);
      expect(state.hasValue, isTrue);
      expect(state.value, hasLength(3));
    });
  });
}
