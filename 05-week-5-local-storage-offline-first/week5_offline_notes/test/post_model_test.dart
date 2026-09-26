import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/data/models/post.dart';

void main() {
  test('Post.fromJson aman saat field null atau hilang', () {
    final post = Post.fromJson(const {'id': null, 'userId': null});
    expect(post.id, 0);
    expect(post.userId, 0);
    expect(post.title, '');
    expect(post.body, '');
  });

  test('Post.toJson lalu fromJson mempertahankan nilai', () {
    const post = Post(userId: 1, id: 2, title: 'Judul', body: 'Isi');
    final round = Post.fromJson(post.toJson());
    expect(round.userId, 1);
    expect(round.id, 2);
    expect(round.title, 'Judul');
    expect(round.body, 'Isi');
  });
}