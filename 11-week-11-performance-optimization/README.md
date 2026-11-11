# Week 11: Optimasi Performa

Mengoptimalkan `campus_notify` hasil Week 9. Fokusnya bukan menambah fitur,
melainkan menghapus pekerjaan yang tidak perlu: pengambilan data berulang,
penyaringan yang dijalankan tiap ketikan, dan rebuild yang terlalu luas.

Empat optimasi diterapkan, enam ditolak setelah diperiksa.

## Tujuan

- Menggunakan DevTools untuk profiling CPU dan memori.
- Mengidentifikasi dan mengurangi widget rebuild yang tidak perlu.
- Menerapkan lazy loading, pagination, dan optimasi gambar bila relevan.
- Mengoptimalkan jaringan dengan caching dan strategi offline-first.
- Memperbaiki bottleneck pada aplikasi yang sudah ada.

## Ringkasan Optimasi

| # | Optimasi | Bukti | Status |
|---|---|---|---|
| 1 | Cache daftar, filter di memori | 6 pemanggilan jadi 1 | Diterapkan |
| 2 | Debounce 300 ms | Test ketikan beruntun | Diterapkan |
| 3 | Pisahkan state FCM dari halaman | 0 rebuild kartu sesi | Diterapkan |
| 4 | `RepaintBoundary` pada kartu FCM | Belum diukur | Diterapkan sebagian |
| 5 | `select` pada `authStateProvider` | Rebuild sama, tidak berkurang | **Ditolak** |
| 6 | `ListView.builder` di dashboard | 5 item tetap | **Ditolak** |
| 7 | Pagination infinite scroll | 3 data, tidak ada endpoint | **Ditolak** |
| 8 | `CachedNetworkImage` | Tidak ada gambar jaringan | **Ditolak** |
| 9 | Repository cache stale-while-revalidate | Tidak ada backend | **Ditolak** |
| 10 | `RepaintBoundary` di semua kartu | Biaya memori | **Ditolak** |

Rincian tiap temuan ada di `docs/performance-findings.md`, dan hasil pengukuran
di `docs/performance-report.md`.

## Hasil yang Dicapai

### Angka yang terukur

| Metrik | Baseline | Setelah |
|---|---|---|
| Pemanggilan `fetchAll` saat mengetik 5 huruf | 6 | **1** |
| Rebuild kartu sesi saat token FCM berubah | seluruh halaman | **0** |
| `build()` HomePage | 161 baris, satu widget | 39 baris, 5 widget |
| Kelas widget di `home_page.dart` | 2 | 5 |
| Test | 71 | 80 |

### Bukti mesin

```
flutter analyze -> No issues found!
flutter test    -> All tests passed! (80 test)
dart format     -> Formatted 43 files (0 changed)
```

Tiga grep sterilitas tetap nol:

```
rg "Dio\(|openDatabase|getDatabasesPath|FlutterSecureStorage|SharedPreferences\.getInstance|jsonDecode" \
   lib/features/*/presentation
-> nol hasil

rg "import 'package:flutter|import 'package:dio|import 'package:sqflite|import 'package:firebase" \
   lib/features/*/domain lib/core
-> nol hasil

rg "toMap|fromMap|toJson|fromJson" lib/features/*/domain
-> nol hasil
```

### Yang belum diukur

| Metrik | Status |
|---|---|
| Jank frame | **Terukur**: 1 sebelum, 0 sesudah |
| Rata-rata FPS sebelum | 57, terbaca dari screenshot |
| Rata-rata FPS sesudah | Tidak terbaca, skala sumbu Y terpotong |
| Heap usage | Belum diukur, butuh tab Memory |

Angka jank dan FPS berasal dari rekaman `flutter run --profile` di perangkat,
bukan dari mode debug. Bagian Screenshot di bawah memuat gambarnya.

Tidak ada angka flame chart yang dikarang di README ini.

## Detail Optimasi

### 1. Cache daftar, filter di memori

