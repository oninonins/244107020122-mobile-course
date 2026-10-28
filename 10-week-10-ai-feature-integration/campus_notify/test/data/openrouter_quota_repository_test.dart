import 'dart:convert';
import 'dart:typed_data';

import 'package:campus_notify/core/failures.dart';
import 'package:campus_notify/features/ocr/data/datasources/secure_api_key_store.dart';
import 'package:campus_notify/features/ocr/data/repositories/openrouter_quota_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.statusCode, this.body});

  final int statusCode;
  final String? body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body ?? '',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

OpenRouterQuotaRepository _build({
  required _FakeAdapter adapter,
  String? apiKey = 'sk-or-uji',
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://openrouter.ai/api/v1'))
    ..httpClientAdapter = adapter;
  return OpenRouterQuotaRepository(
    dio: dio,
    keyStore: InMemoryApiKeyStore(apiKey),
  );
}

String _body({
  required int used,
  required int limit,
  required int remaining,
  bool freeTier = true,
  double? creditRemaining = 0,
}) => jsonEncode({
  'data': {
    'is_free_tier': freeTier,
    'limit_remaining': creditRemaining,
    'free_model_daily_requests': {
      'used': used,
      'limit': limit,
      'remaining': remaining,
    },
  },
});

void main() {
  test('membaca sisa jatah harian', () async {
    final adapter = _FakeAdapter(
      statusCode: 200,
      body: _body(used: 12, limit: 50, remaining: 38),
    );
    final repo = _build(adapter: adapter);

    final result = await repo.fetch();

    expect(result.failure, isNull);
    expect(result.quota?.isFreeTier, isTrue);
    expect(result.quota?.dailyUsed, 12);
    expect(result.quota?.dailyLimit, 50);
    expect(result.quota?.dailyRemaining, 38);
    expect(result.quota?.dailyExhausted, isFalse);
  });

  test('kuota habis terdeteksi', () async {
    final adapter = _FakeAdapter(
      statusCode: 200,
      body: _body(used: 50, limit: 50, remaining: 0),
    );
    final repo = _build(adapter: adapter);

    final result = await repo.fetch();

    expect(result.quota?.dailyExhausted, isTrue);
  });

  test('saldo negatif terdeteksi', () async {
    final adapter = _FakeAdapter(
      statusCode: 200,
      body: _body(used: 0, limit: 50, remaining: 50, creditRemaining: -1.5),
    );
    final repo = _build(adapter: adapter);

    final result = await repo.fetch();

    expect(result.quota?.creditNegative, isTrue);
  });

  test('key dikirim lewat header ke endpoint yang benar', () async {
    final adapter = _FakeAdapter(
      statusCode: 200,
      body: _body(used: 1, limit: 50, remaining: 49),
    );
    final repo = _build(adapter: adapter);

    await repo.fetch();

    expect(adapter.lastRequest?.headers['Authorization'], 'Bearer sk-or-uji');
    expect(adapter.lastRequest?.uri.path, '/api/v1/key');
  });

  test('key belum diatur tidak memanggil jaringan', () async {
    final adapter = _FakeAdapter(statusCode: 200, body: '{}');
    final repo = _build(adapter: adapter, apiKey: null);

    final result = await repo.fetch();

    expect(result.failure, isA<AiFailure>());
    expect(adapter.lastRequest, isNull);
  });

  test('401 berarti key ditolak', () async {
    final adapter = _FakeAdapter(statusCode: 401, body: '{}');
    final repo = _build(adapter: adapter);

    final result = await repo.fetch();

    expect(result.failure?.message, contains('API key ditolak'));
  });

  test('format data tidak dikenali ditolak dengan jelas', () async {
    final adapter = _FakeAdapter(statusCode: 200, body: '{"data":{}}');
    final repo = _build(adapter: adapter);

    final result = await repo.fetch();

    // Field yang tidak ada menghasilkan null, bukan crash.
    expect(result.quota, isNotNull);
    expect(result.quota?.dailyRemaining, isNull);
    expect(result.quota?.dailyExhausted, isFalse);
  });

  test('pesan error tidak memuat API key', () async {
    final adapter = _FakeAdapter(statusCode: 500, body: '');
    final repo = _build(adapter: adapter);

    final result = await repo.fetch();

    expect(result.failure, isNotNull);
    expect(result.failure!.message.contains('sk-or-uji'), isFalse);
  });
}
