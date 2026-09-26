import 'repositories/note_repository.dart';

/// Sinkronisasi catatan kotor (dirty) ke server.
///
/// Codelab ini belum punya backend tulis, jadi server disimulasikan
/// dengan delay. Yang dinilai adalah mekanismenya, bukan servernya:
/// di project nyata, di sinilah tiap catatan dirty dikirim via REST API
/// dan ditandai bersih hanya bila server menjawab 2xx.
Future<int> syncNotes(NoteRepository repo) async {
  final dirtyCount = await repo.countDirty();
  if (dirtyCount == 0) return 0;

  // Simulasi upload: kirim tiap catatan dirty ke server di sini.
  await Future.delayed(const Duration(seconds: 1));

  // Semua catatan terkirim, tandai bersih.
  await repo.markAllSynced();
  return dirtyCount;
}