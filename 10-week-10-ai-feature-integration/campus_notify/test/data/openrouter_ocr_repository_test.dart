import 'dart:convert';
import 'dart:typed_data';

import 'package:campus_notify/core/failures.dart';
import 'package:campus_notify/features/ocr/data/datasources/secure_api_key_store.dart';
import 'package:campus_notify/features/ocr/data/repositories/openrouter_ocr_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter Dio tiruan. Tidak ada jaringan sama sekali.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.statusCode, this.body, this.headers = const {}});

  final int statusCode;
  final String? body;

  /// Header tambahan pada respons, dipakai untuk menguji `Retry-After` dan
  /// `X-RateLimit-Remaining`.
  final Map<String, String> headers;

  RequestOptions? lastRequest;
  Object? lastData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    lastData = options.data;
    return ResponseBody.fromString(
      body ?? '',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        for (final entry in headers.entries) entry.key: [entry.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({OpenRouterOcrRepository repo, _FakeAdapter adapter}) _build({
  required _FakeAdapter adapter,
  String? apiKey = 'sk-or-uji',
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://openrouter.ai/api/v1'))
    ..httpClientAdapter = adapter;
  final repo = OpenRouterOcrRepository(
    dio: dio,
    keyStore: InMemoryApiKeyStore(apiKey),
  );
  return (repo: repo, adapter: adapter);
}

String _okBody({String text = 'Jadwal kuliah berubah'}) => jsonEncode({
  'model': 'google/gemma-4-31b-it:free',
  'choices': [
    {
      'message': {'role': 'assistant', 'content': text},
    },
  ],
});

void main() {
  final bytes = Uint8List.fromList([1, 2, 3, 4]);

  test('key belum diatur tidak memanggil jaringan', () async {
    final adapter = _FakeAdapter(statusCode: 200, body: _okBody());
    final s = _build(adapter: adapter, apiKey: null);

    final result = await s.repo.extractText(
      imageBytes: bytes,
      mimeType: 'image/jpeg',
    );

    expect(result.result, isNull);
    expect(result.failure, isA<AiFailure>());
    expect(result.failure?.message, contains('API key belum diatur'));
    expect(adapter.lastRequest, isNull, reason: 'tidak boleh ada request');
  });

  test('respons 200 mengembalikan teks dan nama model', () async {
    final adapter = _FakeAdapter(statusCode: 200, body: _okBody());
    final s = _build(adapter: adapter);

    final result = await s.repo.extractText(
      imageBytes: bytes,
      mimeType: 'image/jpeg',
    );

    expect(result.failure, isNull);
    expect(result.result?.text, 'Jadwal kuliah berubah');
    expect(result.result?.model, 'google/gemma-4-31b-it:free');
    expect(result.result?.truncated, isFalse);
  });

  test('key dikirim lewat header, bukan query string', () async {
    final adapter = _FakeAdapter(statusCode: 200, body: _okBody());
    final s = _build(adapter: adapter);

    await s.repo.extractText(imageBytes: bytes, mimeType: 'image/jpeg');

    final request = adapter.lastRequest!;
    expect(request.headers['Authorization'], 'Bearer sk-or-uji');
    expect(request.uri.query, isEmpty, reason: 'key tidak boleh di query');
    expect(request.uri.path, '/api/v1/chat/completions');
  });

  test('gambar dikirim sebagai data URI base64', () async {
    final adapter = _FakeAdapter(statusCode: 200, body: _okBody());
    final s = _build(adapter: adapter);

    await s.repo.extractText(imageBytes: bytes, mimeType: 'image/png');

    final payload = adapter.lastData! as Map<String, Object?>;
    final messages = payload['messages']! as List;
    final userContent = (messages.last as Map)['content'] as List;
    final imagePart = userContent.last as Map;
    final url = (imagePart['image_url'] as Map)['url'] as String;

    expect(url, startsWith('data:image/png;base64,'));
    expect(url, contains(base64Encode(bytes)));
  });

  test('respons 401 dipetakan ke pesan key ditolak', () async {
    final adapter = _FakeAdapter(statusCode: 401, body: '{"error":"nope"}');
    final s = _build(adapter: adapter);

    final result = await s.repo.extractText(
      imageBytes: bytes,
      mimeType: 'image/jpeg',
    );

    expect(result.failure, isA<AiFailure>());
    expect(result.failure?.message, contains('API key ditolak'));
    expect((result.failure as AiFailure).quotaExceeded, isFalse);
  });

  test('429 tanpa bukti kuota tidak diklaim sebagai kuota', () async {
    // Versi pertama kode ini menampilkan "kuota habis" untuk semua 429.
    // Akibatnya pengguna menunggu sia-sia padahal masalahnya bisa lain,
    // misalnya tidak ada provider yang cocok dengan kebijakan data.
    final adapter = _FakeAdapter(statusCode: 429, body: '{"error":"rate"}');
    final s = _build(adapter: adapter);

    final result = await s.repo.extractText(
      imageBytes: bytes,
      mimeType: 'image/jpeg',
    );

    expect(result.failure, isA<AiFailure>());
    expect((result.failure as AiFailure).quotaExceeded, isFalse);
  });

  test('respons 500 dipetakan ke gangguan layanan', () async {
    final adapter = _FakeAdapter(statusCode: 503, body: '');
    final s = _build(adapter: adapter);

    final result = await s.repo.extractText(
      imageBytes: bytes,
      mimeType: 'image/jpeg',
    );

    expect(result.failure?.message, contains('sedang bermasalah'));
  });

  test('JSON tanpa choices ditolak dengan pesan jelas', () async {
    final adapter = _FakeAdapter(statusCode: 200, body: '{"model":"x"}');
    final s = _build(adapter: adapter);

    final result = await s.repo.extractText(
      imageBytes: bytes,
      mimeType: 'image/jpeg',
    );

    expect(result.result, isNull);
    expect(result.failure?.message, contains('tidak mengembalikan hasil'));
  });

  test('jawaban kosong memberi saran memotret ulang', () async {
    final adapter = _FakeAdapter(statusCode: 200, body: _okBody(text: '   '));
    final s = _build(adapter: adapter);

    final result = await s.repo.extractText(
      imageBytes: bytes,
      mimeType: 'image/jpeg',
    );

    expect(result.failure?.message, contains('Tidak ada teks yang terbaca'));
  });

  test('pesan error tidak pernah memuat API key', () async {
    // DioException bisa memuat headers di toString(). Pesan yang dipakai UI
    // disusun dari status dan tipe saja, jadi key tidak boleh ikut.
    final adapter = _FakeAdapter(statusCode: 418, body: 'teapot');
    final s = _build(adapter: adapter);

    final result = await s.repo.extractText(
      imageBytes: bytes,
      mimeType: 'image/jpeg',
    );

    expect(result.failure, isNotNull);
    expect(result.failure!.message.contains('sk-or-uji'), isFalse);
    expect(result.failure!.message.contains('Bearer'), isFalse);
  });

  group('fallback model', () {
    test('payload memakai models array, bukan model tunggal', () async {
      final adapter = _FakeAdapter(statusCode: 200, body: _okBody());
      final s = _build(adapter: adapter);

      await s.repo.extractText(imageBytes: bytes, mimeType: 'image/jpeg');

      final payload = adapter.lastData! as Map<String, Object?>;
      expect(payload.containsKey('model'), isFalse);
      final models = payload['models']! as List;
      expect(models.length, greaterThanOrEqualTo(3));
      expect(models.first, defaultOcrModel);
    });

    test('semua model cadangan gratis, tidak ada yang berbayar', () async {
      // Dokumentasi OpenRouter: kalau daftar berisi model berbayar dan fallback
      // ke sana, request jadi berbayar. Test ini menjaga agar itu tidak terjadi.
      for (final m in freeVisionModels) {
        expect(m.endsWith(':free'), isTrue, reason: '$m bukan model gratis');
      }
    });

    test('model pilihan pengguna tidak dikirim dua kali', () async {
      final adapter = _FakeAdapter(statusCode: 200, body: _okBody());
      final dio = Dio(BaseOptions(baseUrl: 'https://openrouter.ai/api/v1'))
        ..httpClientAdapter = adapter;
      final repo = OpenRouterOcrRepository(
        dio: dio,
        keyStore: InMemoryApiKeyStore('sk-or-uji'),
        model: 'nvidia/nemotron-3.5-super-vl:free',
      );

      await repo.extractText(imageBytes: bytes, mimeType: 'image/jpeg');

      final models = (adapter.lastData! as Map)['models'] as List;
      expect(
        models.where((m) => m == 'nvidia/nemotron-3.5-super-vl:free').length,
        1,
      );
      expect(models.first, 'nvidia/nemotron-3.5-super-vl:free');
    });
  });

  group('membedakan dua sumber 429', () {
    test('X-RateLimit-Remaining 0 berarti kuota harian habis', () async {
      final adapter = _FakeAdapter(
        statusCode: 429,
        body: jsonEncode({
          'error': {'code': 429, 'message': 'Rate limit exceeded'},
        }),
        headers: {'x-ratelimit-remaining': '0'},
      );
      final s = _build(adapter: adapter);

      final result = await s.repo.extractText(
        imageBytes: bytes,
        mimeType: 'image/jpeg',
      );

      final failure = result.failure! as AiFailure;
      expect(failure.quotaExceeded, isTrue);
      expect(failure.message, contains('Kuota harian'));
    });

    test('Retry-After berarti kapasitas provider, bukan kuota', () async {
      final adapter = _FakeAdapter(
        statusCode: 429,
        body: jsonEncode({
          'error': {
            'code': 429,
            'message': 'Provider returned error',
            'metadata': {
              'provider_code': 'rate_limited',
              'remedy_hint': 'Retry after the provider frees capacity.',
            },
          },
        }),
        headers: {'retry-after': '30'},
      );
      final s = _build(adapter: adapter);

      final result = await s.repo.extractText(
        imageBytes: bytes,
        mimeType: 'image/jpeg',
      );

      final failure = result.failure! as AiFailure;
      expect(
        failure.quotaExceeded,
        isFalse,
        reason: 'kapasitas provider bukan kuota pengguna',
      );
      expect(failure.retryAfterSeconds, 30);
      expect(failure.hint, contains('frees capacity'));
      expect(failure.message, 'Provider returned error');
    });

    test('pesan asli penyedia diteruskan, tidak diganti tebakan', () async {
      final adapter = _FakeAdapter(
        statusCode: 429,
        body: jsonEncode({
          'error': {
            'code': 429,
            'message': 'No endpoints found matching your data policy',
          },
        }),
      );
      final s = _build(adapter: adapter);

      final result = await s.repo.extractText(
        imageBytes: bytes,
        mimeType: 'image/jpeg',
      );

      expect(
        result.failure?.message,
        'No endpoints found matching your data policy',
      );
    });
  });

  test('503 bukan kuota', () async {
    final adapter = _FakeAdapter(statusCode: 503, body: '');
    final s = _build(adapter: adapter);

    final result = await s.repo.extractText(
      imageBytes: bytes,
      mimeType: 'image/jpeg',
    );

    expect((result.failure! as AiFailure).quotaExceeded, isFalse);
  });
}
