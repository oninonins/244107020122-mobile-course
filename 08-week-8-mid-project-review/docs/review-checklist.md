# Review Checklist

Dokumen kerja Minggu 8. Bagian pertama berisi audit riwayat (Praktikum 1).
Bagian berikutnya diisi saat PR, review sejawat, dan penilaian kesiapan
tengah semester.

Repo: `244107020122-mobile-course`
Remote: `https://github.com/oninonins/244107020122-mobile-course.git`

---

## Praktikum 1: Audit Riwayat

Dijalankan pada 14 Oktober 2026, commit terakhir `c5a2d8e`.

### Perintah dan hasil

```
$ git log --oneline -15
c5a2d8e perbaiki readme
1c18273 week 7: add docs folder and complete README deliverables
6ed19f8 week 7: refactor campus_notify into feature-first clean architecture
ea863e5 week 7: add before/after screenshots for praktikum 3
544e71e week 7: scaffold clean architecture structure and core layer
094e322 week 7: document praktikum 2 violations with rg output
6b2b46c week 7: map files to layers for praktikum 1
ffe1706 chore: snapshot before clean architecture
7a8258b week 6: add reflection section and verify deliverable checklist
b282453 week 6: refactor routes, wire token refresh, and add tests
025258d document week 6 AI challenge review
0c897c2 week 6: praktikum authentication, security, and FCM with screenshots
559e6ce refactor: offline-first notes app with GoRouter, tests, and documentation
fe32a76 praktikum & ai challenge
eed69ad refactor: add PostTile, post detail page with GoRouter, and centralize error handler
```

```
$ git branch -a
* main
```

```
$ git ls-remote --heads origin
c5a2d8e0c64c2de6d6a264efc0776ad740ff3604    refs/heads/main
```

```
$ git status
On branch main
Your branch is up to date with 'origin/main'.
nothing to commit, working tree clean
```

Total commit: 22.

### Temuan

| # | Temuan | Bukti | Tingkat |
|---|---|---|---|
| 1 | Tidak ada branch `develop` | `git branch -a` hanya `main`; remote juga hanya `main` | Blocker |
| 2 | Tidak ada branch `feature/*` atau `fix/*` | idem | Blocker |
| 3 | Semua 22 commit masuk langsung ke `main` | riwayat linear di `main`, tidak ada merge commit | Blocker |
| 4 | 19 dari 22 pesan commit tidak memakai format `tipe(scope): deskripsi` | lihat tabel di bawah | Blocker |
| 5 | Tidak ada CI | `.github/workflows/` tidak ada | Blocker |
| 6 | Folder `.github/modernize/java-upgrade/` membawa `.gitignore` berisi `**/*` | `git check-ignore -v` menunjuk aturan itu | Saran |
| 7 | Tidak ada issue maupun PR | `git log` tidak memuat merge dari PR; `Closes #` tidak pernah dipakai | Blocker |

Catatan temuan 6: aturan `**/*` hanya berlaku di dalam folder itu, jadi
`.github/workflows/ci.yml` tetap bisa dibuat dan dilacak. Tapi keberadaan folder
alat yang meng-ignore dirinya sendiri membuat `git status --ignored` berisik dan
membingungkan saat menilai apa yang benar-benar terlacak.

### Kualitas pesan commit

| Kategori | Jumlah |
|---|---|
| Konvensional | 3 |
| Tidak konvensional | 19 |
| **Total** | **22** |

Yang sudah benar:

```
chore: snapshot before clean architecture
refactor: offline-first notes app with GoRouter, tests, and documentation
refactor: add PostTile, post detail page with GoRouter, and centralize error handler
```

Yang bermasalah, contoh terburuk:

| Pesan sekarang | Masalah |
|---|---|
| `perbaiki readme` | Tidak ada tipe, tidak ada scope, tidak menjelaskan apa yang diperbaiki |
| `praktikum & ai challenge` | Dua pekerjaan dalam satu commit, tanpa tipe |
| `ai challenge` | Hanya dua kata, tidak bisa direview |
| `week 2` | Tidak menjelaskan apa pun |
| `week 3 and  AI Challenge` | Spasi ganda, tanpa tipe, dua hal sekaligus |
| `week 4, praktikum and screenshoot` | Salah ejaan, tanpa tipe, tiga hal sekaligus |
| `refactor and add documentation` | `refactor` bukan tipe konvensional di posisi itu, dan dua perubahan digabung |
| `document week 6 AI challenge review` | Harusnya `docs: ...` |
| `week 7: ...` (6 commit) | `week 7` bukan tipe yang diakui, sehingga filter per tipe tidak jalan |

### Yang sudah benar

- Working tree bersih, tidak ada file tak terlacak yang seharusnya di-commit.
- Artefak build sudah di-ignore dengan benar. `git status --ignored` menunjukkan
  `build/`, `.dart_tool/`, `.idea/`, `local.properties`, dan `google-services.json`
  semuanya masuk daftar ignore.
- Tiga commit sudah mengikuti format konvensional.
- Riwayat tidak pernah memuat file rahasia. `google-services.json` dan
  `local.properties` tidak pernah masuk index.

### Tindak lanjut

