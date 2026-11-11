# Performance Findings

Hasil pembacaan kode dan pengukuran pada `campus_notify` Week 9 sebagai baseline.
Setiap temuan punya lokasi, penjelasan, dan cara membuktikannya.

| | |
|---|---|
| Baseline | `09-week-9-ai-assisted-development/campus_notify` (identik dengan `main` sebelum Week 11) |
| Target | `11-week-11-performance-optimization/campus_notify` |
| Test baseline | 71 |
| Test setelah optimasi | 80 |

---

## Temuan 1: `fetchAll()` dijalankan ulang pada setiap ketikan

**Lokasi:** `features/announcements/presentation/providers/announcement_providers.dart:59`
dan `features/announcements/domain/usecases/search_announcements.dart:45`

**Kode bermasalah:**

```dart
final searchResultsProvider = FutureProvider<...>((ref) {
  final query = ref.watch(searchQueryProvider);       // berubah tiap ketikan
  return ref.watch(searchAnnouncementsProvider).call(query);
});

// di use case
final result = await _repository.fetchAll();          // dipanggil ulang
```

**Kenapa ini masalah.** Provider menonton kata kunci, dan setiap perubahan kata
kunci menjalankan ulang `call()`. `call()` memanggil `fetchAll()`, yang di
`MockAnnouncementRepository` berisi:

1. `Future.delayed(150 ms)`
2. Parsing seluruh seed lewat `AnnouncementModel.fromJson` untuk setiap baris

Jadi mengetik `jadwal` (6 huruf) berarti 6 kali pengambilan, 6 kali parsing, dan
sekitar 900 ms delay kumulatif. Untuk data dari jaringan, itu 6 request.

**Cara membuktikan.** Test dengan repository penghitung:

```dart
test('fetchAll hanya dipanggil sekali walau kata kunci berubah berkali-kali',
    () async {
  // ... 5 kali ganti kata kunci
  expect(repo.fetchAllCalls, setelahPemanasan);
});
```

Hasil pada kode lama: **6 pemanggilan**. Setelah perbaikan: **1**.

```
# kode lama
Expected: <1>
  Actual: <6>
```

---

## Temuan 2: tidak ada jeda pada kolom pencarian

**Lokasi:** `features/announcements/presentation/pages/announcement_list_page.dart:44`

**Kode bermasalah:**

```dart
onChanged: (value) => ref.read(searchQueryProvider.notifier).set(value),
```

**Kenapa ini masalah.** Setiap huruf langsung mengubah state. Bahkan setelah
temuan 1 diperbaiki, mengetik 10 huruf berarti 10 kali penyaringan dan 10 kali
rebuild daftar hasil. Penyaringan di memori memang murah, tetapi rebuild daftar
`ListView.separated` tidak gratis.

**Cara membuktikan.** Test yang mengetik cepat tanpa jeda:

```dart
for (final q in ['j', 'ja', 'jad', 'jadw', 'jadwal']) {
  container.read(searchQueryProvider.notifier).set(q);
}
expect(container.read(debouncedQueryProvider), '');
```

Sebelum jeda selesai, kata kunci yang dipakai masih nilai lama. Setelah 300 ms,
hanya nilai terakhir yang diteruskan.

---

## Temuan 3: satu `setState` membangun ulang seluruh halaman

**Lokasi:** `features/announcements/presentation/pages/home_page.dart` (316 baris
pada baseline, `build()` saja 161 baris)

**Kode bermasalah.** Seluruh dashboard adalah satu `ConsumerStatefulWidget`.
Setiap perubahan berikut memanggil `setState` di level halaman:

| Pemicu | Frekuensi |
|---|---|
| Token FCM baru dari `onTokenRefresh` | Setiap rotasi token |
| Status izin notifikasi | Saat tombol Minta izin ditekan |
| Status pengiriman device | Saat tombol Kirim token |
| Langganan topik | Saat toggle topik |

**Kenapa ini masalah.** Satu perubahan token membangun ulang `build()` 161 baris,
termasuk kartu sesi, kartu Debug token, dan dua kartu menu yang isinya tidak
berubah. Kartu menu bahkan tidak punya state sama sekali.

**Cara membuktikan.** Test dengan penghitung build:

```dart
sessionCardsBuildCount = 0;
push.emitToken('token-baru-dari-refresh');
await tester.pumpAndSettle();
expect(sessionCardsBuildCount, 0);
```

Sebelum dipisah, angka ini tidak mungkin nol karena `setState` ada di halaman
induk.

---

## Temuan 4: tidak ada isolasi repaint pada area yang sering berubah

**Lokasi:** `features/announcements/presentation/pages/home_page.dart`

