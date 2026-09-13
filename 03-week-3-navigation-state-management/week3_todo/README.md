# week3_todo

Aplikasi ToDo sederhana dengan state management **Riverpod** (v3) dan navigasi **GoRouter**. Berisi halaman ToDo (CRUD tugas), halaman Produk, dan halaman Statistik untuk praktikum `AsyncValue`.

## Fitur
- **ToDo** (`lib/pages/todo_page.dart` + `lib/providers/todo_provider.dart` + `lib/widgets/todo_tile.dart`)
  - Tambah tugas (FAB → dialog)
  - Tandai selesai (checkbox → coret teks) — hanya tugas belum selesai yang ditampilkan
  - Hapus tugas
  - `TodoTile` terpisah agar `build` pendek dan mudah diuji
  - `pendingTodosProvider` — provider turunan yang menyaring tugas dari `todoListProvider`
- **Navigasi** (`lib/main.dart` + `lib/pages/main_shell.dart`)
  - GoRouter: `/` daftar, `/stats` statistik
  - `NavigationBar` untuk berpindah; state ToDo bertahan karena `ProviderScope` membungkus root
- **Produk** (`lib/pages/product_page.dart` + `lib/providers/products_provider.dart`)
  - Simulasi state asinkron dengan `AsyncNotifier<List<String>>`:
    `loading` → `error` → `success`
- **Statistik** (`lib/pages/stats_page.dart` + `lib/providers/stats_provider.dart`)
  - `StatsNotifier extends AsyncNotifier<List<String>>`: delay 2 detik, 30%
    kemungkinan gagal; UI menangani `loading` (spinner), `error` (pesan +
    tombol retry), dan `success` (ListView 3 item).
  - Unit test notifier di `test/stats_provider_test.dart` (gunakan `overrideWith`
    dengan `failureRate`, `delay`, dan `Random` tiruan agar deterministik).

## Refactoring & Testing
- `flutter analyze` dan `flutter test` untuk verifikasi.
- Widget test di `test/widget_test.dart`: memastikan UI bereaksi terhadap
  perubahan state provider (menambah tugas baru).
- Unit test notifier di `test/stats_provider_test.dart`; container memakai
  `retry: (_, _) => null` agar build gagal langsung menjadi `AsyncError`
  (Riverpod default memakai auto-retry untuk `Exception`).
- Checklist verifikasi: navigasi GoRouter (pindah halaman & back), `ProviderScope`
  membungkus root sehingga state ToDo bertahan, UI AsyncValue menangani
  `loading`/`error`/`success`.

## Praktikum 3 — Uji ketiga state AsyncValue

### 1. Uji state `loading`
Kode `ProductPage` memakai `productsAsync.when(...)`. Saat pertama kali halaman dibuka,
`build()` menunggu `Future.delayed(2 detik)` sehingga UI menampilkan
`CircularProgressIndicator` selama 2 detik pertama.

### 2. Uji state `error`
Ubah `build()` di `lib/providers/products_provider.dart` menjadi:

```dart
@override
Future<List<String>> build() async {
  await Future.delayed(const Duration(seconds: 2));
  throw Exception('Gagal terhubung ke server');
}
```

Setelah reload, UI menampilkan teks **"Gagal memuat: Gagal terhubung ke server"**
beserta tombol **"Coba lagi"**. Exception apa pun yang dilempar di `build()`
otomatis ditangkap Riverpod menjadi `AsyncError` — tidak perlu try/catch manual.

### 3. Uji state `success` (retry via `ref.invalidate`)
Tombol **"Coba lagi"** memanggil:

```dart
onPressed: () => ref.invalidate(productsProvider)
```

`ref.invalidate(productsProvider)` menandai provider sebagai stale, sehingga
provider dijalankan ulang dari awal (muncul loading lagi, lalu sukses).
Pulihkan `build()` seperti semula dan pastikan daftar produk tampil:
`Keyboard`, `Mouse`, `Monitor`.

### 4. Refleksi: kapan stale data lebih baik daripada blank layar?
**Jawaban:** Menampilkan data lama (stale) dengan indikator refresh lebih baik
daripada mengosongkan layar ketika proses refresh **hanya memperbarui data
yang sudah ada** dan data lama masih relevan (belum kedaluwarsa). Layar kosong
justru menurunkan pengalaman pengguna karena pengguna kehilangan konteks.

Pola ini penting saat:
- **Refresh di latar belakang** — misalnya aplikasi berita/social feed, data lama
  tetap bisa dibaca pengguna sementara pembaruan berikutnya dimuat.
- **Data hampir real-time** — misalnya harga saham, cuaca, atau antrian; memutihkan
  layar tiap data berubah hanya akan membuat layar berkedip.
- **Tidak ada perubahan sebenarnya** — jika payload refresh sama dengan data lama,
  menghapus layar adalah pemborosan.
- **Error handling yang "tenang"** — saat refresh gagal, tampilkan data lama
  ditambah banner/snackbar "gagal menyegarkan" alih-alih menutup data yang
  sudah tampil. Di Riverpod, data lama bisa dipertahankan dengan
  `.copyWithPrevious()` atau `skipLoadingOnRefresh`.

Kapan lebih baik mengosongkan layar? Ketika data baru **sepenuhnya
menggantikan** konteks lama (misalnya berpindah akun/pengguna) sehingga data
lama tidak lagi valid dan menyesatkan.

## Kesalahan umum (catatan ujian)
1. **Memanggil `ref.watch` di dalam callback** — `ref.watch` harus dipanggil saat
   build/state dihitung, bukan di dalam event handler; gunakan `ref.read`.
   (`ref.watch` di callback menyebabkan "watch called outside build" / provider
   tidak berlangganan dengan benar.)
2. **Mengubah state langsung tanpa membuat objek baru** — `state.add(...)` atau
   `state[i] = ...` tidak memicu rebuild karena Riverpod mengandalkan kesetaraan
   objek; selalu buat koleksi/objek baru yang immutable (`[...state]`).
3. **Melupakan UI error** — jika cabang `error` tidak ditangani, aplikasi
   tampil layar putih/blank saat API gagal; selalu sediakan UI `error` + mekanisme
   retry.
4. **Menggunakan `setState` untuk state lintas halaman** — `setState` hanya untuk
   state lokal satu widget; untuk data yang dipakai banyak halaman gunakan
   provider (Riverpod/Bloc), karena `setState` akan hilang saat halaman ditutup.

Tugas refactor — checklist verifikasi mandiri:
- Navigasi GoRouter bekerja: pindah halaman, back, dan akses path detail langsung.
- `ProviderScope` membungkus root aplikasi; state ToDo bertahan saat berpindah halaman.
- UI AsyncValue menangani loading, error, dan success, bukan hanya success.
- `flutter analyze` tanpa issue dan semua test lulus.

Hasil: `flutter analyze` No issues found.


flutter test
00:08 +5: All tests passed!                                                                                 
