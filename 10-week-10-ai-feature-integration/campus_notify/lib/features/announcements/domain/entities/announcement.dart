/// Objek bisnis pengumuman kampus.
///
/// ## Kenapa tidak ada `publishedAt`
///
/// Aplikasi belum menampilkan tanggal pengumuman di mana pun, jadi menambah
/// field itu sekarang berarti menyimpan data yang tidak pernah dipakai — itu
/// generality spekulatif, jenis kesalahan yang sama dengan over-engineering use
/// case, hanya di tempat berbeda. Kalau nanti UI menampilkan tanggal, field ini
/// ditambahkan saat itu juga, bukan sekarang "siap dipakai".
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
  });

  /// Id sebagai string karena came dari `data.route` pada payload FCM, yang
  /// selalu berupa teks. Mengubahnya ke `int` berarti menambahkan konversi
  /// hanya di satu tempat tanpa ada yang membutuhkannya.
  final String id;

  final String title;

  final String body;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Announcement &&
          other.id == id &&
          other.title == title &&
          other.body == body;

  @override
  int get hashCode => Object.hash(id, title, body);

  @override
  String toString() => 'Announcement($id)';
}
