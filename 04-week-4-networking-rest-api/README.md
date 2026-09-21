Uji tiga skenario error

1. Jalankan aplikasi dengan internet normal, amati loading lalu daftar 100 posts.
![Uji 1 - loading lalu daftar 100 posts](screenshots/uji%201.jpeg)
2. Matikan internet (mode pesawat), tekan refresh, amati pesan ramah + tombol Coba lagi. Nyalakan kembali internet, tekan Coba lagi.
![Uji 2 - pesan ramah + tombol Coba lagi](screenshots/uji%202.jpeg) 
3. Sementara ubah baseUrl menjadi URL salah, amati pesan error koneksi. Kembalikan setelah uji.
![Uji 3 - pesan error koneksi](screenshots/uji%203.jpeg) 

![Praktikum](screenshots/praktikum.jpeg) 






Ai Challenge 

prompt 

Buatkan repository layer Flutter untuk endpoint GET /comments?postId={id}
dari JSONPlaceholder menggunakan Dio + flutter_riverpod.
Requirements:
- Model Comment dengan fromJson aman null (postId, id, name, email, body).
- CommentRepository dengan method fetchComments(postId) + timeout 10 detik.
- AsyncNotifierProvider dengan penanganan error otomatis (AsyncError)
  dan fungsi pesan error
  ramah pengguna untuk timeout, connection error, 404, dan 500.
- Satu unit test untuk fromJson dengan field yang hilang.
Jelaskan setiap bagian kode dalam komentar.


AI Verification Checklist



1. UI tidak memanggil Dio secara langsung. Rantai pemanggilan selalu lewat `UI → Provider → Repository → Dio`. Library `dio` hanya diimpor di folder `lib/data/` (api_client, kedua repository, dan providers), sedangkan halaman hanya melewati provider dari Riverpod sehingga lapisan UI bersih dari logika HTTP.

2. `Comment.fromJson` aman terhadap null (field hilang atau bernilai null diberi fallback 0 untuk angka dan string kosong untuk teks), tetapi tidak aman terhadap tipe. Cast `as String?` atau `as num?` akan melempar `TypeError` bila nilainya bertipe salah, misalnya `name: 123` atau `postId: "5"`. Temuan ini dicatat sebagai risiko yang diterima dan sengaja tidak diperbaiki.

3. Semua jenis `DioExceptionType` terpetakan ke pesan ramah pengguna di fungsi `friendlyErrorMessage`. Timeout (`connectionTimeout`, `sendTimeout`, `receiveTimeout`), `connectionError`, dan `badResponse` (404, 401, 403, serta fallback untuk kode lain termasuk 500) masing memiliki pesan tersendiri. `TimeoutException` dari `Future.timeout` juga ditangani.

4. `baseUrl` dan timeout Dio terpusat di satu client melalui fungsi `createDio()` di `api_client.dart` (connect dan receive timeout 10 detik). `CommentRepository.fetchComments` menambahkan `Future.timeout(10 detik)` sebagai batas waktu keseluruhan request, sesuai persyaratan eksplisit, sehingga bukan duplikasi konfigurasi melainkan pengaman tambahan di lapisan repository.

5. Unit test `test/comment_model_test.dart` sudah menguji kasus field hilang, field bernilai null, konversi angka, dan happy path. Belum ada edge case untuk nilai bertipe salah yang berhubungan dengan temuan nomor 2, dan sengaja tidak ditambahkan. 

6. Jalankan flutter analyze dan flutter test, apakah hasil AI lolos tanpa warning?
flutter analyze
Analyzing week4_api...                                                  
No issues found! (ran in 8.7s)
flutter test
00:27 +4 -1: Some tests failed.



Checklist verifikasi mandiri
UI tidak memanggil Dio langsung, semua akses data lewat repository + provider.
Semua halaman membaca via provider yang memakai repository:
PagedPostPage → pagedPostsProvider → postRepository, PostDetailPage → postDetailProvider → fetchPost, PostListPage → postListProvider.

Empat state tampil benar: loading, error (+ retry), empty, success.
Hasil: Lulus.

Loading: spinner centered di halaman list dan detail, serta indikator di footer daftar berpagina.
Error + retry: pesan ramah `friendlyErrorMessage` dan tombol `Coba lagi` muncul saat daftar kosong.
Empty: teks `Belum ada data dari server.` di halaman list, dan `Semua data termuat.` di daftar berpagina.
Success: daftar PostTile dengan avatar id, judul, dan ringkasan isi.

Pagination: data bertambah saat scroll, tidak ada request ganda, ada indikator akhir data.
Hasil: Lulus.

Data bertambah saat scroll: notifier menempelkan data baru ke daftar dan menaikkan nomor halaman.
Tidak ada request ganda: guard `isLoadingMore` dan `!hasMore` menghentikan pemicuan ulang selama request berjalan.
Indikator akhir: footer menampilkan `Semua data termuat.` ketika `hasMore` bernilai false.

flutter analyze tanpa issue dan semua test lulus.

flutter test  
00:13 +8: D:/college/semester 5/PeMo
flutter analyze
Analyzing week4_api...                                                  
No issues found! (ran in 7.7s)


hasil refactor 

![Hasil Refactor](screenshots/hasilRefactor.jpeg) 


Refleksi
Mengapa UI dilarang memanggil Dio langsung? Apa yang rusak jika aturan ini dilanggar?
Agar UI tidak bergantung pada detail HTTP/API Jika dilanggar, logic networking tersebar di banyak widget, sulit dites
Kapan pagination client-side cukup, dan kapan harus mengandalkan pagination server (_page/_limit)?
Client-side cukup jika dataset kecil dan seluruh data aman/efisien dimuat sekaligus
Bagaimana exception repository berubah menjadi AsyncError tanpa try/catch di setiap widget? Kapan try/catch eksplisit tetap dibutuhkan?
Repository melempar exception, lalu Riverpod FutureProvider/AsyncNotifier menangkap kegagalan tersebut dan mengeksposnya sebagai AsyncError. try/catch di widget hanya diperlukan jika UI perlu menangani error secara khusus atau melakukan recovery tertentu.
Bagian mana dari hasil AI yang Anda perbaiki, dan mengapa?
tidak ada  
