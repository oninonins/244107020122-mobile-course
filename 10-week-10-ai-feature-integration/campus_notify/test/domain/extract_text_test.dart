import 'dart:typed_data';

import 'package:campus_notify/core/failures.dart';
import 'package:campus_notify/features/ocr/domain/entities/ocr_result.dart';
import 'package:campus_notify/features/ocr/domain/repositories/ocr_repository.dart';
import 'package:campus_notify/features/ocr/domain/usecases/extract_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository palsu. Tidak ada jaringan, tidak ada Dio.
///
/// Sama seperti fake di Week 7: TIDAK memakai `throw UnimplementedError()`,
/// karena itu melanggar Liskov Substitution. Semua metode mengembalikan record
/// yang wajar, sehingga fake benar-benar bisa menggantikan implementasi asli.
class FakeOcrRepository implements OcrRepository {
  FakeOcrRepository({this.result, this.failure});

  final OcrResult? result;
  final Failure? failure;
  int calls = 0;

  @override
  Future<({OcrResult? result, Failure? failure})> extractText({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    calls++;
    if (failure != null) return (result: null, failure: failure);
    return (result: result, failure: null);
  }
}

Uint8List _bytes(int length) => Uint8List(length);

void main() {
  const okResult = OcrResult(
    text: 'Jadwal kuliah berubah',
    model: 'google/gemma-4-31b-it:free',
  );

  group('ExtractText meneruskan hasil', () {
    test('gambar valid menghasilkan teks', () async {
      final repo = FakeOcrRepository(result: okResult);
      final result = await ExtractText(repo)
          .call(imageBytes: _bytes(1024), mimeType: 'image/jpeg');

      expect(result.failure, isNull);
      expect(result.result?.text, 'Jadwal kuliah berubah');
      expect(repo.calls, 1);
    });

    test('kegagalan repository diteruskan tanpa melempar', () async {
      final repo = FakeOcrRepository(
        failure: const AiFailure('API key ditolak.', quotaExceeded: false),
      );
      final result = await ExtractText(repo)
          .call(imageBytes: _bytes(1024), mimeType: 'image/png');

      expect(result.result, isNull);
      expect(result.failure, isA<AiFailure>());
      expect(result.failure?.message, 'API key ditolak.');
    });
  });

  group('validasi berjalan sebelum repository dipanggil', () {
    test('gambar kosong ditolak', () async {
      final repo = FakeOcrRepository(result: okResult);
      final result = await ExtractText(repo)
          .call(imageBytes: Uint8List(0), mimeType: 'image/jpeg');

      expect(result.failure, isA<ValidationFailure>());
      expect(repo.calls, 0, reason: 'repository tidak boleh dipanggil');
    });

    test('format tidak didukung ditolak', () async {
      final repo = FakeOcrRepository(result: okResult);
      final result = await ExtractText(repo)
          .call(imageBytes: _bytes(1024), mimeType: 'application/pdf');

      expect(result.failure?.message, contains('tidak didukung'));
      expect(repo.calls, 0);
    });

    test('gambar di atas 4 MB ditolak', () async {
      final repo = FakeOcrRepository(result: okResult);
      final result = await ExtractText(repo).call(
        imageBytes: _bytes(ExtractText.maxBytes + 1),
        mimeType: 'image/jpeg',
      );

      expect(result.failure, isA<ValidationFailure>());
      expect(result.failure?.message, contains('terlalu besar'));
      expect(repo.calls, 0);
    });

    test('gambar tepat 4 MB masih diterima', () async {
      final repo = FakeOcrRepository(result: okResult);
      final result = await ExtractText(
        repo,
      ).call(imageBytes: _bytes(ExtractText.maxBytes), mimeType: 'image/webp');

      expect(result.failure, isNull);
      expect(repo.calls, 1);
    });
  });

  group('OcrResult', () {
    test('teks berisi spasi saja dianggap kosong', () {
      expect(const OcrResult(text: '   \n ', model: 'm').isEmpty, isTrue);
      expect(const OcrResult(text: 'ada isi', model: 'm').isEmpty, isFalse);
    });
  });
}