Sebelumnya `searchResultsProvider` memanggil use case, dan use case memanggil
`fetchAll()` setiap kali. Provider itu menonton kata kunci, jadi setiap ketikan
memicu pengambilan ulang seluruh daftar, lengkap dengan `Future.delayed` dan
parsing JSON.

Sekarang dua provider dipisah:

| Provider | Peran |
|---|---|
| `allAnnouncementsProvider` | Mengambil seluruh daftar **sekali** |
| `searchResultsProvider` | Hanya memfilter hasilnya di memori |

Dampak terbesarnya bukan pada rebuild widget, melainkan pada pekerjaan yang
dihilangkan: 5 kali pengambilan dan 5 kali parsing untuk satu kata enam huruf.

### 2. Debounce 300 ms

Kolom pencarian punya dua kata kunci dengan peran berbeda. `searchQueryProvider`
mengisi kolom teks dan mengubah tombol hapus seketika. `debouncedQueryProvider`
menunggu 300 ms sebelum dipakai menyaring.

Kata kunci kosong sengaja diteruskan seketika, tanpa jeda, supaya tombol hapus
terasa langsung.

### 3. Memisahkan state FCM dari halaman

`HomePage` dulu satu `ConsumerStatefulWidget` 316 baris dengan satu `setState`
(161 baris di antaranya ada di `build()`).
Sekarang `ConsumerWidget` tanpa state, dan state FCM pindah ke `_FcmDebugCard`
yang punya `setState` sendiri.

Kartu menu jadi `StatelessWidget` dengan argumen `const`, sehingga tidak pernah
dibangun ulang saat halaman induk rebuild.

### 4. `RepaintBoundary`

Dipakai hanya pada kartu FCM, area yang paling sering berubah. Tidak dipasang di
semua kartu karena setiap boundary menyimpan lapisan tambahan.

Dampaknya belum dipisahkan dari optimasi lain. Rekaman frame chart yang ada
memakai skenario gabungan, jadi tidak bisa menunjukkan berapa bagian yang
berasal dari boundary ini. Kalau ingin dibuktikan, raster thread harus direkam
terpisah dengan dan tanpa boundary.

## Satu Optimasi yang Dibatalkan Setelah Diukur

`select((s) => s.isLoading)` pada `authStateProvider` di halaman login terlihat
seperti optimasi yang benar: halaman hanya butuh status sibuk, bukan seluruh
`AsyncValue`.

Setelah diukur, jumlah rebuild **sama persis**. Penyebabnya, setiap transisi auth
melewati `AsyncLoading`, jadi `isLoading` memang berubah false -> true -> false.
Kedua rebuild itu diperlukan dan `select` tidak menghapus satu pun.

Perubahan itu dibatalkan, dan test penjaga sekarang mencatat kesamaan angkanya
supaya tidak pernah diklaim sebagai optimasi.

## Stack Teknologi

| Teknologi | Versi | Peran |
|---|---|---|
| Flutter | 3.47.5 | Framework |
| Dart | 3.13.4 | Bahasa |
| flutter_riverpod | ^3.4.3 | State management dan DI |
| go_router | ^18.0.2 | Routing |
| dio | ^5.11.1 | HTTP client |
| flutter_secure_storage | ^11.2.0 | Penyimpanan token |
| firebase_core / firebase_messaging | ^4.15.0 / ^16.7.0 | Push notification |
| flutter_local_notifications | ^22.3.1 | Banner notifikasi |
| flutter_lints | ^6.0.0 | Analisis statis |

Tidak ada package baru. Semua optimasi memakai yang sudah ada.

## Cara Menjalankan

```bash
cd 11-week-11-performance-optimization/campus_notify
flutter pub get

# Salin google-services.json ke android/app/ (tidak di-commit)
flutter run
```

Untuk profiling, mode debug tidak akurat. Pakai profile:

```bash
flutter run --profile
```

Pemeriksaan mesin:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Struktur Folder

