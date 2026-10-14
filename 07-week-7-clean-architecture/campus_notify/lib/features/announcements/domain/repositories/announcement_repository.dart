import '../../../../core/failures.dart';
import '../entities/announcement.dart';

/// Kontrak sumber data pengumuman.
///
/// Hanya ada `fetchById`, bukan `fetchAll`. Alasannya: satu-satunya tempat yang
/// membaca pengumuman adalah `announcement_page.dart`, yang menerima `id` dari
/// deep link FCM (`/pengumuman/3`). Menulis `fetchAll()` sekarang berarti
/// menebak kebutuhan masa depan — dan metode yang tak terpakai adalah
/// over-engineering di level yang sama dengan use case yang berlebihan.
///
/// Kalau nanti ada halaman daftar pengumuman, `fetchAll()` ditambahkan saat itu
/// juga, bersama use case yang memakainya.
abstract interface class AnnouncementRepository {
  Future<({Announcement? announcement, Failure? failure})> fetchById(String id);
}