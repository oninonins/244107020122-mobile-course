import 'package:dio/dio.dart';

import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/token_store.dart';

/// Penanda pada `RequestOptions.extra` agar request yang sudah dicoba ulang
/// tidak diulang lagi. Tanpa ini endpoint yang selalu 401 akan loop.
const _retriedKey = 'auth_retried';

typedef SessionExpiredCallback = void Function();

/// Dipanggil setelah access token berhasil diperbarui oleh interceptor.
///
/// Ada karena secure storage punya dua penulis: `AuthNotifier.login()` dan
/// interceptor di file ini. Kartu debug membaca penyimpanan itu lewat provider
/// terpisah, jadi keduanya harus memberi tahu saat isinya berubah. Kalau hanya
/// jalur login yang memberi tahu, kartu debug menampilkan access token lama
/// setiap kali token diperbarui diam-diam saat menerima 401.
typedef SessionRenewedCallback = void Function();

/// Membangun [Dio] yang menempelkan `Authorization: Bearer <access>` pada
/// setiap request dan, saat menerima 401, menukar refresh token lalu mengulang
/// request tepat satu kali.
///
/// Hanya butuh dua kontrak domain ([TokenStore] dan [AuthRepository]), bukan
/// implementasi konkretnya. Itulah alasan kelas ini boleh dipakai dari
/// `features/notifications/data` tanpa menarik dependensi auth whole.
Dio buildApiClient({
  required TokenStore store,
  required AuthRepository auth,
  String baseUrl = 'https://example-campus-api.test',
  SessionExpiredCallback? onSessionExpired,
  SessionRenewedCallback? onSessionRenewed,
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

        // `refresh()` mengembalikan record, jadi tidak ada exception yang perlu
        // ditangkap di sini — cukup periksa failure-nya.
        final renewed = await auth.refresh(refresh);
        if (renewed.session == null) {
          // Refresh ikut kedaluwarsa -> paksa login ulang.
          await _expire(store, onSessionExpired);
          return handler.next(e);
        }

        await store.save(
          access: renewed.session!.access,
          refresh: renewed.session!.refresh,
        );

        // Penyimpanan sudah berisi token baru. Pembaca lain perlu tahu.
        onSessionRenewed?.call();

        request.extra[_retriedKey] = true;
        request.headers['Authorization'] = 'Bearer ${renewed.session!.access}';
        final retry = await dio.fetch<dynamic>(request);
        return handler.resolve(retry);
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
