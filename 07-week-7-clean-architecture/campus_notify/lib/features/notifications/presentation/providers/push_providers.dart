import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dio_device_registrar.dart';
import '../../data/firebase_push_repository.dart';
import '../../domain/repositories/push_repositories.dart';
import '../../domain/usecases/register_device.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// SATU-SATUNYA tempat `new` untuk kelas Firebase dan Dio di fitur ini.
///
/// Perhatikan apa yang TIDAK ada di file ini: tidak ada HTTP client, tidak ada
/// plugin Firebase, tidak ada plugin penyimpanan token. Yang terlihat hanya
/// kontrak domain dan factory dari `data/`. Itulah yang membuat grep sterilitas
/// presentation benar-benar nol, bukan nol karena grep-nya yang longgar.
///
/// ## Satu-satunya ketergantungan lintas fitur
///
/// File ini mengimpor `auth_providers.dart` untuk [tokenStoreProvider],
/// [authRepositoryProvider], dan aksi logout. Itu satu-satunya tautan antar fitur
/// di seluruh project.
///
/// Alasannya nyata, bukan sekadar-malasan: `POST /devices` memakai header
/// `Authorization`, jadi mendaftarkan token perangkat memang butuh sesi milik
/// auth. Alternatifnya `lib/core/providers.dart` (untuk provider lintas fitur,
/// yang memang disediakan struktur target codelab) ditolak karena `core/`
/// diperuntukkan bagi hal yang tidak punya pemilik fitur. Begitu sesi auth
/// pindah tempat, `core/providers.dart` ikut harus diubah, sedangkan
/// `features/auth/...` jelas lokasinya.
final _firebasePushProvider = Provider<FirebasePushRepository>((ref) {
  return FirebasePushRepository();
});

final pushTokenSourceProvider = Provider<PushTokenSource>((ref) {
  return ref.watch(_firebasePushProvider);
});

final topicSubscriptionProvider = Provider<TopicSubscription>((ref) {
  return ref.watch(_firebasePushProvider);
});

final deepLinkSourceProvider = Provider<DeepLinkSource>((ref) {
  return ref.watch(_firebasePushProvider);
});

/// `buildDeviceRegistrar()` membuat `Dio` di dalam `data/`. Karena tipenya tidak
/// pernah disebut di sini, presentation tidak bisa memegangnya.
final deviceRegistrarProvider = Provider<DeviceRegistrar>((ref) {
  return buildDeviceRegistrar(
    store: ref.watch(tokenStoreProvider),
    auth: ref.watch(authRepositoryProvider),
    readToken: () => ref.read(_firebasePushProvider).currentToken,
    onSessionExpired: () => ref.read(authStateProvider.notifier).logout(),
  );
});

/// Use case: mendaftarkan token perangkat, HANYA kalau sesi sudah aktif.
final registerDeviceProvider = Provider<RegisterDevice>((ref) {
  return RegisterDevice(
    registrar: ref.watch(deviceRegistrarProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

/// Mendaftarkan token perangkat setiap kali sesi baru berhasil dibuka.
///
/// Dipasang di `main.dart` lewat `ref.watch`. Letaknya di sini, bukan di
/// `AuthNotifier`, untuk memutus siklus import: `auth` tidak boleh tahu apa pun
/// soal notifikasi, dan `notifications` boleh tahu soal sesi karena
/// `POST /devices` memang butuh header `Authorization`.
///
/// Tanpa pemisahan ini, `auth_providers.dart` dan file ini saling mengimpor,
/// dan hanya Flutter yang bisa menoleransi cycle seperti itu.
final deviceRegistrationOnLoginProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<bool>>(authStateProvider, (previous, next) {
    if (previous?.value == true || next.value != true) return;
    unawaited(ref.read(registerDeviceProvider).call());
  });
});
