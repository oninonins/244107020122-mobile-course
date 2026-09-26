class Post {
  const Post({
    required this.userId,
    required this.id,
    required this.title,
    required this.body,
  });

  final int userId;
  final int id;
  final String title;
  final String body;

  /// Mengurai JSON dari server dengan aman terhadap null.
  /// Field yang hilang atau null diberi fallback (0 untuk angka,
  /// string kosong untuk teks) agar satu data rusak tidak
  /// menjatuhkan seluruh daftar.
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }

  /// Serialisasi kembali ke Map agar bisa disimpan sebagai
  /// payload JSON di tabel `cached_posts`.
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'id': id,
        'title': title,
        'body': body,
      };
}