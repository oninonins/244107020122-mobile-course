# AI Log: Pencarian Pengumuman

Dokumen wajib Minggu 9. Berisi prompt, konteks, output awal, verifikasi, dan
keputusan terima atau tolak.

| | |
|---|---|
| Fitur | Pencarian pengumuman dengan empty state |
| Project | `09-week-9-ai-assisted-development/campus_notify` |
| Arsitektur | feature-first, presentation → domain ← data |
| State | Riverpod 3 |
| Hasil | 48 test menjadi 71 test |

---

## 1. Prompt yang diberikan

### Formula 5 slot

```
Peran: senior Flutter dev
Konteks: feature-first (presentation -> domain <- data), Riverpod 3,
  Dio, tanpa SQLite. Project campus_notify hasil refactor Week 7.
  Kontrak AnnouncementRepository saat ini hanya fetchById(String id).
  Entity Announcement: id String, title, body.
Tugas: tambah fitur pencarian pengumuman. Halaman daftar baru dengan kolom
  cari, filter yang bisa diuji tanpa widget, dan dua empty state
  (belum ada data vs tidak cocok).
Batas: jangan ubah arsitektur. Filter harus di domain, bukan di widget.
  Jangan panggil repository dari build(). Maksimal 2 file baru di lib/.
Output: kode + test untuk filter murni + test widget empty state.
```

### Konteks yang ditempel

Yang disertakan:

- Isi `announcement_repository.dart` (kontrak yang akan diubah)
- Isi `announcement.dart` (entity, untuk tahu field yang tersedia)
- Isi `announcement_providers.dart` (pola provider yang sudah ada)
- Versi package dari `pubspec.yaml`: `flutter_riverpod ^3.4.3`

Yang **tidak** disertakan:

- API key, token, atau `google-services.json`
- Seluruh repo
- File `auth/` dan `notifications/` yang tidak relevan

### Satu hal yang sengaja disebut

Prompt menyebut **"jangan panggil repository dari build()"**. Itu batas yang
dipilih karena versi paling naif dari fitur pencarian adalah memanggil
`ref.read(...)` langsung di dalam `build()`, dan pola itu sudah pernah muncul
sebagai masalah di Week 7.

---

## 2. Ringkasan output awal

Draf pertama menghasilkan:

| File | Baris | Isi |
|---|---|---|
| `domain/usecases/search_announcements.dart` | 62 | `filter()` statis + use case |
| `data/repositories/mock_announcement_repository.dart` | +18 | `fetchAll()` |
| `domain/repositories/announcement_repository.dart` | +4 | `fetchAll()` di kontrak |
| `presentation/providers/announcement_providers.dart` | +38 | query notifier + hasil |
| `presentation/pages/announcement_list_page.dart` | 155 | daftar, cari, empty state |

Tiga test file: `search_announcements_test.dart`, `announcement_model_test.dart`,
`announcement_list_test.dart`.

---

## 3. Verifikasi 6 langkah, hasil apa adanya

### Langkah 1: baca tiap baris

Dilakukan. Bagian yang ditandai untuk diperiksa ulang: `FutureProvider` yang
membaca `searchQueryProvider`, karena setiap ketikan memicu pemanggilan ulang
`fetchAll()`.

### Langkah 2: cek import

```
rg "import 'package:flutter|import 'package:dio|import 'package:sqflite|import 'package:firebase" \
   lib/features/*/domain lib/core
```

**Nol hasil.** `search_announcements.dart` hanya mengimpor `core/failures.dart`
dan entity. Tidak ada Flutter, tidak ada Dio.

### Langkah 3: cek API

| API yang dipakai | Ada di versi ini? | Cara cek |
|---|---|---|
| `Notifier` dan `NotifierProvider` | Ya | Sudah dipakai di `auth_providers.dart` |
| `FutureProvider` | Ya | Sudah dipakai di `sessionDebugProvider` |
| `firstOrNull` pada `Iterable` | Ya | Sudah dipakai di repository yang ada |
| `StateProvider` | **Tidak** | Dihapus di Riverpod 3, jadi memakai `Notifier` |

`StateProvider` adalah kandidat halusinasi yang paling mungkin di sini, karena
dokumentasi Riverpod versi lama masih memakainya. Sudah dihindari sejak awal.

### Langkah 4: `flutter analyze`

Hasil pertama, apa adanya:

```
error - Missing concrete implementation of 'AnnouncementRepository.fetchAll'.
  Try implementing the missing method, or make the class abstract
  test\domain\get_announcement_test.dart:13:7
  non_abstract_class_inherits_abstract_member
```

**Ini temuan pertama.** Menambah satu metode ke kontrak langsung memecah fake
yang sudah ada di test lama. Bukan hal buruk: compiler menunjukkan setiap tempat
yang harus ikut diperbarui. Fake ditambahkan `fetchAll`, lalu analyze bersih.

### Langkah 5: tulis test sukses dan gagal

