import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../local/db.dart';
import '../models/post.dart';

/// Menyimpan daftar posts sebagai cache lokal di tabel `cached_posts`.
///
/// Strateginya satu baris dengan `id = 1`: kolom `payload` berisi
/// seluruh daftar posts yang di-encode JSON. Catatan saat cache
/// dibuat disimpan di kolom `cached_at`.
class CachedPostsRepository {
  /// [openDb] bisa diganti lewat constructor untuk keperluan testing;
  /// defaultnya membuka database aplikasi yang sama dengan notes.
  CachedPostsRepository({Future<Database> Function()? openDb})
      : _openDb = openDb ?? openNotesDb;

  final Future<Database> Function() _openDb;

  static const _cacheId = 1;

  /// Membaca cache daftar posts. Mengembalikan daftar kosong jika
  /// belum pernah ada cache atau payload-nya rusak, sehingga UI
  /// tidak pernah crash karena data lama yang tidak valid.
  Future<List<Post>> readCachedPosts() async {
    final db = await _openDb();
    final rows = await db.query(
      'cached_posts',
      where: 'id = ?',
      whereArgs: [ _cacheId],
      limit: 1,
    );
    if (rows.isEmpty) return [];
    final payload = rows.first['payload'] as String?;
    if (payload == null || payload.isEmpty) return [];

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Post.fromJson)
          .toList();
    } on FormatException {
      // Payload rusak: anggap tidak ada cache.
      return [];
    }
  }

  /// Menyimpan (upsert) daftar posts ke baris cache `id = 1`.
  Future<void> saveCachedPosts(List<Post> posts) async {
    final db = await _openDb();
    await db.insert(
      'cached_posts',
      {
        'id': _cacheId,
        'payload': jsonEncode(posts.map((p) => p.toJson()).toList()),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}