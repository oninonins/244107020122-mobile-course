import 'package:campus_notify/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fungsi di `core/format.dart` murni: tanpa Flutter, tanpa plugin. Karena itu
/// `test()` sudah cukup — tanpa `pumpWidget`, tanpa `HomePage`, tanpa Firebase.
///
/// Catatan: test seperti ini mengimpor fungsi asli dari `lib/`, bukan menyalin
/// logikanya ke dalam file test. Kalau fungsinya disalin, test tetap hijau
/// walau `format.dart` rusak atau dihapus — persis kesalahan yang terjadi di
/// `auth_push_test.dart` Week 6 sebelum diperbaiki.
void main() {
  group('maskToken', () {
    test('memotong token panjang jadi 12 karakter pertama', () {
      expect(maskToken('mock-access-token-1234567890.sig'), 'mock-access-...');
    });

    test('menandai token kosong dan null, tidak melempar', () {
      expect(maskToken(null), '(kosong)');
      expect(maskToken(''), '(kosong)');
    });

    test('token yang lebih pendek dari batas tetap ditandai', () {
      expect(maskToken('abc'), 'abc...');
    });

    test('batas tampilan bisa diubah', () {
      expect(maskToken('abcdefghij', visible: 4), 'abcd...');
    });

    test('tidak pernah membocorkan isi token penuh', () {
      const secret = 'mock-access-token-1234567890.sig';
      final masked = maskToken(secret);
      expect(masked.contains(secret), isFalse);
      expect(masked.length, lessThan(secret.length));
    });
  });

  group('formatClock', () {
    test('menyamakan panjang dua digit', () {
      expect(formatClock(DateTime(2026, 9, 27, 7, 5, 3)), '07:05:03');
    });

    test('null menjadi tanda hubung, bukan "null"', () {
      expect(formatClock(null), '-');
    });

    test('tidak butuh locale plugin', () {
      // Kalau suatu saat implementasi dipecah ke `intl`, test ini yang
      // reminds us that the output format changed.
      expect(formatClock(DateTime(2026, 1, 1, 0, 0, 0)), '00:00:00');
    });
  });

  group('formatDate', () {
    test('memakai nama bulan lokal', () {
      expect(formatDate(DateTime(2026, 9, 27)), '27 Sep 2026');
      expect(formatDate(DateTime(2026, 5, 1)), '01 Mei 2026');
    });

    test('null menjadi tanda hubung', () {
      expect(formatDate(null), '-');
    });
  });

  group('emailFromRefresh', () {
    test('mengambil email dari refresh token mock', () {
      expect(
        emailFromRefresh('refresh:mhs@polinema.ac.id|1756320000000'),
        'mhs@polinema.ac.id',
      );
    });

    test('mengembalikan null untuk format yang tidak dikenali', () {
      // Mengembalikan null, bukan melempar: satu token aneh tidak boleh
      // menjatuhkan seluruh kartu debug.
      expect(emailFromRefresh(null), isNull);
      expect(emailFromRefresh(''), isNull);
      expect(emailFromRefresh('token-asli-dari-server'), isNull);
      expect(emailFromRefresh('refresh:'), isNull);
    });

    test('mengambil bagian sebelum pipe pertama', () {
      expect(emailFromRefresh('refresh:a@b.ac.id|1|2|3'), 'a@b.ac.id');
    });
  });
}
