/// Sumber tunggal untuk semua string rute di aplikasi.
///
/// GoRouter dan deep link dari FCM memakai konstanta yang sama, jadi nama rute
/// tidak bisa berbeda antara router dan payload notifikasi.
abstract final class Routes {
  static const String login = '/login';
  static const String home = '/';

  /// Pola yang didaftarkan di GoRouter, misalnya `/pengumuman/3`.
  static const String announcementPattern = '/pengumuman/:id';

  /// Prefix untuk mengenali deep link pengumuman.
  static const String announcementPrefix = '/pengumuman/';

  static String announcementDetail(String id) => '$announcementPrefix$id';
}

/// Mengubah payload data FCM menjadi rute GoRouter yang valid.
///
/// Sengaja dibuat fungsi murni di file yang bebas Firebase supaya bisa diunit
/// test tanpa menyiapkan instance Firebase sungguhan.
String routeFromMessage(Map<String, dynamic> data) {
  final route = data['route'] as String? ?? Routes.home;
  return route.startsWith('/') ? route : '${Routes.home}$route';
}