**Kenapa ini masalah.** Kartu Debug FCM berubah paling sering di halaman ini,
tetapi berada dalam satu lapisan paint dengan sisa halaman. Saat kartu itu
berubah, Flutter harus me-repaint area yang lebih luas daripada yang perlu.

**Cara membuktikan.** Ini tidak bisa dibuktikan lewat test unit. Yang bisa
dilakukan: memasang `RepaintBoundary` dan mengukur dampaknya lewat flame chart
di DevTools. Karena itu temuan ini **tidak diklaim** menghasilkan penurunan
angka tertentu.

---

## Temuan yang diperiksa lalu DITOLAK

Bagian ini sama pentingnya dengan temuan yang diterima. Setiap usulan diperiksa
dulu, dan yang tidak menghasilkan dampak tidak dikerjakan.

### Ditolak 1: `select` pada `authStateProvider` di `login_page`

**Usulan.** `ref.watch(authStateProvider.select((s) => s.isLoading))` supaya
halaman hanya rebuild saat status sibuk berubah.

**Hasil pengukuran.** Tidak ada penghematan sama sekali.

`AuthNotifier.logout()` dan `login()` sama-sama memulai dengan
`state = const AsyncLoading()`, lalu diakhiri `AsyncData`. Jadi `isLoading`
**benar-benar berubah** false -> true -> false. Kedua rebuild itu diperlukan,
dan `select` tidak menghapus satu pun.

```
Expected: <2>
  Actual: <4>
```

Angka di atas dari percobaan pertama, yang mengira `select` akan menekan angka.
Ternyata jumlah rebuild dengan dan tanpa `select` **sama**. Test penjaga
sekarang mencatat kesamaan itu, supaya klaim "optimasi" tidak pernah ditulis
untuk perubahan ini.

**Keputusan.** Dibatalkan. `login_page.dart` kembali memakai
`ref.watch(authStateProvider).isLoading`, dengan komentar yang menjelaskan
kenapa.

### Ditolak 2: `ListView.builder` di dashboard

**Usulan.** Ganti `ListView(children: [...])` jadi `ListView.builder`.

**Alasan penolakan.** Halaman itu punya 5 item tetap yang semuanya dibangun
sekaligus dan tidak pernah berubah jumlahnya. `builder` hanya menghemat kalau
jumlah item banyak atau berubah. Menggantinya menambah `itemBuilder` dan
penomoran index tanpa dampak terukur.

### Ditolak 3: pagination infinite scroll

**Alasan penolakan.** Seed hanya 3 pengumuman. Tidak ada data untuk dipaginasi,
dan tidak ada endpoint yang mengembalikan halaman. Menulis pagination sekarang
berarti menulis kode yang tidak bisa diuji dengan data nyata.

### Ditolak 4: `CachedNetworkImage`

**Alasan penolakan.** Aplikasi tidak menampilkan satu pun gambar jaringan.
Pencarian di `lib/` untuk `Image.network` dan `CachedNetworkImage` nol hasil.

### Ditolak 5: repository cache stale-while-revalidate

**Alasan penolakan.** Tidak ada backend sungguhan. `MockAnnouncementRepository`
membaca seed lokal, jadi "cache" dan "sumber" adalah hal yang sama. Menerapkannya
sekarang berarti menulis dua lapisan yang tidak bisa dibedakan hasilnya.

### Ditolak 6: `RepaintBoundary` di semua kartu

**Alasan penolakan.** Setiap boundary punya biaya memori untuk lapisan tambahan.
Memasangnya di semua tempat bisa lebih lambat, bukan lebih cepat. Hanya dipasang
di kartu FCM, area yang terbukti paling sering berubah.

---

## Ringkasan

| # | Temuan | Bukti | Keputusan |
|---|---|---|---|
| 1 | `fetchAll` diulang tiap ketikan | 6 pemanggilan jadi 1 | Diterima |
| 2 | Tidak ada debounce | Test ketikan beruntun | Diterima |
| 3 | Satu `setState` untuk seluruh halaman | Penghitung build | Diterima |
| 4 | Tidak ada isolasi repaint | Flame chart, tidak diukur di sini | Diterima sebagian |
| 5 | `select` pada `authStateProvider` | Rebuild sama, tidak berkurang | **Ditolak** |
| 6 | `ListView.builder` di dashboard | 5 item tetap | **Ditolak** |
| 7 | Pagination | 3 data, tidak ada endpoint | **Ditolak** |
| 8 | `CachedNetworkImage` | Nol gambar jaringan | **Ditolak** |
| 9 | Repository cache | Tidak ada backend | **Ditolak** |
| 10 | `RepaintBoundary` di semua kartu | Biaya memori | **Ditolak** |