| Temuan | Rencana perbaikan | Praktikum |
|---|---|---|
| 1, 2, 3 | Buat `develop` dari `main` sekali, lalu semua kerja baru lewat `feature/*` bercabang dari `develop` | Praktikum 2 |
| 4 | Tulis ulang 3 pesan commit terburuk ke format konvensional sebagai tabel sebelum/sesudah, tanpa menulis ulang riwayat yang sudah ter-push | Praktikum 3 |
| 5 | Tambah `.github/workflows/ci.yml` yang menjalankan `flutter analyze` dan `flutter test` | Praktikum 6 |
| 7 | Buat issue, lalu PR dari `feature/*` ke `develop` dengan `Closes #<issue>` | Praktikum 4 |
| 6 | Biarkan, tapi dicatat. Folder itu milik alat, bukan kode aplikasi | Tidak ditindaklanjuti |

Catatan penting: temuan 4 sengaja **tidak** diperbaiki dengan `git rebase` atau
`git commit --amend` pada commit lama. Riwayat sudah ter-push ke `origin/main`, dan
menulis ulang history akan mengubah semua hash. Codelab meminta tabel
sebelum/sesudah sebagai simulasi, bukan rewrite.

---

## Praktikum 2: Branch Kerja

### Branch yang dibuat

```
main      865ad79   dilindungi, tidak disentuh langsung
develop   865ad79   default branch, target semua PR
```

Perintah yang dipakai, sekali saja:

```
git checkout -b develop
git push -u origin develop
gh repo edit --default-branch develop
```

Setelah itu setiap pekerjaan bercabang dari `develop`, bukan dari `main`:

| Branch | Tujuan | PR | Status |
|---|---|---|---|
| `chore/ci-pipeline` | CI | #4 | merged |
| `fix/session-debug-stale` | Perbaikan bug | #2 | merged |
| `docs/week-8-review` | Dokumen review | #3 | merged |

Ketiganya sudah dihapus setelah merge, lokal dan remote.

### Yang berubah dibanding audit

| Temuan audit | Sebelum | Sesudah |
|---|---|---|
| Tidak ada `develop` | hanya `main` | `develop` ada, jadi default branch |
| Tidak ada `feature/*` atau `fix/*` | tidak pernah dibuat | 3 branch kerja, semuanya via PR |
| Commit langsung ke `main` | 22 commit | 0 commit baru di `main` |

`main` masih di `865ad79`. Codelab menyebut `main` hanya berubah lewat release,
jadi itu memang keadaan yang benar untuk paruh semester.

---

## Praktikum 3: Perbaiki Pesan Commit

Tiga pesan terburuk ditulis ulang. **Riwayat tidak diubah**: `git log` tetap
menampilkan pesan lama, karena commit itu sudah ter-push dan menulis ulang hash
akan merusak riwayat bersama.

### Sebelum dan sesudah

| # | Commit | Pesan lama | Pesan baru | Alasan |
|---|---|---|---|---|
| 1 | `ff59979` | `week 2` | `feat(responsive): dashboard responsif dengan breakpoint dan layout adaptif` | `week 2` hanya menyebut minggu, bukan isi. Tidak ada tipe, tidak ada scope, dan tidak ada yang bisa direview dari judulnya. Isi commit sebenarnya: `responsive_dashboard` beserta README 345 baris dan screenshot. |
| 2 | `fe32a76` | `praktikum & ai challenge` | `feat(notes): offline-first notes dengan SQLite dan AI challenge` | Dua pekerjaan dalam satu commit, dan `praktikum` bukan tipe. Isinya project `week5_offline_notes` lengkap: SQLite, README 109 baris, screenshot. |
| 3 | `c5a2d8e` | `perbaiki readme` | `docs(readme): ganti tanda hubung panjang pada prosa dan heading` | `perbaiki` bukan tipe, tidak ada scope, dan tidak dijelaskan apa yang diperbaiki. Isinya 4 file dokumentasi, 100 tambahan dan 95 penghapusan, semuanya soal tanda baca. |

### Yang membedakan

Pesan lama hanya menjawab "kapan" atau "di folder mana". Pesan baru menjawab
tiga hal sekaligus:

1. **Apa** yang berubah (`dashboard responsif`, `offline-first notes`, `tanda
   hubung`)
2. **Di mana** (`responsive`, `notes`, `readme`)
3. **Kenapa** ada di body, bukan di judul

Perhatikan commit 1: judulnya `week 2`, padahal isinya 345 baris README plus satu
project Flutter utuh. Reviewer tidak punya cara menebak itu dari judul.

### Kesalahan yang sama, dua kali

`c5a2d8e` dan `0c897c2` sama-sama buatan sendiri pada minggu yang sama dengan
kesalahan serupa: menyebut aktivitas, bukan perubahan. Itu bukan kelalaian
sekali, melainkan kebiasaan. Karena itu aturan yang dipakai sekarang:

| Aturan | Contoh benar | Contoh salah |
|---|---|---|
| Selalu ada tipe | `fix(auth): ...` | `perbaiki readme` |
| Scope menyebut area kode | `feat(notes): ...` | `week 5` |
| Judul menjelaskan hasil, bukan aktivitas | `test(auth): uji alur login A, logout, login B` | `add test` |
| Satu commit satu perubahan logis | `ci: jalankan analyze dan test` | `praktikum & ai challenge` |

### Bukti aturan itu dipakai

Tiga commit terakhir di `develop` semuanya mengikuti aturan di atas:

```
573400d Merge pull request #2 from oninonins/fix/session-debug-stale
c6ed5a5 test(auth): rapatkan test dan kembalikan komentar yang tidak terkait
8c098c2 test(auth): uji alur login A, logout, login B pada kartu debug
```

Enam commit week 8 seluruhnya bertipe `docs`, `fix`, `test`, `ci`, atau `chore`,
dengan scope yang menyebut area kode.

