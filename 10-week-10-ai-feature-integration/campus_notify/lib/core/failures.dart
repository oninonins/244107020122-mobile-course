/// Kegagalan yang sudah dinormalisasi sebelum mencapai presentation.
///
/// Aturan main: `domain` dan `core` tidak boleh mengimpor apa pun. Semua
/// kegagalan dari luar (DioException, Exception dari plugin, FormatException)
/// dipetakan ke sini di lapisan `data`, sehingga UI hanya pernah menerima
/// [message] yang sudah ramah pengguna — bukan stack trace mentah.
///
/// `sealed` dipilih agar `switch` pada subtype harus lengkap: kalau nanti
/// ditambah jenis kegagalan baru, semua titik yang menangani kegagalan ikut
/// obligated untuk Weeks-dan itu terlihat oleh compiler.
sealed class Failure {
  const Failure(this.message);

  /// Siap ditampilkan ke pengguna.
  final String message;

  @override
  String toString() => message;
}

/// Kegagalan dari penyimpanan lokal: secure storage, cache, atau basis data.
class LocalFailure extends Failure {
  const LocalFailure(super.message);
}

/// Kegagalan jaringan atau HTTP: timeout, 4xx, 5xx, sertifikat tidak valid.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Kegagalan autentikasi: kredensial ditolak, sesi habis, refresh token mati.
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Kegagalan validasi input yang lolos ke domain, mis. email tidak berformat.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Kegagalan layanan AI: key belum diatur, kuota habis, atau model menolak.
///
/// Dipisah dari [NetworkFailure] karena penanganannya berbeda di UI. Kuota habis
/// butuh saran menunggu, sedangkan key belum diatur butuh saran membuka
/// pengaturan.
class AiFailure extends Failure {
  const AiFailure(
    super.message, {
    this.quotaExceeded = false,
    this.hint,
    this.retryAfterSeconds,
  });

  /// Benar bila penyedia menolak karena batas laju atau kuota.
  ///
  /// UI memakai ini untuk menampilkan tombol coba lagi, bukan menyuruh pengguna
  /// mengganti key.
  final bool quotaExceeded;

  /// Saran tindakan dari penyedia, bila ada.
  ///
  /// Diambil dari `error.metadata.remedy_hint` atau `Retry-After`. Ditampilkan
  /// terpisah dari [message] supaya pesan utama tetap pendek.
  final String? hint;

  /// Berapa detik pengguna sebaiknya menunggu sebelum mencoba lagi.
  ///
  /// Berasal dari header `Retry-After`. Null berarti penyedia tidak memberi
  /// perkiraan waktu.
  final int? retryAfterSeconds;

  @override
  String toString() => hint == null ? message : '$message ($hint)';
}