```
11-week-11-performance-optimization/
├── campus_notify/          salinan Week 9 + optimasi
├── docs/
│   ├── performance-findings.md   temuan dan yang ditolak
│   └── performance-report.md     baseline, optimasi, verifikasi
├── screenshots/            frame chart sebelum dan sesudah
└── README.md
```

## Screenshot

Dua rekaman dari tab **Performance** di DevTools, diambil dengan
`flutter run --profile` di perangkat Android nyata. Mode profile dipakai karena
mode debug punya overhead yang membuat angkanya tidak sah.

| Berkas | Isi |
|---|---|
| `screenshots/before-profile.png` | Week 9, sebelum optimasi |
| `screenshots/after-profile.png` | Week 11, sesudah optimasi |

### Sebelum optimasi

![Frame chart Week 9](screenshots/before-profile.png)

Yang terlihat:

- Rata-rata **57 FPS**, di bawah target 60.
- Satu frame **merah** di sekitar frame 633, menembus garis 17 ms sampai
  sekitar 27 ms. Itu jank: frame yang butuh lebih dari satu kali budget 16,67 ms.
- Frame sesudahnya masih di atas garis 7 ms, lebih tinggi daripada frame sebelum
  kejadian.

### Sesudah optimasi

![Frame chart Week 11](screenshots/after-profile.png)

Yang terlihat:

- Tidak ada frame merah pada rentang yang direkam.
- Semua bar biru, berada jauh di bawah garis 17 ms.
- Skala sumbu Y pada gambar ini terpotong, jadi rata-rata FPS-nya tidak terbaca
  dari gambar. Yang bisa dinyatakan hanya tidak ada jank, bukan angka FPS
  tertentu.

### Yang dibandingkan, dan yang tidak

Yang **bisa** disimpulkan dari dua gambar ini: frame merah hilang. Satu jank
sebelum optimasi, nol jank sesudahnya.

Yang **tidak bisa** disimpulkan:

- Angka FPS rata-rata sesudah optimasi, karena skala sumbu Y terpotong.
- Porsi dampak tiap optimasi. Kedua rekaman memakai skenario yang sama, tetapi
  tidak memisahkan mana yang berasal dari cache, debounce, atau pemisahan state.
- Dampak `RepaintBoundary`, karena raster thread tidak di-zoom terpisah.

Untuk angka yang pasti, bukti yang dipakai tetap test penghitung: `fetchAll`
enam kali menjadi satu, dan nol rebuild kartu sesi saat token berubah.

## Utang dan Batasan

- **Profiling baru satu skenario.** Jank turun dari 1 menjadi 0 pada rekaman
  yang ada. Heap usage belum diukur, dan angka FPS sesudah optimasi tidak
  terbaca karena skala sumbu Y terpotong.
- **`RepaintBoundary` belum terbukti.** Efeknya hanya terlihat di flame chart.
  Kalau tidak ada bedanya, sebaiknya dicopot.
- **Debounce belum diuji di perangkat.** Yang diuji baru perilaku provider lewat
  test, belum rasa mengetik di HP.
- **Cache tidak punya invalidasi.** `allAnnouncementsProvider` menyimpan daftar
  selama provider hidup. Kalau nanti ada fitur menambah pengumuman, provider itu
  harus di-invalidate setelah data berubah.
- **Filter berjalan di memori.** Untuk puluhan pengumuman masih wajar. Untuk
  ribuan, penyaringan sebaiknya pindah ke sumber data.

## Refleksi

### Optimasi mana yang paling besar dampaknya, dan mengapa?

Cache daftar. Bukan karena ia menghapus rebuild, tetapi karena ia menghapus
pekerjaan yang paling mahal: pengambilan data dan parsing.

Bedanya penting. Rebuild widget memakan waktu dalam hitungan mikrodetik sampai
milidetik. `Future.delayed(150 ms)` dan parsing seluruh seed memakan waktu yang
jauh lebih besar, dan itu terjadi berulang pada setiap huruf yang diketik.
Menghapus enam pengambilan menjadi satu berarti menghilangkan sekitar 750 ms
penundaan kumulatif untuk satu kata enam huruf.

