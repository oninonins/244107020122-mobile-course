import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/data/repositories/note_repository.dart';
import 'package:week5_offline_notes/data/sync.dart';

/// Repositori palsu: hanya countDirty dan markAllSynced yang relevan,
/// tanpa menyentuh database sungguhan.
class FakeNoteRepository extends NoteRepository {
  FakeNoteRepository({this.dirtyCount = 0});

  int dirtyCount;
  bool markedSynced = false;

  @override
  Future<int> countDirty() async => dirtyCount;

  @override
  Future<void> markAllSynced() async {
    markedSynced = true;
  }
}

void main() {
  test('syncNotes keluar dengan 0 tanpa menandai saat tidak ada dirty', () async {
    final repo = FakeNoteRepository(dirtyCount: 0);
    final result = await syncNotes(repo);
    expect(result, 0);
    expect(repo.markedSynced, isFalse);
  });

  test('syncNotes menandai bersih dan mengembalikan jumlah dirty', () async {
    final repo = FakeNoteRepository(dirtyCount: 2);
    final result = await syncNotes(repo);
    expect(result, 2);
    expect(repo.markedSynced, isTrue);
  });
}