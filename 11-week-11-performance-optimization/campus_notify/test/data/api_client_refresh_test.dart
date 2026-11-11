import 'dart:convert';
import 'dart:typed_data';

import 'package:campus_notify/core/failures.dart';
import 'package:campus_notify/features/auth/data/api_client.dart';
import 'package:campus_notify/features/auth/data/datasources/secure_token_store.dart';
import 'package:campus_notify/features/auth/domain/entities/auth_session.dart';
import 'package:campus_notify/features/auth/domain/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter Dio tiruan: 401 sekali, lalu 200.
class _UnauthorizedThenOkAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (calls == 1) {
      return ResponseBody.fromString('{"message":"expired"}', 401);
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Auth palsu. Kalau [failRefresh] benar, penukaran refresh ditolak.
class _FakeAuth implements AuthRepository {
  _FakeAuth({this.failRefresh = false});

  final bool failRefresh;
  int refreshCalls = 0;

  @override
  Future<({AuthSession? session, Failure? failure})> refresh(
    String refreshToken,
  ) async {
    refreshCalls++;
    if (failRefresh) return (session: null, failure: null);
    return (
      session: const AuthSession(
        access: 'access-hasil-refresh',
        refresh: 'refresh-hasil-refresh',
      ),
      failure: null,
    );
  }

  @override
  Future<({AuthSession? session, Failure? failure})> login({
    required String email,
    required String password,
  }) async {
    return (
      session: const AuthSession(access: 'a', refresh: 'r'),
      failure: null,
    );
  }
}

void main() {
  ({Dio client, _UnauthorizedThenOkAdapter adapter}) siapkan({
    required InMemoryTokenStore store,
    required _FakeAuth auth,
    void Function()? onRenewed,
    void Function()? onExpired,
  }) {
    final adapter = _UnauthorizedThenOkAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://contoh.test'))
      ..httpClientAdapter = adapter;
    final client = buildApiClient(
      store: store,
      auth: auth,
      inner: dio,
      onSessionRenewed: onRenewed,
      onSessionExpired: onExpired,
    );
    return (client: client, adapter: adapter);
  }

  test('token hasil refresh memberi tahu pembaca lain', () async {
    final store = InMemoryTokenStore();
    await store.save(access: 'access-lama', refresh: 'refresh-lama');

    final auth = _FakeAuth();
    var renewed = 0;
    var expired = 0;
    final s = siapkan(
      store: store,
      auth: auth,
      onRenewed: () => renewed++,
      onExpired: () => expired++,
    );

    final response = await s.client.get<dynamic>('/devices');

    expect(response.statusCode, 200);
    expect(s.adapter.calls, 2, reason: 'satu request awal, satu retry');
    expect(auth.refreshCalls, 1);
    expect(await store.readAccess(), 'access-hasil-refresh');
    expect(renewed, 1, reason: 'onSessionRenewed harus dipanggil sekali');
    expect(expired, 0, reason: 'sesi tidak boleh dianggap kedaluwarsa');
  });

  test(
    'refresh gagal memicu onSessionExpired, bukan onSessionRenewed',
    () async {
      final store = InMemoryTokenStore();
      await store.save(access: 'access-lama', refresh: 'refresh-lama');

      var renewed = 0;
      var expired = 0;
      final s = siapkan(
        store: store,
        auth: _FakeAuth(failRefresh: true),
        onRenewed: () => renewed++,
        onExpired: () => expired++,
      );

      await expectLater(
        s.client.get<dynamic>('/devices'),
        throwsA(isA<DioException>()),
      );

      expect(renewed, 0, reason: 'token tidak pernah diperbarui');
      expect(expired, 1, reason: 'sesi harus dianggap kedaluwarsa');
      expect(await store.readAccess(), isNull, reason: 'token dibersihkan');
    },
  );
}
