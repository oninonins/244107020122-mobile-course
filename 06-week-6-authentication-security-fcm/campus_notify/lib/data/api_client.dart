import 'package:dio/dio.dart';

import 'auth_repository.dart';
import 'token_store.dart';

/// Penanda pada `RequestOptions.extra` agar request yang sudah dicoba ulang
/// tidak diulang lagi. Tanpa ini endpoint yang selalu 401 akan loop.
const _retriedKey = 'auth_retried';

typedef SessionExpiredCallback = void Function();

/// Membangun [Dio] yang menempelkan `Authorization: Bearer <access>` pada
/// setiap request dan, saat menerima 401, menukar refresh token lalu mengulang
/// request tepat satu kali.
Dio buildApiClient({
  required TokenStore store,
  required AuthRepository auth,
  String baseUrl = 'https://example-campus-api.test',
  SessionExpiredCallback? onSessionExpired,
  Dio? inner,
}) {
  final dio = inner ?? Dio(BaseOptions(baseUrl: baseUrl));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final access = await store.readAccess();
        if (access != null) {
          options.headers['Authorization'] = 'Bearer $access';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final request = e.requestOptions;
        if (e.response?.statusCode != 401 ||
            (request.extra[_retriedKey] as bool? ?? false)) {
          return handler.next(e);
        }

        final refresh = await store.readRefresh();
        if (refresh == null) {
          await _expire(store, onSessionExpired);
          return handler.next(e);
        }

        try {
          final renewed = await auth.refresh(refresh);
          await store.save(access: renewed.access, refresh: renewed.refresh);
          request.extra[_retriedKey] = true;
          request.headers['Authorization'] = 'Bearer ${renewed.access}';
          final retry = await dio.fetch<dynamic>(request);
          return handler.resolve(retry);
        } catch (_) {
          // Refresh ikut kedaluwarsa -> paksa login ulang.
          await _expire(store, onSessionExpired);
        }

        handler.next(e);
      },
    ),
  );

  return dio;
}

Future<void> _expire(
  TokenStore store,
  SessionExpiredCallback? onSessionExpired,
) async {
  await store.clear();
  onSessionExpired?.call();
}
