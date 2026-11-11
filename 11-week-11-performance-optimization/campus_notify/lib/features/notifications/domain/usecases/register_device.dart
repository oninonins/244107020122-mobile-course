import '../../../../core/failures.dart';
import '../../../auth/domain/repositories/token_store.dart';
import '../repositories/push_repositories.dart';

/// Operasi bisnis: mendaftarkan token perangkat ke backend.
///
/// ## Kenapa use case ini perlu ada
///
/// Karena ia memegang **aturan bisnis**: token hanya boleh dikirim kalau sesi
/// sudah ada.
///
/// Week 6, aturan itu tersebar di dua tempat — `main.dart:135` mengecek
/// `await ref.read(authStateProvider.future)`, dan `auth_provider.dart:62`
/// memanggil ulang setelah login. Dua tempat, satu aturan, dan mudah lupa di
/// salah satunya. Kalau token terkirim tanpa header `Authorization`, backend
/// menolaknya, dan karena `onTokenRefresh` hanya memicu saat token benar-benar
/// berubah, token itu tidak akan pernah dikirim ulang dengan otentikasi yang
/// sah — bug senyap yang bertahan berbulan-bulan.
///
/// Setelah dikumpulkan di sini, aturannya diuji sekali di
/// `test/domain/register_device_test.dart`.
///
/// ## Kenapa `RequestPermission` dan `SetTopicSubscription` TIDAK punya use case
///
/// Keduanya tidak punya aturan apa pun - keduanya pembungkus satu panggilan.
/// [TopicSubscription.setSubscribed] sudah mengembalikan record berisi nilai
/// baru dan kegagalan, jadi tidak ada yang perlu ditambahkan di atasnya.
/// Membuat use case untuk keduanya adalah over-engineering, dan batas yang
/// dipakai project ini sudah konsisten: **use case dibuat bila ada aturan
/// bisnis atau lebih dari satu sumber data.**
class RegisterDevice {
  const RegisterDevice({required this.registrar, required this.tokenStore});

  final DeviceRegistrar registrar;
  final TokenStore tokenStore;

  Future<({String? status, Failure? failure})> call() async {
    final access = await tokenStore.readAccess();
    if (access == null) {
      return (status: 'Token belum dikirim: sesi belum aktif', failure: null);
    }

    return registrar.registerDevice();
  }
}
