import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/data/local/note.dart';

void main() {
  test('Note.fromMap memberi fallback saat field hilang', () {
    final note = Note.fromMap(const {});
    expect(note.title, '');
    expect(note.body, '');
    expect(note.dirty, isFalse);
    expect(note.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
  });

  test('Note.toMap lalu fromMap mempertahankan nilai', () {
    final note = Note(
      id: 3,
      title: 'Judul',
      body: 'Isi',
      updatedAt: DateTime.utc(2026, 9, 26, 1, 2, 3),
      dirty: true,
    );
    final round = Note.fromMap(note.toMap());
    expect(round.id, 3);
    expect(round.title, 'Judul');
    expect(round.body, 'Isi');
    expect(round.updatedAt, DateTime.utc(2026, 9, 26, 1, 2, 3));
    expect(round.dirty, isTrue);
  });
}