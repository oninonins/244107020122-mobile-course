import '../../../../core/failures.dart';
import '../entities/announcement.dart';
import '../repositories/announcement_repository.dart';

/// Operasi bisnis: mencari pengumuman berdasarkan kata kunci.
///
/// ## Aturan pencarian
///
/// 1. Spasi di awal dan akhir dibuang.
/// 2. Pencocokan tidak membedakan huruf besar dan kecil.
/// 3. Kata kunci dicocokkan ke **judul dan isi**, bukan judul saja. Alasannya
///    praktis: pengguna mencari "A2" untuk menemukan pengumuman yang menyebut
///    ruang kelas, dan kata itu ada di isi, bukan di judul.
/// 4. Kata kunci kosong berarti tampilkan semua.
///
/// ## Kenapa filter dipisah sebagai fungsi statis
///
/// [filter] tidak menyentuh repository dan tidak menyentuh widget. Ia bisa
/// diuji dengan `test()` biasa, tanpa `pumpWidget` dan tanpa fake repository.
/// Kalau logika ini ditulis di dalam `build()`, satu-satunya cara mengujinya
/// adalah memompa seluruh halaman.
class SearchAnnouncements {
  const SearchAnnouncements(this._repository);

  final AnnouncementRepository _repository;

  /// Menyaring daftar tanpa menyentuh sumber data.
  ///
  /// Murni: hasilnya hanya bergantung pada argumen, tidak ada efek samping.
  static List<Announcement> filter(List<Announcement> items, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return items;

    return items.where((item) {
      final title = item.title.toLowerCase();
      final body = item.body.toLowerCase();
      return title.contains(needle) || body.contains(needle);
    }).toList();
  }

  /// Mengambil seluruh pengumuman lalu menyaringnya.
  Future<({List<Announcement> announcements, Failure? failure})> call(
    String query,
  ) async {
    final result = await _repository.fetchAll();
    if (result.failure != null) {
      return (announcements: const <Announcement>[], failure: result.failure);
    }

    return (announcements: filter(result.announcements, query), failure: null);
  }
}