Test ditulis untuk tiga hal: filter murni, `fromJson`, dan widget empty state.
Menjalankannya memunculkan temuan kedua, dijelaskan di bagian 4.

### Langkah 6: uji manual

Dijalankan di perangkat Android nyata pada 29 Oktober 2026, pukul 14.01.

| Yang diuji | Hasil | Bukti |
|---|---|---|
| Daftar penuh, query kosong | Tiga pengumuman tampil berurutan | `screenshots/search-list.jpeg` |
| Query cocok (`uts`) | Satu pengumuman tersisa | `screenshots/search-result.jpeg` |
| Query tidak cocok (`zzz`) | Empty state muncul dengan pesan yang menyebut query | `screenshots/search-empty.jpeg` |
| Kartu menu di dashboard | Muncul dan bisa dibuka | `screenshots/search-dashboard.jpeg` |

Satu hal yang **belum** terbukti dari screenshot: pencarian menyentuh isi, bukan
hanya judul. Query `uts` ada di judul dan isi sekaligus, jadi tidak membedakan.
Bukti untuk itu ada di test `mencocokkan isi, bukan hanya judul`, yang memakai
query `A2`. Di aplikasi, query `A2` hanya akan memunculkan "Jadwal kuliah
berubah", karena kata itu tidak ada di judulnya.

---

## 4. Temuan nyata: bug `fromJson` yang memblokir fitur

### Cara menemukannya

Test pertama untuk `MockAnnouncementRepository.fetchAll()` gagal, bukan karena
asersi salah, melainkan karena exception:

```
type 'String' is not a subtype of type 'num?' in type cast
  announcement_model.dart 16:23  new AnnouncementModel.fromJson
```

### Akar masalah

```dart
// sebelum
id: (json['id'] as num?)?.toString() ?? (json['id'] as String?) ?? '',
```

`as num?` adalah cast, bukan pemeriksaan. Untuk nilai `String` ia **melempar**,
bukan mengembalikan `null`. Seed repository memakai id `String`:

```dart
{'id': '1', 'title': 'Pendaftaran UTS dibuka', ...}
```

Jadi setiap pembacaan pengumuman gagal. `fetchById` juga terkena, tapi tidak
pernah ketahuan karena tidak ada test yang memanggil `fromJson` langsung.

### Kenapa test lama tidak menangkapnya

`widget_test.dart` memeriksa `find.text('Pengumuman #3')`, dan teks itu adalah
judul `AppBar` yang dirender di semua state, termasuk `error`. Jadi test lulus
meski isi halaman gagal dimuat.

### Perbaikan

```dart
// sesudah
id: json['id']?.toString() ?? '',
```

`toString()` menerima `String` maupun angka, dan mengembalikan `null` kalau
field hilang.

### Bukti sebelum dan sesudah

```
# sebelum perbaikan
00:00 +0 -1: AnnouncementModel.fromJson menerima id bertipe String [E]
  type 'String' is not a subtype of type 'num?' in type cast

00:00 +2 -3: MockAnnouncementRepository fetchAll membaca seluruh seed [E]
  Expected: null
    Actual: LocalFailure:<Gagal membaca daftar pengumuman:
            type 'String' is not a subtype of type 'num?' in type cast>

# sesudah perbaikan
00:00 +7: All tests passed!
```

Tujuh test baru mengunci perilaku ini: id `String`, id `int`, id hilang, field
lain hilang, `fetchAll` membaca seed, `fetchAll` mengembalikan entity, dan
`fetchById` tetap bekerja.

---

## 5. Temuan kedua: test yang saya tulis sendiri salah

Saat test widget empty state dijalankan:

```
Expected: exactly one matching candidate
  Actual: Found 2 widgets with text containing zzz-tak-ada
```

Penyebabnya asersi `find.textContaining('zzz-tak-ada')`. Teks itu muncul dua
kali: di kolom input dan di pesan empty state. Yang diperiksa seharusnya
pesannya, bukan isi kolom.

**Ini bukan bug aplikasi.** Kode benar, test-nya yang terlalu longgar. Diperbaiki
menjadi memeriksa teks pesan lengkap.

Dicatat di sini karena verifikasi yang jujur harus membedakan bug kode dari
kesalahan test.

---

## 6. Tabel terima dan tolak

### Diterima

| Saran | Alasan | Bukti |
|---|---|---|
| Filter sebagai fungsi statis di use case | Bisa diuji dengan `test()` biasa, tanpa `pumpWidget` | 10 test di `search_announcements_test.dart`, semuanya `test()` bukan `testWidgets` |
| Cocokkan ke judul **dan** isi | Pengguna mencari "A2" untuk ruang kelas, dan kata itu ada di isi | Test `mencocokkan isi, bukan hanya judul` |
| Dua empty state berbeda | "Belum ada data" dan "tidak cocok" butuh tindakan berbeda | Dua test widget terpisah |
| `fetchAll` ditambahkan ke kontrak | Sekarang ada konsumennya, jadi penolakan Week 7 sudah kedaluwarsa | Komentar kontrak diperbarui dengan alasan |
| Query lewat `NotifierProvider` | `StateProvider` dihapus di Riverpod 3 | `flutter analyze` bersih |