Pelajarannya: cari pekerjaan yang paling mahal dulu, bukan yang paling mudah
diubah. Menambahkan `const` pada lima widget terasa seperti optimasi, tetapi
dampaknya tidak terlihat dibanding satu `fetchAll` yang berlebihan.

### Bagaimana memverifikasi bahwa optimasi benar-benar bekerja, bukan placebo?

Dengan menghitung, bukan dengan merasa. Dua alat ukur dipakai:

**Penghitung pemanggilan.** Repository palsu menaikkan counter setiap
`fetchAll()` dipanggil. Angkanya 6 sebelum, 1 sesudah.

**Penghitung build.** Widget pembantu menaikkan counter statis di `build()`.
Saat token berubah, angkanya 0 untuk kartu sesi.

Yang paling meyakinkan adalah **eksperimen balik**: kode optimasi dikembalikan
sementara ke versi lama, lalu test dijalankan. Hasilnya gagal dengan
`Expected: <1>, Actual: <6>`. Itu membuktikan test-nya benar-benar mengukur
perubahan, bukan sekadar lulus karena kebetulan.

Tanpa eksperimen balik itu, test yang selalu hijau tidak membuktikan apa pun.

### Trade-off apa yang dihadapi?

**Kompleksitas versus keterbacaan.** Sebelumnya satu provider, satu use case,
satu alur. Sekarang tiga provider: daftar lengkap, kata kunci mentah, kata kunci
setelah jeda. Jumlah kode bertambah 81 baris di `announcement_providers.dart`.

Yang membuatnya layak: setiap provider punya satu alasan keberadaan yang jelas,
dan semuanya diuji. Yang membuatnya berisiko: pembaca baru harus memahami
mengapa ada dua kata kunci sebelum mengubah apa pun. Karena itu komentar di file
itu menjelaskan peran masing-masing, bukan hanya isinya.

**Memori versus kecepatan.** Cache menyimpan seluruh daftar di memori. Untuk
tiga pengumuman tidak terasa. Untuk seribu, itu pilihan yang harus ditinjau
ulang, dan itulah sebabnya batasannya dicatat.

**Rebuild versus pemisahan widget.** Memisah `_FcmDebugCard` menambah satu kelas
dan satu `ConsumerStatefulWidget`. Alternatifnya mempertahankan satu widget besar
yang lebih sederhana dibaca. Yang dipilih pemisahan, karena state FCM berubah
jauh lebih sering daripada state lain di halaman itu.

### Kapan optimasi prematur sebaiknya dihindari?

Saat tidak ada cara mengukur dampaknya, dan saat masalahnya belum ada.

Enam usulan di minggu ini ditolak dengan alasan itu. Yang paling jelas:
`ListView.builder` di dashboard. Halaman itu punya lima item tetap. Menggantinya
ke `builder` menambah `itemBuilder`, penomoran index, dan satu lapisan abstraksi,
sementara jumlah widget yang dibangun tetap lima.

Pagination lebih ekstrem lagi. Seed berisi tiga pengumuman. Menulis infinite
scroll berarti menulis kode yang tidak bisa diuji dengan data nyata, dan
kemungkinan besar ditulis salah karena tidak pernah menghadapi batas halaman.

Aturan yang kupakai sekarang: **optimasi dikerjakan kalau ada angka yang
menunjukkan masalah, atau kalau ada batasan keras yang diketahui** (misalnya
daftar yang bisa berisi ribuan item). Selain itu, dicatat sebagai utang, bukan
dikerjakan.

Yang paling berharga dari minggu ini justru satu penolakan: `select` pada
`authStateProvider`. Perubahan itu terlihat benar, lolos `flutter analyze`, dan
hampir kutulis sebagai keberhasilan. Angkanya sama persis, dan tanpa pengukuran
aku akan melaporkan optimasi yang tidak mengoptimalkan apa pun.
