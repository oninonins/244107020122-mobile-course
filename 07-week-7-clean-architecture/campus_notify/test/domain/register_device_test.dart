import 'package:campus_notify/core/failures.dart';
import 'package:campus_notify/features/auth/data/datasources/secure_token_store.dart';
import 'package:campus_notify/features/notifications/domain/repositories/push_repositories.dart';
import 'package:campus_notify/features/notifications/domain/usecases/register_device.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository palsu device. Tidak ada Dio, tidak ada Firebase, tidak ada HTTP.
class FakeDeviceRegistrar implements DeviceRegistrar {
  FakeDeviceRegistrar({this.status, this.failure});

  final String? status;
  final Failure? failure;
  int calls = 0;

  @override
  Future<({String? status, Failure? failure})> registerDevice() async {
    calls++;
    return (status: status, failure: failure);
  }
}

void main() {
  late InMemoryTokenStore store;
  late FakeDeviceRegistrar registrar;

  setUp(() {
    store = InMemoryTokenStore();
    registrar = FakeDeviceRegistrar(status: 'POST /devices berhasil');
  });

  test('sesi aktif -> token dikirim ke backend', () async {
    await store.save(access: 'mock-access', refresh: 'mock-refresh');

    final result = await RegisterDevice(registrar: registrar, tokenStore: store).call();

    expect(result.status, 'POST /devices berhasil');
    expect(result.failure, isNull);
    expect(registrar.calls, 1);
  });

  test('sesi belum aktif -> token TIDAK dikirim, dan alasannya dinyatakan', () async {
    final result = await RegisterDevice(registrar: registrar, tokenStore: store).call();

    // Inilah aturan bisnis yang diuji. Tanpa ini, `POST /devices` berjalan
    // tanpa header `Authorization`, backend menolak, dan karena
    // `onTokenRefresh` hanya memicu saat token berubah, token tidak akan pernah
    // dikirim ulang dengan otentikasi yang sah.
    expect(registrar.calls, 0, reason: 'registrar tidak boleh dipanggil tanpa sesi');
    expect(result.status, contains('sesi belum aktif'));
  });

  test('kegagalan backend dikembalikan sebagai Failure', () async {
    await store.save(access: 'a', refresh: 'r');
    registrar = FakeDeviceRegistrar(
      status: 'POST /devices gagal: Tidak ada koneksi ke server.',
      failure: const NetworkFailure('Tidak ada koneksi ke server.'),
    );

    final result = await RegisterDevice(registrar: registrar, tokenStore: store).call();

    expect(result.failure, isA<NetworkFailure>());
    expect(result.failure?.message, 'Tidak ada koneksi ke server.');
  });
}