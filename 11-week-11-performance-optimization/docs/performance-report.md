# Performance Report

Laporan optimasi `campus_notify` Week 11. Angka yang ada di sini berasal dari
dua sumber, dan keduanya disebutkan supaya jelas mana yang terukur dan mana yang
belum.

| Sumber | Status |
|---|---|
| Test dengan penghitung (jumlah pemanggilan, jumlah build) | **Terukur, sudah dijalankan** |
| Flame chart DevTools (frame time, jank count, memori) | **Belum diisi**, menunggu profiling di perangkat |

Tidak ada angka flame chart yang dikarang di dokumen ini.

---

## Baseline

| Metrik | Baseline (Week 9) | Setelah (Week 11) |
|---|---|---|
| Pemanggilan `fetchAll` saat mengetik 5 huruf | **6** | **1** |
| Rebuild `_SessionCards` saat token FCM berubah | seluruh halaman | **0** |
| `build()` HomePage | 161 baris, satu widget | 39 baris |
| Kelas widget di `home_page.dart` | 2 | 5 |
| Total baris `home_page.dart` | 316 | 352 |
| Jumlah test | 71 | 80 |
| Frame time (DevTools) | belum diukur | belum diukur |
| Jank count (DevTools) | belum diukur | belum diukur |
| Heap usage (DevTools) | belum diukur | belum diukur |

---

## Optimasi yang diterapkan

### 1. Cache daftar, filter di memori

**Sebelum.** `searchResultsProvider` memanggil use case, use case memanggil
`fetchAll()` setiap kali. Setiap ketikan berarti satu pengambilan penuh.

**Sesudah.** Dua provider dipisah:

```dart
// diambil sekali, disimpan selama provider hidup
final allAnnouncementsProvider = FutureProvider<...>((ref) {
  return ref.watch(searchAnnouncementsProvider).fetchAll();
});

// hanya memfilter, tidak fetch
final searchResultsProvider = FutureProvider<...>((ref) async {
  final query = ref.watch(debouncedQueryProvider);
  final all = await ref.watch(allAnnouncementsProvider.future);
  return (
    announcements: SearchAnnouncements.filter(all.announcements, query),
    failure: all.failure,
  );
});
```

**Alasan memilih ini.** Ini satu-satunya temuan dengan dampak yang bisa dihitung
persis: 6 pemanggilan menjadi 1. Selain menghilangkan 5 kali `Future.delayed`
150 ms, ini juga menghilangkan 5 kali parsing JSON untuk seluruh seed.

**Bukti.**

```
# dengan kode lama (use case dipanggil tiap query berubah)
Expected: <1>
  Actual: <6>

# dengan kode sekarang
00:00 +6: All tests passed!
```

### 2. Debounce 300 ms

**Sebelum.** `onChanged` langsung mengubah kata kunci yang dipakai menyaring.

**Sesudah.** Dua kata kunci dengan peran berbeda:

| Provider | Dipakai untuk | Perilaku |
|---|---|---|
| `searchQueryProvider` | Isi kolom teks, tombol hapus | Berubah seketika |
| `debouncedQueryProvider` | Pemicu penyaringan, pesan empty state | Menunggu 300 ms |

Durasi jeda jadi provider sendiri (`debounceDurationProvider`), sehingga test
menggantinya dengan 10 ms dan tidak memperlambat suite.

Satu pengecualian yang disengaja: kata kunci kosong diteruskan **seketika**,
tanpa menunggu jeda. Alasannya, tombol hapus harus terasa langsung.

**Alasan memilih 300 ms.** Di bawah 200 ms, ketikan cepat masih lolos menjadi
beberapa penyaringan. Di atas 500 ms, terasa lambat. 300 ms adalah nilai umum
untuk kolom pencarian dan cukup untuk menahan ketikan beruntun.

**Bukti.** Test `ketikan beruntun hanya menyaring sekali`: lima huruf diketik
tanpa jeda, dan `debouncedQueryProvider` masih kosong sebelum jeda selesai,
lalu hanya berisi nilai terakhir setelahnya.

### 3. Memisahkan state FCM dari halaman

**Sebelum.** Satu `ConsumerStatefulWidget` 316 baris, dengan `build()` sendiri
161 baris. Satu `setState` di level halaman untuk token, izin, device, dan topik.

**Sesudah.** `HomePage` jadi `ConsumerWidget` tanpa state. Lima widget terpisah:

| Widget | State | Frekuensi berubah |
|---|---|---|
| `_SessionCards` | dari provider | Saat sesi berubah |
| `_FcmDebugCard` | `setState` sendiri | Setiap token/izin/device/topik |
| `_MenuCard` (2 buah) | tidak ada | Tidak pernah |
| `_TokenRow` | tidak ada | Mengikuti induk |