### Ditolak

| Saran | Alasan penolakan |
|---|---|
| Filter di dalam `build()` halaman | Satu-satunya cara menguji jadi `testWidgets` yang memompa seluruh halaman. Melanggar batas yang ditulis di prompt |
| Menyaring di repository (`fetchAll(query)`) | Repository jadi tahu aturan bisnis. Kalau nanti sumbernya SQL, filter harus ditulis ulang di SQL, dan aturannya bercabang dua tempat |
| `StateProvider` untuk kata kunci | Tidak ada di Riverpod 3. Memakai `NotifierProvider` |
| Menambah `fetchAll` tanpa use case, provider memanggil repository langsung | Presentation jadi terikat ke kontrak repository, melanggar pola Week 7 |
| Menyimpan hasil filter di state notifier | `FutureProvider` turunan sudah cukup. Menyimpan hasil berarti dua sumber kebenaran yang bisa tidak sinkron |

### Satu yang diterima dengan catatan

`FutureProvider` memanggil ulang `fetchAll()` setiap ketikan. Untuk tiga
pengumuman di memori, itu tidak terasa. Untuk data dari jaringan, itu buruk:
setiap huruf memicu satu request.

Dicatat sebagai batasan, bukan diperbaiki di sini, karena menambah debounce
berarti menambah state dan timer yang harus diuji sendiri. Kalau fitur ini
dipakai dengan data sungguhan, debounce 300 ms wajib ditambahkan.

---

## 7. Keputusan per file

| File | Keputusan |
|---|---|
| `search_announcements.dart` | **Terima**, dengan filter dipisah sebagai fungsi statis |
| `announcement_list_page.dart` | **Terima + refactor**: `build()` versi pertama 72 baris, dipecah menjadi `_SearchField` dan `_ResultBody`. Sekarang 23 baris |
| `announcement_repository.dart` | **Terima**, dengan komentar diperbarui agar penolakan Week 7 dijelaskan |
| `mock_announcement_repository.dart` | **Terima**, dengan `try/catch` ditambahkan supaya satu baris rusak tidak menjatuhkan seluruh daftar |
| `announcement_model.dart` | **Tolak draf awal, tulis manual.** Perbaikan bug ditulis sendiri setelah test membuktikan penyebabnya |
| `announcement_providers.dart` | **Terima**, dengan `searchQueryProvider` dipisah dari `searchResultsProvider` |

### Refactor yang dilakukan

Codelab meminta fungsi di atas 40 baris dipecah. Versi pertama `build()` di
`announcement_list_page.dart` mencapai 72 baris karena memuat kolom pencarian,
empat cabang state, dan pembentukan daftar sekaligus.

Setelah dipecah:

| Bagian | Isi | Baris |
|---|---|---|
| `build()` halaman | Hanya menyusun `Scaffold` dari dua widget | 23 |
| `_SearchField` | Kolom teks dan tombol hapus | 40 |
| `_ResultBody` | Loading, gagal, dua empty state, daftar | 41 |
| `_AnnouncementTile` | Satu kartu pengumuman | 19 |
| `_Message` | Ikon dan teks untuk keadaan kosong | 23 |

71 test tetap lulus setelah pemecahan, termasuk enam test widget yang menyentuh
langsung kunci `search-field`, `search-clear`, dan `search-empty`. Itu yang
membuktikan refactor tidak merusak perilaku.

---

## 8. Bukti mesin

```
flutter analyze -> No issues found!
flutter test    -> All tests passed! (71 test)
dart format     -> Formatted 41 files (0 changed)
```

Tiga grep sterilitas:

```
rg "Dio\(|openDatabase|...|jsonDecode" lib/features/*/presentation
-> nol hasil

rg "import 'package:flutter|...|package:firebase" lib/features/*/domain lib/core
-> nol hasil

rg "toMap|fromMap|toJson|fromJson" lib/features/*/domain
-> nol hasil
```

---

## 9. Yang belum diverifikasi

- **Kasus gagal belum diuji manual.** Repository gagal dan daftar benar-benar
  kosong baru diuji lewat test widget, belum di perangkat.
- **Debounce.** Setiap ketikan memicu `fetchAll()`. Aman untuk data di memori,
  bermasalah untuk data jaringan.
- **Pencarian pada data besar.** Filter berjalan di memori setelah mengambil
  seluruh daftar. Untuk ratusan pengumuman, itu masih wajar. Untuk ribuan,
  penyaringan sebaiknya dipindah ke sumber data.

Tidak ada bagian di dokumen ini yang diisi dengan contoh karangan. Temuan di
bagian 4 dan 5 adalah output asli dari `flutter test` saat dikerjakan.
