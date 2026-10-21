# AI Review vs Keputusan

Dokumen wajib Minggu 8. Berisi prompt review, lima temuan, bukti, dan keputusan
final.

| | |
|---|---|
| Cakupan review | seluruh `07-week-7-clean-architecture/campus_notify` |
| Commit yang direview | `44a5e48` (ujung `develop`) |
| Stack | feature-first Clean Architecture, Riverpod, GoRouter, Dio, Firebase |
| Mesin | Flutter 3.47.5, Dart 3.13.4 |

## Prompt yang diberikan

```
Review PR Flutter ini sebagai senior Flutter dev.
Konteks: feature-first Clean Architecture (presentation -> domain <- data),
Riverpod, GoRouter, SQLite + Dio.
Fokus: kebenaran, arsitektur, dan test. Abaikan style.
Berikan 5 temuan teratas + level (blocker/saran)
+ alasan + usulan potongan kode perbaikan.
```

## Ringkasan lima temuan

| # | Temuan | Level | Keputusan | Status |
|---|---|---|---|---|
| 1 | `AnnouncementModel.fromJson` melempar `TypeError` untuk id bertipe `String` | Blocker | Diterima | **Belum diperbaiki**, dicatat di issue #7 |
| 2 | Tujuh import lintas fitur, termasuk `presentation` ke `presentation` | Blocker | Diterima sebagian | Ditunda, dicatat |
| 3 | `_toggleTopic` mengabaikan `failure` dan menampilkan pesan terbalik | Blocker | Diterima | Dicatat |
| 4 | Ternary mati di `_toggleTopic` | Saran | Diterima | Dicatat |
| 5 | `invalidate` tersebar di tiga titik | Saran | Diterima | Sudah ada issue #5 |

Empat usulan AI ditolak dengan alasan tertulis di bagian akhir.

---

## Temuan 1: `fromJson` gagal untuk id bertipe String

**Level: Blocker.**

### Klaim

`AnnouncementModel.fromJson` memakai `as num?` untuk `id`. Cast itu melempar
`TypeError` kalau nilainya `String`, bukan mengembalikan `null`. Karena seed
repository memakai id `String`, seluruh jalur baca pengumuman gagal.

### Bukti

Kode yang bermasalah, `announcement_model.dart:16`:

```dart
id: (json['id'] as num?)?.toString() ?? (json['id'] as String?) ?? '',
```

Seed di `mock_announcement_repository.dart:45,50,55` memakai `String`:

```dart
'id': '1',
```

Reproduksi dengan test sementara, hasilnya bukan asersi gagal melainkan exception:

```
00:00 +0 -1: fromJson dengan id String [E]
  type 'String' is not a subtype of type 'num?' in type cast
  package:campus_notify/features/announcements/data/models/announcement_model.dart 16:23
    new AnnouncementModel.fromJson

00:00 +0 -2: repository seed benar-benar bisa dibaca [E]
  type 'String' is not a subtype of type 'num?' in type cast
  package:campus_notify/features/announcements/data/models/announcement_model.dart 16:23
    new AnnouncementModel.fromJson
  package:campus_notify/features/announcements/data/repositories/mock_announcement_repository.dart 37:39
    MockAnnouncementRepository.fetchById
```

### Kenapa test yang ada tidak menangkapnya

`test/widget_test.dart:92` memeriksa:

```dart
expect(find.text('Pengumuman #3'), findsOneWidget);
```

`'Pengumuman #3'` adalah judul `AppBar` di `announcement_page.dart:28`, yang
dirender di semua state termasuk `error`. Jadi test itu lulus meski isi halaman
gagal dimuat. Tidak ada satu pun test yang memanggil `AnnouncementModel.fromJson`
langsung.

### Dampak

Kartu "Pengumuman Campus" di dashboard membuka halaman yang menampilkan pesan
error, bukan judul dan isi pengumuman. Ini terlihat saat demo.

### Usulan perbaikan

```dart
static String _idOf(Object? value) => value?.toString() ?? '';

factory AnnouncementModel.fromJson(Map<String, Object?> json) {
  return AnnouncementModel(
    id: _idOf(json['id']),
    title: (json['title'] as String?) ?? '',
    body: (json['body'] as String?) ?? '',
  );
}
```

