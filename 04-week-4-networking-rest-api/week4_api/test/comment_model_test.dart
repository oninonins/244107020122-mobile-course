// Unit test untuk Comment.fromJson — fokus pada perilaku "safe null"
// terhadap field yang hilang/tidak lengkap.
//
// Catatan: test ini murni unit (tanpa jaringan/Dio), cukup jalankan
// `flutter test test/comment_model_test.dart`.

import 'package:flutter_test/flutter_test.dart';
import 'package:week4_api/data/models/comment.dart';

void main() {
  group('Comment.fromJson', () {
    test('menggunakan default saat semua field hilang', () {
      // Map kosong mensimulasikan response JSON yang tidak lengkap.
      final comment = Comment.fromJson(const {});

      expect(comment.postId, 0, reason: 'postId default harus 0');
      expect(comment.id, 0, reason: 'id default harus 0');
      expect(comment.name, '', reason: 'name default harus string kosong');
      expect(comment.email, '', reason: 'email default harus string kosong');
      expect(comment.body, '', reason: 'body default harus string kosong');
    });

    test('menggunakan default saat sebagian field hilang', () {
      // Hanya postId dan id yang tersedia; name/email/body hilang.
      final comment = Comment.fromJson(const {
        'postId': 3,
        'id': 7,
      });

      expect(comment.postId, 3);
      expect(comment.id, 7);
      expect(comment.name, '', reason: 'name tidak boleh null saat hilang');
      expect(comment.email, '', reason: 'email tidak boleh null saat hilang');
      expect(comment.body, '', reason: 'body tidak boleh null saat hilang');
    });

    test('tidak melempar exception saat field bernilai null', () {
      // JSON bisa memuat key dengan nilai null (bukan sekadar hilang).
      final comment = Comment.fromJson(const {
        'postId': null,
        'id': null,
        'name': null,
        'email': null,
        'body': null,
      });

      expect(comment.postId, 0);
      expect(comment.id, 0);
      expect(comment.name, '');
      expect(comment.email, '');
      expect(comment.body, '');
    });

    test('mengonversi angka desimal ke int dan membaca semua field', () {
      // JSONPlaceholder mengirim int, tetapi safe-parse juga mendukung
      // angka berbentuk double (mis. 1.0) tanpa crash.
      final comment = Comment.fromJson(const {
        'postId': 1,
        'id': 2,
        'name': 'Ida',
        'email': 'ida@example.com',
        'body': 'Komentar luar biasa',
      });

      expect(comment.postId, 1);
      expect(comment.id, 2);
      expect(comment.name, 'Ida');
      expect(comment.email, 'ida@example.com');
      expect(comment.body, 'Komentar luar biasa');
    });
  });
}