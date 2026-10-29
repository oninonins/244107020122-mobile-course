import '../../../../core/failures.dart';
import '../entities/announcement.dart';

/// Kontrak sumber data pengumuman.
///
/// Ada dua metode, masing-masing dengan konsumen nyata:
///
/// - `fetchById` dipakai `announcement_page.dart`, yang menerima id dari deep
///   link FCM (`/pengumuman/3`).
/// - `fetchAll` dipakai `announcement_list_page.dart`, halaman daftar dengan
///   pencarian.
///
/// `fetchAll` sempat ditolak pada Week 7 karena saat itu belum ada yang
/// memakainya. Penolakan itu benar pada waktunya: metode tanpa konsumen adalah
/// kode mati. Sekarang konsumennya ada, jadi kontraknya ikut tumbuh.
///
/// Aturannya tetap: metode ditambahkan saat ada pemakainya, bukan sebelum.
abstract interface class AnnouncementRepository {
  Future<({Announcement? announcement, Failure? failure})> fetchById(String id);

  Future<({List<Announcement> announcements, Failure? failure})> fetchAll();
}