### Keputusan

**Diterima sebagai temuan, tetapi perbaikannya belum dikerjakan** atas keputusan
pemilik project. Dicatat di issue #7 supaya tidak hilang.

Alasan penundaan: perbaikan ini menyentuh `data`, dan pada saat review
dikerjakan prioritasnya adalah menutup PR #2 dan menyelesaikan dokumen Week 8.
Risikonya dicatat terbuka di sini, bukan disembunyikan.

---

## Temuan 2: import lintas fitur

**Level: Blocker.**

### Klaim

Ada import dari satu fitur ke fitur lain, termasuk dari `presentation` ke
`presentation`. Codelab Minggu 7 menyebut fitur berkomunikasi lewat rute, bukan
lewat import widget.

### Bukti

```
$ rg -n "^import '.*(auth|announcements|notifications)/" lib/features

notifications/domain/usecases/register_device.dart:2   ../../../auth/domain/repositories/token_store.dart
notifications/data/dio_device_registrar.dart:4         ../../auth/data/api_client.dart
notifications/data/dio_device_registrar.dart:5         ../../auth/domain/repositories/auth_repository.dart
notifications/data/dio_device_registrar.dart:6         ../../auth/domain/repositories/token_store.dart
notifications/presentation/providers/push_providers.dart:9  ../../../auth/presentation/providers/auth_providers.dart
announcements/presentation/pages/home_page.dart:9      ../../../auth/presentation/providers/auth_providers.dart
announcements/presentation/pages/home_page.dart:10     ../../../notifications/presentation/providers/push_providers.dart
```

Tujuh import di empat file. Satu di antaranya salah hitung kalau grep dijalankan
tanpa hati-hati: `firebase_push_repository.dart:5` cocok karena nama package
`flutter_local_notifications`, bukan import lintas fitur.

### Penilaian

Tiga di antaranya masih bisa dipertahankan:

| Import | Alasan |
|---|---|
| `register_device.dart` ke `auth/domain/token_store.dart` | Domain ke domain. `POST /devices` memang butuh sesi |
| `dio_device_registrar.dart` ke `auth/domain/*` | Data ke domain, arah yang benar |
| `dio_device_registrar.dart` ke `auth/data/api_client.dart` | Data ke data, dan Dio hanya hidup di satu tempat |

Empat sisanya bermasalah karena `presentation` mengimpor `presentation`:

| Import | Masalah |
|---|---|
| `push_providers.dart` ke `auth_providers.dart` | Provider notifikasi membaca provider auth |
| `home_page.dart` ke `auth_providers.dart` | Halaman pengumuman membaca state auth |
| `home_page.dart` ke `push_providers.dart` | Halaman pengumuman membaca state notifikasi |

### Usulan AI

Pindahkan `sessionDebugProvider`, `tokenStoreProvider`, dan aksi logout ke
`lib/core/providers.dart`, lalu semua fitur membaca dari sana.

### Keputusan

**Ditolak, dengan alasan.** Usulan itu memindahkan provider yang bergantung pada
`TokenStore` dan `AuthNotifier` ke `lib/core/`. `core/` di project ini
diperuntukkan bagi kode yang tidak punya pemilik fitur, dan grep sterilitas
Minggu 7 mensyaratkan `lib/core` bebas import Flutter. `auth_providers.dart`
mengimpor `flutter_riverpod`, jadi memindahkannya ke `core/` akan membuat grep
itu tidak nol.

Temuan tetap dicatat sebagai utang arsitektur. Yang disepakati: satu tautan
`notifications` ke `auth` dibiarkan karena `POST /devices` butuh header
`Authorization`, sementara `home_page.dart` yang mengimpor dua fitur sekaligus
perlu dipecah saat ada waktu.

---

## Temuan 3: `_toggleTopic` mengabaikan kegagalan

**Level: Blocker.**

### Klaim

