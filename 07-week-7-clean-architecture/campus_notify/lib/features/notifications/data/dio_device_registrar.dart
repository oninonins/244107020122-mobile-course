import 'package:dio/dio.dart';

import '../../../core/failures.dart';
import '../../auth/data/api_client.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../../auth/domain/repositories/token_store.dart';
import '../domain/repositories/push_repositories.dart';
import 'api_errors.dart';

/// Mendaftarkan token perangkat ke backend lewat `POST /devices`.
///
/// `Dio` tidak pernah keluar dari file ini. Kalau `presentation` memegang Dio,
/// UI terikat ke HTTP client - itu persis kebocoran yang harus hilang.
class DioDeviceRegistrar implements DeviceRegistrar {
  DioDeviceRegistrar({required this.dio, required this.readToken});

  final Dio dio;

  /// Membaca token perangkat dari sumber push saat ini.
  ///
  /// Dipakai sebagai callback, bukan nilai langsung, karena token FCM belum ada
  /// ketika objek ini dibuat: `getToken()` menunggu jaringan dan dipanggil
  /// setelah aplikasi berjalan.
  final String? Function() readToken;

  @override
  Future<({String? status, Failure? failure})> registerDevice() async {
    final token = readToken();
    if (token == null) {
      return (status: 'Token belum tersedia', failure: null);
    }

    try {
      await dio.post<void>(
        '/devices',
        data: {'fcm_token': token, 'platform': 'android'},
      );
      return (status: 'POST /devices berhasil', failure: null);
    } on DioException catch (e) {
      // Kegagalan dikembalikan sebagai Failure, bukan dilempar. Endpoint contoh
      // memang belum ada, dan kegagalannya justru ditampilkan di debug card
      // sebagai bukti alur token benar-benar memanggil jaringan.
      return (
        status: 'POST /devices gagal: ${readableApiError(e)}',
        failure: readableApiFailure(e),
      );
    }
  }
}

/// Membangun [DioDeviceRegistrar] lengkap dengan sesi terautentikasi.
///
/// Dipanggil dari `presentation/providers/push_providers.dart`. Fungsi inilah
/// yang membuat `Dio` benar-benar tidak pernah muncul di presentation: yang
/// dikembalikan hanya kontrak [DeviceRegistrar].
///
/// [readToken] diteruskan dari pemanggil karena sumber token adalah
/// `FirebasePushRepository`, yang juga hidup di `data/`.
DeviceRegistrar buildDeviceRegistrar({
  required TokenStore store,
  required AuthRepository auth,
  required String? Function() readToken,
  void Function()? onSessionExpired,
}) {
  final dio = buildApiClient(
    store: store,
    auth: auth,
    onSessionExpired: onSessionExpired,
  );
  return DioDeviceRegistrar(dio: dio, readToken: readToken);
}