import 'package:campus_notify/core/failures.dart';
import 'package:campus_notify/features/auth/data/datasources/secure_token_store.dart';
import 'package:campus_notify/features/auth/domain/entities/auth_session.dart';
import 'package:campus_notify/features/auth/domain/repositories/auth_repository.dart';
import 'package:campus_notify/features/auth/domain/usecases/login.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository palsu untuk menguji domain tanpa Dio, tanpa secure storage, tanpa
/// Firebase. Hanya butuh `test()` biasa — tidak ada `pumpWidget`.
///
/// ## Deviasi dari contoh codelab: tidak ada `throw UnimplementedError()`
///
/// Contoh `FakeNoteRepository` di codelab menulis:
///
/// ```dart
/// @override
/// Future<...> addNote(...) => throw UnimplementedError();
/// ```
///
/// Itu persis gejala pelanggaran Liskov Substitution yang dicantumkan di bagian
/// SOLID halaman yang sama: *"Repository palsu untuk test malah melempar error
/// yang tak pernah dilempar repository asli." Kalau `Login` misalnya
/// memanggil `refresh()` di masa depan, test ini akan gagal dengan error yang
/// tidak ada hubungannya dengan apa pun yang sedang diuji.
///
/// Sebaliknya, [FakeAuthRepository] mengembalikan record kegagalan yang wajar,
/// sehingga **setiap metode pada interface bisa Replace repository asli tanpa
/// merusak apa pun** — persis syarat Liskov. Test di bawah membuktikannya.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.session = const AuthSession(access: 'fake-access', refresh: 'fake-refresh'),
    this.failure,
    this.loginCalls = 0,
    this.refreshCalls = 0,
  });

  /// Dikembalikan kalau [failure] null.
  final AuthSession session;

  /// Kalau tidak null, semua metode mengembalikan kegagalan ini.
  final Failure? failure;

  /// Menghitung pemanggilan supaya bisa dibuktikan bahwa validasi terjadi
  /// **sebelum** repository dipanggil.
  int loginCalls;
  int refreshCalls;

  @override
  Future<({AuthSession? session, Failure? failure})> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    final f = failure;
    if (f != null) return (session: null, failure: f);
    return (session: session, failure: null);
  }

  @override
  Future<({AuthSession? session, Failure? failure})> refresh(String refreshToken) async {
    refreshCalls++;
    final f = failure;
    if (f != null) return (session: null, failure: f);
    return (session: session, failure: null);
  }
}

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());

  group('Login meneruskan sesi', () {
    test('kredensial valid menghasilkan session', () async {
      final result = await Login(repo).call(
        email: 'mhs@polinema.ac.id',
        password: 'rahasia123',
      );

      expect(result.failure, isNull);
      expect(result.session, isNotNull);
      expect(result.session!.access, 'fake-access');
      expect(repo.loginCalls, 1);
    });

    test('email dipangkas spasi sebelum dikirim', () async {
      await Login(repo).call(email: '  mhs@polinema.ac.id  ', password: 'rahasia123');
      expect(repo.loginCalls, 1);
    });
  });

  group('Login meneruskan failure tanpa melempar', () {
    test('repository menolak -> failure dikembalikan', () async {
      repo = FakeAuthRepository(failure: const AuthFailure('Email atau kata sandi tidak valid'));

      final result = await Login(repo).call(
        email: 'mhs@polinema.ac.id',
        password: 'rahasia123',
      );

      expect(result.session, isNull);
      expect(result.failure, isA<AuthFailure>());
      expect(result.failure?.message, 'Email atau kata sandi tidak valid');
    });

    test('tidak ada exception yang bocor keluar dari use case', () async {
      repo = FakeAuthRepository(failure: const NetworkFailure('Server mati'));

      // Kalau use case melempar, baris ini melempar dan test gagal.
      final result = await Login(repo).call(
        email: 'mhs@polinema.ac.id',
        password: 'rahasia123',
      );
      expect(result.failure, isA<NetworkFailure>());
    });
  });

  group('validasi dipindah ke domain', () {
    test('email kosong ditolak tanpa memanggil repository', () async {
      final result = await Login(repo).call(email: '', password: 'rahasia123');
      expect(result.session, isNull);
      expect(result.failure, isA<ValidationFailure>());
      expect(repo.loginCalls, 0, reason: 'repository tidak boleh dipanggil untuk input tak valid');
    });

    test('email tanpa @ ditolak', () async {
      final result = await Login(repo).call(email: 'bukan-email', password: 'rahasia123');
      expect(result.failure?.message, 'Format email tidak valid');
      expect(repo.loginCalls, 0);
    });

    test('kata sandi kosong ditolak', () async {
      final result = await Login(repo).call(email: 'mhs@polinema.ac.id', password: '');
      expect(result.failure?.message, 'Kata sandi wajib diisi');
      expect(repo.loginCalls, 0);
    });

    test('kata sandi terlalu pendek ditolak', () async {
      final result = await Login(repo).call(email: 'mhs@polinema.ac.id', password: '123');
      expect(result.failure?.message, 'Minimal 6 karakter');
      expect(repo.loginCalls, 0);
    });
  });

  group('Liskov Substitution — fake benar-benar menggantikan repository asli', () {
    test('semua metode interface mengembalikan record, tidak ada yang melempar', () async {
      // Kalau ada satu metode yang `throw UnimplementedError()`, pemanggilan
      // pertama di test ini akan gagal. Ini bukti langsung bahwa fake aman
      // dipakai sebagai pengganti `MockAuthRepository` yang sungguhan.
      final subject = repo;
      final loginResult = await subject.login(email: 'a@b.c', password: '123456');
      final refreshResult = await subject.refresh('apa saja');

      expect(loginResult.failure, isNull);
      expect(refreshResult.failure, isNull);
    });

    test('TokenStore palsu juga tanpa melempar', () async {
      final store = InMemoryTokenStore();
      await store.save(access: 'a', refresh: 'r');
      expect(await store.readAccess(), 'a');
      await store.clear();
      expect(await store.readAccess(), isNull);
    });
  });
}