`_toggleTopic` memakai `result.subscribed` untuk menentukan pesan SnackBar, tetapi
tidak pernah memeriksa `result.failure`. Kalau pemanggilan gagal, nilai
`subscribed` kembali ke nilai lama, sehingga pesan yang muncul adalah kebalikan
dari yang diminta pengguna, tanpa pemberitahuan error.

### Bukti

`home_page.dart:97-111`:

```dart
final subscribe = !_topicSubscribed;
final result = await ref
    .read(topicSubscriptionProvider)
    .setSubscribed(value: subscribe);
if (!mounted) return;
setState(() => _topicSubscribed = result.subscribed);
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(
      result.subscribed
          ? 'Berlangganan topik ${result.subscribed ? topicName : ''}'.trim()
          : 'Berhenti berlangganan topik $topicName',
    ),
  ),
);
```

`FirebasePushRepository.setSubscribed` mengembalikan
`(subscribed: _topicSubscribed, failure: LocalFailure(...))` saat gagal, dan
`_topicSubscribed` tetap bernilai lama.

Skenario: pengguna menekan "Berlangganan topik" saat perangkat offline.
`subscribe` bernilai `true`, pemanggilan gagal, `result.subscribed` tetap
`false`, lalu SnackBar berbunyi **"Berhenti berlangganan topik
pengumuman-kampus"**. Pesan itu kebalikan dari tindakan pengguna, dan tidak ada
informasi bahwa permintaan gagal.

### Usulan perbaikan

```dart
if (result.failure != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.failure!.message)),
  );
  return;
}
setState(() => _topicSubscribed = result.subscribed);
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(
      result.subscribed
          ? 'Berlangganan topik $topicName'
          : 'Berhenti berlangganan topik $topicName',
    ),
  ),
);
```

### Keputusan

Diterima. Belum dikerjakan pada commit ini karena berada di `presentation` dan
menyentuh perilaku; perlu test widget sendiri. Dicatat bersama temuan 1.

---

## Temuan 4: ternary mati di `_toggleTopic`

**Level: Saran.**

### Klaim

`'Berlangganan topik ${result.subscribed ? topicName : ''}'.trim()` berada di
dalam cabang `result.subscribed` yang sudah bernilai benar. Jadi ternary itu
selalu menghasilkan `topicName`, dan `.trim()` tidak pernah memangkas apa pun.

### Bukti

`home_page.dart:106-109`. Di cabang `result.subscribed == true`, kondisi
`result.subscribed ? topicName : ''` pasti `topicName`.

### Keputusan

Diterima. Cukup ditulis `'Berlangganan topik $topicName'`. Digabung dengan
perbaikan temuan 3, karena berada di ekspresi yang sama.

---

## Temuan 5: `invalidate` tersebar di tiga titik

**Level: Saran.**

### Klaim

`sessionDebugProvider` sekarang di-invalidate dari tiga tempat. Penulis keempat
ke secure storage harus ingat menambahkannya, dan kalau lupa, kartu Debug token
menampilkan data basi tanpa error apa pun.

### Bukti

```
auth_providers.dart:76              ref.invalidate(sessionDebugProvider);   // login
auth_providers.dart:94              ref.invalidate(sessionDebugProvider);   // logout
push_providers.dart:59              onSessionRenewed: () => ref.invalidate(...)
```

### Keputusan

Diterima, dan sudah dicatat di issue #5 sebelum review ini. Usulan provider
revisi belum dikerjakan. Sama seperti temuan 2, ini utang arsitektur yang
diketahui, bukan kelalaian yang tidak disadari.

---

## Usulan AI yang ditolak

### Ditolak 1: pindahkan `api_errors.dart` ke `lib/core/`

**Usulan.** Fungsi pemetaan error dianggap util umum, jadi layak masuk `core/`.

**Alasan penolakan.** `api_errors.dart` mengimpor `package:dio`. Grep sterilitas
Minggu 7 mensyaratkan `lib/core` bebas import Flutter, Dio, SQLite, dan Firebase.
Memindahkannya ke `core/` akan membuat grep itu tidak nol.

```
$ rg "import 'package:flutter|import 'package:dio" lib/core
(sebelum: nol hasil)
```

