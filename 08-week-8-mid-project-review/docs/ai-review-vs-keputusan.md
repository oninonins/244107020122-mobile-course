# AI Review vs Keputusan

Dokumen wajib Minggu 8. Berisi temuan reviewer, bukti, dan keputusan final.
Codelab meminta minimal 2 temuan terbukti benar dengan bukti, dan minimal 1
temuan ditolak dengan alasan tertulis.

## Konteks

| | |
|---|---|
| PR | #2, `fix/session-debug-stale` ke `develop` |
| Issue | #1, kartu Debug token menampilkan sesi lama |
| Reviewer sejawat | Zuhdiaja (Approve, 2 temuan) |
| Reviewer AI | sesi pengembangan, temuan diverifikasi manual |
| Commit awal yang direview | `1dd709c` |

## Prompt yang diberikan

```
Review PR Flutter ini sebagai senior Flutter dev.
Konteks: feature-first Clean Architecture (presentation -> domain <- data),
Riverpod, GoRouter, SQLite + Dio.
Fokus: kebenaran, arsitektur, dan test. Abaikan style.
Berikan 5 temuan teratas + level (blocker/saran)
+ alasan + usulan potongan kode perbaikan.
```

## Ringkasan hasil

| # | Temuan | Sumber | Status | Bukti |
|---|---|---|---|---|
| 1 | Interceptor 401 menyimpan token hasil refresh tanpa memberi tahu pembaca lain | AI dan sejawat | Diterima, diperbaiki | Test `api_client_refresh_test.dart` |
| 2 | Test hanya menguji jalur `logout()`, bukan `login()` | Sejawat | Diterima, diperbaiki | Eksperimen hapus `invalidate` |
| 3 | `invalidate` di `logout()` seharusnya cukup karena `invalidateSelf()` sudah memicu rebuild | AI | **Ditolak** | Lihat bagian penolakan |
| 4 | `auth_providers.dart` dirapikan `dart format` sehingga diff memuat perubahan layout | AI | Diterima, dicatat | Diff 39 baris untuk perbaikan 4 baris |
| 5 | Komentar `invalidate` terlalu panjang | AI | **Ditolak** | Lihat bagian penolakan |

---

## Temuan 1: token hasil refresh tidak memberi tahu pembaca lain

**Klaim.** `lib/features/auth/data/api_client.dart` menyimpan sesi baru setelah
401, tetapi tidak memberi tahu `sessionDebugProvider`. Kartu Debug token tetap
menampilkan access token lama setelah token diperbarui diam-diam.

**Verifikasi.** Dicari semua tempat yang menulis ke secure storage:

```
$ rg -n "\.save\(" lib
lib\features\auth\presentation\providers\auth_providers.dart:70
lib\features\auth\data\api_client.dart:59
```

Dua penulis, tetapi hanya jalur login yang memanggil
`ref.invalidate(sessionDebugProvider)`. Jalur interceptor tidak. Klaim terbukti.

**Keputusan.** Diterima. Perbaikan: `buildApiClient()` menerima callback
`onSessionRenewed` yang dipanggil tepat setelah `store.save()` berhasil.
Wiring-nya di `push_providers.dart`, karena di situlah `buildDeviceRegistrar()`
dipanggil.

**Bukti setelah perbaikan.** `test/data/api_client_refresh_test.dart` memakai
`HttpClientAdapter` tiruan yang membalas 401 sekali lalu 200:

```
flutter test test/data/api_client_refresh_test.dart
00:00 +2: All tests passed!
```

Test memeriksa tiga hal: `adapter.calls == 2` (satu request awal, satu retry),
`auth.refreshCalls == 1`, dan `renewed == 1` (callback terpanggil).

---

## Temuan 2: test tidak menguji jalur `login()`

**Klaim reviewer.** Test pertama menulis ke store secara langsung, bukan lewat
`login()`. Jadi `ref.invalidate` di `AuthNotifier.login()` tidak teruji. Hapus
baris itu, test tetap hijau.

**Verifikasi.** Klaim diuji dengan eksperimen, bukan dibaca sekilas. Baris
`ref.invalidate(sessionDebugProvider)` di `login()` diganti komentar, lalu test
dijalankan:

```
flutter test test/presentation/session_debug_test.dart
00:00 +2: All tests passed!
```

Test **tetap lulus**. Klaim terbukti: test lama hanya menempuh jalur `logout()`,
karena `logout()` memanggil `invalidateSelf()` yang memicu rebuild.

**Keputusan.** Diterima. Test pertama diubah supaya login lewat
`AuthNotifier.login()`, lalu login lagi dengan akun berbeda tanpa logout.

**Bukti setelah perbaikan.** Eksperimen yang sama diulang pada test baru:

