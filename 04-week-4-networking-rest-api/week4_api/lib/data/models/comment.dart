/// Model data untuk satu komentar dari endpoint JSONPlaceholder
/// `GET /comments` (response berupa `List` dari objek berikut):
///   - postId : id dari post yang memiliki komentar ini
///   - id     : id unik komentar
///   - name   : nama penulis komentar
///   - email  : email penulis komentar
///   - body   : isi/teks komentar
class Comment {
  // Konstruktor const: semua field wajib diisi saat membuat objek
  // secara manual (misalnya untuk test atau data lokal).
  const Comment({
    required this.postId,
    required this.id,
    required this.name,
    required this.email,
    required this.body,
  });

  // Semua field bersifat final (immutable) — pola yang sama dengan model Post.
  final int postId;
  final int id;
  final String name;
  final String email;
  final String body;

  /// Membuat [Comment] dari map JSON hasil parsing API.
  ///
  /// "Safe null": setiap key dicek dengan `as T?` lalu diberi nilai
  /// fallback (default). Jika field hilang, bernilai `null`, atau bertipe
  /// salah, tidak akan melempar exception — parse tetap berhasil.
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      // `num?` digunakan agar bilangan JSON (int maupun double) aman,
      // lalu dikonversi ke `int` dengan `?.toInt()`. Fallback 0.
      postId: (json['postId'] as num?)?.toInt() ?? 0,
      id: (json['id'] as num?)?.toInt() ?? 0,
      // String diperiksa dengan `as String?`; kalau hilang → fallback ''.
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }

  /// Kebalikan dari [fromJson]: mengubah objek menjadi map JSON.
  /// Berguna untuk serialisasi ulang (misalnya caching / logging).
  Map<String, dynamic> toJson() => {
        'postId': postId,
        'id': id,
        'name': name,
        'email': email,
        'body': body,
      };
}