### Ditolak 2: ganti record dengan `fpdart` `Either<Failure, T>`

**Usulan.** Record `({T? value, Failure? failure})` dianggap kurang ekspresif
dibanding `Either`.

**Alasan penolakan.** Codelab Minggu 7 menyebut pola kontraknya sama dan record
bawaan Dart sudah cukup. Menambah dependency untuk mengganti tipe bawaan
menambah satu hal yang harus dipelajari tim tanpa mengubah perilaku. Kalau nanti
butuh `map`/`fold` berantai, baru dipertimbangkan.

### Ditolak 3: ubah `Announcement.id` menjadi `int`

**Usulan.** Id sebaiknya `int` karena bentuknya angka.

**Alasan penolakan.** Nilai id berasal dari `data.route` payload FCM yang selalu
berupa teks, dan `announcement_page.dart` menerima `String` dari
`state.pathParameters`. Mengubahnya ke `int` menambah konversi di dua tempat
tanpa ada konsumen yang membutuhkannya. Perbaikan yang tepat adalah temuan 1,
yaitu membuat `fromJson` menerima kedua bentuk.

### Ditolak 4: rapikan panjang baris dan `prefer_const`

**Usulan.** Beberapa baris melewati 80 kolom, dan beberapa widget bisa memakai
`const`.

**Alasan penolakan.** Prompt meminta mengabaikan style, dan urusan itu sudah
ditangani `dart format` plus CI. Menuliskannya sebagai temuan review hanya
menambah kebisingan. Sudah dijalankan: 27 file diformat, dan langkah
`dart format --set-exit-if-changed` ditambahkan ke CI supaya tidak kembali
kotor.

---

## Checklist verifikasi

| Butir | Status | Bukti |
|---|---|---|
| Temuan benar-benar ada, dibuktikan grep, test gagal, atau reproduksi | Ya | Temuan 1 lewat test reproduksi, temuan 2 dan 5 lewat `rg`, temuan 3 lewat penelusuran jalur `setSubscribed` |
| Usulan tidak melanggar dependency rule | Ya | Usulan yang melanggar (pindahkan `api_errors` ke `core`) ditolak |
| AI hanya nitpick style | Sebagian | Usulan style ditolak dan diserahkan ke formatter/CI |
| Minimal 2 temuan terbukti benar | Ya | Temuan 1 dan 3, keduanya dengan bukti keras |
| Minimal 1 temuan ditolak dengan alasan tertulis | Ya | Empat usulan ditolak, semuanya beralasan |
| Keputusan final dan alasan teknis terdokumentasi | Ya | Bagian "Keputusan" pada tiap temuan |

## Bukti mesin setelah perubahan

```
flutter analyze -> No issues found!
flutter test    -> All tests passed! (48 test)
dart format     -> 36 file, 0 changed
CI              -> format + analyze + test, hijau
```

## Review sejawat PR #2

Sebagai pembanding, review sejawat pada PR #2 menemukan dua hal yang tidak
ditemukan reviewer AI:

| Temuan | Sumber | Status |
|---|---|---|
| Interceptor 401 menyimpan token tanpa memberi tahu pembaca lain | AI dan sejawat | Diperbaiki |
| Test hanya menguji jalur `logout()`, bukan `login()` | **Sejawat saja** | Diperbaiki |

Temuan kedua penting: reviewer AI menganggap test yang ada sudah memadai, dan
hanya review manusia yang mempertanyakannya. Setelah dibuktikan dengan
menghapus `ref.invalidate` di `login()`, test lama memang tetap hijau.

## Catatan untuk demo

Tiga hal yang perlu bisa dijelaskan tanpa membuka dokumen ini:

1. Temuan 1 nyata dan bisa direproduksi dengan satu baris:
   `AnnouncementModel.fromJson({'id': '3'})` melempar `TypeError`.
2. Temuan 2 sebagian ditolak karena `core/` harus bebas Dio. Yang tersisa adalah
   utang arsitektur, bukan temuan palsu.
3. Temuan 3 bukan sekadar soal pesan: pesannya kebalikan dari tindakan pengguna.