**Alasan memilih ini.** Kartu FCM berubah paling sering, kartu menu tidak pernah.
Menyatukan keduanya dalam satu `setState` berarti pekerjaan sia-sia pada setiap
perubahan token.

**Bukti.** Test dengan penghitung build:

```dart
sessionCardsBuildCount = 0;
push.emitToken('token-baru-dari-refresh');
await tester.pumpAndSettle();
expect(sessionCardsBuildCount, 0);
```

Nol rebuild pada kartu sesi saat token berubah, dan test kedua memastikan angka
itu bukan karena tidak ada yang berubah: saat sesi berubah, penghitungnya naik.

### 4. `RepaintBoundary` pada kartu FCM

**Sesudah.** Kartu FCM dibungkus `RepaintBoundary`, sehingga perubahannya tidak
memaksa repaint area lain.

**Dampak.** **Tidak diukur.** Ini satu-satunya optimasi yang tidak punya angka
pendukung. Alasannya, efeknya hanya terlihat di flame chart, dan profiling belum
dijalankan. Kalau setelah profiling ternyata tidak ada bedanya, boundary ini
layak dicopot karena menyimpan lapisan tambahan.

---

## Optimasi yang ditolak

Enam usulan diperiksa dan tidak dikerjakan. Rinciannya di
`performance-findings.md` bagian "Temuan yang diperiksa lalu DITOLAK". Ringkasnya:

| Usulan | Alasan |
|---|---|
| `select` pada `authStateProvider` | Diukur: rebuild sama, tidak berkurang |
| `ListView.builder` di dashboard | 5 item tetap, tidak ada yang dihemat |
| Pagination | 3 data, tidak ada endpoint |
| `CachedNetworkImage` | Tidak ada gambar jaringan |
| Repository cache | Tidak ada backend sungguhan |
| `RepaintBoundary` di semua kartu | Biaya memori, hanya dipasang di area yang terbukti |

Yang paling penting di tabel ini adalah baris pertama. `select` terdengar seperti
optimasi yang benar, dan hampir kutulis sebagai keberhasilan. Setelah diukur,
angkanya sama persis, karena `isLoading` memang berubah pada setiap transisi.
Test penjaga sekarang mencatat kesamaan itu, supaya perubahan ini tidak pernah
diklaim sebagai optimasi.

---

## Verifikasi

```
flutter analyze -> No issues found!
flutter test    -> All tests passed! (80 test)
dart format     -> Formatted 43 files (0 changed)
```

Tiga grep sterilitas tetap nol:

```
rg "Dio\(|openDatabase|...|jsonDecode" lib/features/*/presentation   -> nol
rg "import 'package:flutter|...|package:firebase" lib/features/*/domain lib/core -> nol
rg "toMap|fromMap|toJson|fromJson" lib/features/*/domain             -> nol
```

### Test performa

| Berkas | Jumlah | Isi |
|---|---|---|
| `test/performance/fetch_cache_test.dart` | 6 | Hitung `fetchAll`, debounce, kegagalan lewat cache |
| `test/performance/rebuild_count_test.dart` | 3 | Hitung rebuild kartu sesi, plus catat bahwa `select` tidak menghemat |

Sembilan test ini bukan test perilaku biasa. Fungsinya mengukur, dan angka di
dalamnya adalah bukti optimasi.

---

## Yang belum diukur

| Metrik | Kenapa belum | Cara mengisi |
|---|---|---|
| Frame time sebelum/sesudah | Butuh `flutter run --profile` di perangkat | Screenshot tab Performance, `screenshots/before-profile.png` dan `after-profile.png` |
| Jank count | idem | idem |
| Heap usage | Butuh tab Memory | Heap snapshot sebelum dan sesudah navigasi 5 kali |
| Dampak `RepaintBoundary` | Hanya terlihat di flame chart | Bandingkan raster thread |

Baseline profiling diambil dari Week 9 di `main`, karena salinan Week 11 dibuat
dari sana dan kode aslinya masih utuh. Yang perlu dilakukan:

```bash
# baseline
cd 09-week-9-ai-assisted-development/campus_notify
flutter run --profile

# sesudah
cd 11-week-11-performance-optimization/campus_notify
flutter run --profile
```

Skenario yang sama untuk keduanya: buka Daftar Pengumuman, ketik `jadwal`,
hapus, kembali ke dashboard, tekan Simulasikan notifikasi.

---

## Kesimpulan

Dari empat optimasi yang diterapkan, tiga punya bukti angka dan satu tidak.
Yang paling besar dampaknya adalah **cache daftar**, karena ia menghapus
pekerjaan yang paling mahal: pengambilan data dan parsing, bukan sekadar
rebuild widget.

Dari enam optimasi yang ditolak, yang paling berguna adalah penolakan `select`.
Tanpa pengukuran, perubahan itu akan terlihat seperti perbaikan, ditulis di
laporan sebagai keberhasilan, dan tidak mengubah apa pun.