```
flutter test test/presentation/session_debug_test.dart
  Expected: 'lain@polinema.ac.id'
    Actual: 'mhs@polinema.ac.id'
  tanpa invalidate di login(), nilai cache sesi pertama bertahan
```

Sekarang test **gagal** ketika `invalidate` dihapus. Artinya jalur itu benar
terkunci. Setelah baris dikembalikan, seluruh test hijau.

Catatan teknis: asersi awal membandingkan `maskedAccess`, dan itu keliru karena
token mock berbagi prefix `mock-access.` sehingga hasil masking-nya identik.
Pembanding yang andal adalah `email`, yang berasal dari refresh token.

---

## Temuan 3 ditolak: `invalidate` di `logout()` dianggap berlebihan

**Klaim.** `logout()` sudah memanggil `ref.invalidateSelf()`, yang membangun
ulang `authStateProvider`. Karena itu `ref.invalidate(sessionDebugProvider)`
dianggap tidak perlu.

**Alasan penolakan.** `sessionDebugProvider` tidak membaca `authStateProvider`.
Ia hanya membaca `tokenStoreProvider`, dan `tokenStoreProvider` adalah
`Provider<TokenStore>` biasa yang tidak pernah berubah nilainya. Membangun ulang
`authStateProvider` karena itu tidak menyentuh `sessionDebugProvider` sama
sekali.

Diuji dengan menghapus baris tersebut: `test/presentation/session_debug_test.dart`
gagal pada kasus logout, dengan `Actual: 'sesi-pertama...'` padahal yang
diharapkan `(kosong)`.

Kesimpulan: klaim ini salah, dan menghapus baris itu akan mengembalikan bug.
Baris dipertahankan.

---

## Temuan 4 diterima: diff memuat perubahan format

**Klaim.** `dart format` pada file yang disentuh ikut merapikan baris lain,
sehingga diff 39 baris untuk perbaikan yang sebenarnya 4 baris.

**Verifikasi.** `git diff --stat` menunjukkan 30 tambahan dan 9 penghapusan,
sementara baris logika yang berubah hanya `ref.invalidate` di dua tempat.

**Keputusan.** Diterima dan dicatat di deskripsi PR, tetapi tidak dikembalikan.
Alasannya: file itu memang belum pernah diformat, dan mengembalikan formatnya
berarti PR tetap tidak lolos `dart format --set-exit-if-changed`.

Perapian 28 file lain **tidak** dimasukkan ke PR ini. Saat dijalankan,
`dart format` menyentuh 30 file; 28 di antaranya dikembalikan dengan
`git checkout` supaya PR tetap di bawah 300 baris.

---

## Temuan 5 ditolak: komentar dianggap terlalu panjang

**Klaim.** Komentar penjelasan `invalidate` sepanjang 6 baris dianggap berlebihan
untuk kode 1 baris.

**Alasan penolakan.** Komentar itu menjelaskan **mengapa**, bukan **apa**.
Tanpa penjelasan tersebut, `ref.invalidate(sessionDebugProvider)` terlihat
seperti baris yang bisa dihapus tanpa akibat, dan temuan 3 membuktikan bahwa
kesimpulan itu memang mudah diambil. Komentar dipertahankan tanpa perubahan.

---

## Checklist verifikasi

| Butir | Status | Bukti |
|---|---|---|
| Temuan benar-benar ada, dibuktikan grep/test/reproduksi | Ya | Temuan 1 lewat `rg`, temuan 2 lewat eksperimen |
| Usulan tidak melanggar dependency rule | Ya | Perubahan hanya di `presentation` dan `data`; `domain` tidak disentuh |
| AI hanya nitpick style | Sebagian | Temuan 4 memang style, dan itu diakui serta dicatat |
| Minimal 2 temuan terbukti benar | Ya | Temuan 1 dan 2 |
| Minimal 1 temuan ditolak dengan alasan tertulis | Ya | Temuan 3 dan 5 |

## Verifikasi dependency rule setelah perubahan

```
rg "import 'package:flutter|import 'package:dio|import 'package:sqflite|import 'package:firebase" \
   lib/features/auth/domain lib/features/announcements/domain lib/features/notifications/domain lib/core
-> nol hasil

flutter analyze -> No issues found!
flutter test    -> All tests passed! (47 test)
```

## Kesimpulan

Dua temuan nyata masuk ke kode. Satu di antaranya (temuan 2) tidak akan
ditemukan tanpa review sejawat, karena reviewer AI sendiri sempat menganggap
test yang ada sudah memadai. Satu temuan ditolak karena salah secara teknis,
dan penolakan itu dibuktikan dengan test, bukan dengan argumen.