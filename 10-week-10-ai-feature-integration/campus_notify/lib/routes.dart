/// Sumber tunggal untuk semua string rute di aplikasi.
///
/// GoRouter dan deep link dari FCM memakai konstanta yang sama, jadi nama rute
/// tidak bisa berbeda antara router dan payload notifikasi.
///
/// Catatan: fungsi `routeFromMessage` **tidak** ada di sini, melainkan di
/// `core/format.dart`, sesuai Refactoring Challenge codelab — pemisahan format
/// dan parsing agar bisa diuji tanpa widget. File ini tetap murni Dart, jadi
/// `core/format.dart` mengimpornya tanpa melanggar grep sterilitas `core/`.
abstract final class Routes {
  static const String login = '/login';
  static const String home = '/';

  /// Pola yang didaftarkan di GoRouter, misalnya `/pengumuman/3`.
  static const String announcementPattern = '/pengumuman/:id';

  /// Prefix untuk mengenali deep link pengumuman.
  static const String announcementPrefix = '/pengumuman/';

  /// Halaman pindai pengumuman dengan AI.
  static const String scan = '/pindai';

  static String announcementDetail(String id) => '$announcementPrefix$id';
}
