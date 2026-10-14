import '../../../../core/failures.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// Operasi bisnis: memvalidasi kredensial lalu meminta sesi baru.
///
/// ## Kenapa use case ini perlu ada
///
/// Karena ia memegang **aturan bisnis**, bukan sekadar meneruskan panggilan.
/// Aturan "email harus berformat email" dan "kata sandi minimal 6 karakter"
/// sebelumnya berada di dalam `login_page.dart`. Akibatnya:
///
/// - validasinya tidak bisa diuji tanpa memompa seluruh halaman beserta plugin
///   Firebase-nya;
/// - setiap halaman yang punya form login harus menyalin ulang validasinya.
///
/// Setelah pindah ke sini, `test/domain/login_test.dart` mengujinya dengan
/// `test()` biasa — tanpa widget, tanpa Dio, tanpa secure storage.
///
/// Mengembalikan record berisi session, bukan `bool`. Notifier butuh token
/// untuk disimpan, jadi `bool` memaksa repository dipanggil dua kali.
///
/// ## Kapan use case TIDAK perlu
///
/// `Logout` sengaja tidak dibuat use case: operasinya satu baris
/// (`tokenStore.clear()`) tanpa aturan apa pun. Membuat kelas untuk itu adalah
/// over-engineering. Batas yang dipakai project ini: **use case dibuat bila ada
/// aturan bisnis, atau operasinya menggabungkan lebih dari satu sumber data.**
class Login {
  const Login(this._repository);

  final AuthRepository _repository;

  /// Aturan validasi, dipisah dari [call] supaya bisa dipakai dua kali:
  ///
  /// 1. [call] memanggilnya sebagai gerbang — tidak ada jalur yang melewatinya.
  /// 2. `login_page.dart` memanggilnya lewat validator `TextFormField` agar
  ///    pesan kesalahan tetap muncul **di bawah field** seperti sebelumnya.
  ///
  /// Format pesan karena itu ditulis ulang persis seperti aslinya.
  ///
  /// Ini yang membuat aturan tidak pernah terduplikasi: Presentation menampilkan
  /// hasil, domain memutuskan. Kalau aturan hanya hidup di widget, ia tidak bisa
  /// diuji tanpa widget; kalau hanya di domain, umurnya hilang dan pengalamannya
  /// berubah.
  static Failure? validateEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return const ValidationFailure('Email wajib diisi');
    }
    if (!trimmed.contains('@')) {
      return const ValidationFailure('Format email tidak valid');
    }
    return null;
  }

  static Failure? validatePassword(String password) {
    if (password.isEmpty) {
      return const ValidationFailure('Kata sandi wajib diisi');
    }
    if (password.length < 6) {
      return const ValidationFailure('Minimal 6 karakter');
    }
    return null;
  }

  /// Gerbang untuk [call]: mengembalikan kegagalan pertama, atau `null` kalau
  /// keduanya valid.
  static Failure? validate({required String email, required String password}) {
    return validateEmail(email) ?? validatePassword(password);
  }

  Future<({AuthSession? session, Failure? failure})> call({
    required String email,
    required String password,
  }) async {
    final invalid = validate(email: email, password: password);
    if (invalid != null) {
      return (session: null, failure: invalid);
    }

    return _repository.login(email: email.trim(), password: password);
  }
}