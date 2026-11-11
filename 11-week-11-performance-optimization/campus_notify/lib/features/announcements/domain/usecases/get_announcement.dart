import '../../../../core/failures.dart';
import '../entities/announcement.dart';
import '../repositories/announcement_repository.dart';

/// Operasi bisnis: mengambil satu pengumuman berdasarkan id dari deep link.
///
/// ## Kenapa ada use case yang cuma meneruskan
///
/// Secara harfiah ia tidak menambah apa pun: dia memanggil repository lalu
/// mengembalikan hasilnya.
///
/// Yang sebenarnya ia lakukan adalah memberi **satu pintu masuk domain** ke
/// data pengumuman. Tanpa dia, `announcement_page.dart` harus mengimpor kontrak
/// repository langsung, dan UI jadi terikat ke bentuk sumber data. Kalau nanti
/// tumbuh — mis. harus memeriksa apakah pengumuman sudah dibaca, atau melakukan
/// refresh lalu streaming — logikanya tinggal ditambah di sini tanpa menyentuh
/// halaman.
///
/// Batas yang dipakai project ini tetap sama dengan batas auth:
/// **use case dibuat bila ada aturan bisnis atau lebih dari satu sumber data.**
/// Yang membedakan di sini adalah ada entry point yang sudah dipanggil UI.
class GetAnnouncement {
  const GetAnnouncement(this._repository);

  final AnnouncementRepository _repository;

  Future<({Announcement? announcement, Failure? failure})> call(String id) {
    return _repository.fetchById(id);
  }
}
