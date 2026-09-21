import 'package:flutter/material.dart';
import '../data/models/post.dart';

/// Baris (tile) tunggal untuk satu post, agar `ListView.builder` di halaman
/// list/paged tetap pendek dan mudah diuji.
///
/// Navigasi tidak ditangani di dalam widget ini; cukup terima [onTap]
/// callback dari pemanggil. Dengan begitu widget ini murni (tanpa
/// dependency routing/provider) sehingga test widget lebih sederhana.
class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post, this.onTap});

  /// Data post yang ditampilkan.
  final Post post;

  /// Dipanggil saat tile ditekan (mis. navigasi ke halaman detail).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // Avatar berisi id post agar baris mudah dikenali di daftar.
      leading: CircleAvatar(child: Text(post.id.toString())),
      // Judul dibatasi satu baris agar daftar tetap seragam.
      title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      // Isi post tampil maksimal 2 baris sebagai ringkasan.
      subtitle: Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      // Indikator adanya halaman detail (opsional, tidak menambah data).
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}