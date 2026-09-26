import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/data/local/note.dart';
import 'package:week5_offline_notes/widgets/note_tile.dart';

void main() {
  testWidgets('NoteTile menampilkan badge belum tersinkron saat dirty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteTile(
            note: Note(
              id: 1,
              title: 'Judul',
              body: 'Isi',
              updatedAt: DateTime(2026, 9, 26),
              dirty: true,
            ),
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('belum tersinkron'), findsOneWidget);
  });

  testWidgets('NoteTile tidak menampilkan badge saat sudah sinkron', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteTile(
            note: Note(
              id: 1,
              title: 'Judul',
              body: 'Isi',
              updatedAt: DateTime(2026, 9, 26),
              dirty: false,
            ),
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('belum tersinkron'), findsNothing);
  });
}