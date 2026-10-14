# AI Prompt Challenge

Dokumen ini berisi prompt yang diberikan, usulan AI, dan hasil verifikasinya.
Wajib ada di folder `docs/` menurut codelab: *"simpan prompt, output awal AI,
tabel usulan-vs-keputusan-final, dan hasil tiga grep verifikasi pada folder
`docs/`"*.

---

## 1. Prompt yang diberikan

```text
Project Flutter saya: campus_notify (auth + FCM + daftar pengumuman).
Kondisi kini: folder lib/{data, providers, pages, messaging},
repository tercampur dengan implementasi, widget memanggil Dio langsung.
Tugas:
1. Usulkan struktur feature-first Clean Architecture
   (presentation/domain/data) untuk fitur auth + announcements.
2. Untuk tiap file lama, sebutkan tujuan barunya (pindah/pecah/hapus).
3. Tandai bagian yang over-engineering bila diterapkan ke CRUD sederhana,
   dan kapan use case benar-benar dibutuhkan vs repository langsung.
4. Tunjukkan wiring DI dengan Riverpod (tanpa package DI tambahan).
Jelaskan trade-off setiap keputusan.
```

Kondisi nyata saat proposal dibuat, terverifikasi dengan `rg` (lihat
`verification-grep.md`):

```
12 item refactor di 5 file
- presentation memegang Dio: 6 baris
- DI bocor di provider: 4 baris
- logika format di dalam widget: 2 fungsi
- tipe data bocor ke presentation: 4 tempat
- import lintas layer: 8 baris
```

---

## 2. Jawaban Tugas 1 — Struktur feature-first

```
lib/
├── main.dart                                  # composition root
├── routes.dart                                # konstanta rute saja
├── core/
│   ├── failures.dart                          # sealed Failure + 4 subtype, nol import
│   └── format.dart                            # 5 fungsi murni, nol import framework
└── features/
    ├── auth/{domain,data,presentation}
    ├── announcements/{domain,data,presentation}
    └── notifications/{domain,data,presentation}
```

Arah dependensi — satu arah, ke dalam:

```
presentation (widget, notifier, provider)
      |
      v  bergantung ke
domain (entity, repository interface, use case, Failure)
      ^
      |  diimplementasikan oleh
data (model, repository impl, Dio, Firebase, secure storage)
```

**Feature-first dipilih, bukan layer-first.** Alasannya: `campus_notify` punya
tiga fitur yang saling bebas, dan menghapus satu fitur berarti menghapus satu
folder tanpa menyentuh yang lain. Pada struktur layer-first, satu fitur baru
menyentuh tiga folder sekaligus.

---

## 3. Jawaban Tugas 2 — Peta file lama

Rinci perpecahan per baris ada di `refactor-map.md`. Ringkasnya:

| File lama | Aksi | Jadi apa |
|---|---|---|
| `data/auth_repository.dart` (89 b) | **pecah → 4** | entity · kontrak · impl mock · `maskToken` → `core/format.dart` |
| `data/token_store.dart` (67 b) | **pecah → 2** | kontrak `domain/` · impl `data/` |
| `data/api_client.dart` (72 b) | **pindah** | `features/auth/data/` |
| `data/api_errors.dart` (39 b) | **pindah** | `features/notifications/data/` |
| `messaging/push_service.dart` (280 b) | **pecah → 2** | `firebase_push_repository.dart` · `dio_device_registrar.dart` |
| `providers/auth_provider.dart` (71 b) | **pecah** | `features/auth/presentation/providers/auth_providers.dart` |
| `pages/login_page.dart` (152 b) | **pindah + modif** | `features/auth/presentation/pages/` |
| `pages/home_page.dart` (291 b) | **pindah + modif** | `features/announcements/presentation/pages/` |
| `pages/announcement_page.dart` (38 b) | **pindah** | `features/announcements/presentation/pages/` |
| `main.dart` (174 b) | **pertahankan, perkecil** | composition root |
| `routes.dart` (25 b) | **dipangkas** | konstanta rute saja |

Yang **dihapus** bukan hanya dipindah: `lib/pages`, `lib/providers`, `lib/data`,
dan `lib/messaging` seluruh foldernya dihapus. Kalau dibiarkan, grep sterilitas
presentation tidak akan pernah nol — dan folder yang tidak pernah diimpor siapa
apa juga adalah kode mati.

---

## 4. Jawaban Tugas 3 — Over-engineering

### Kriteria yang dipakai

> **Use case dibuat bila ada aturan bisnis, atau operasinya menggabungkan lebih
> dari satu sumber data.**

Kriteria ini dipakai konsisten untuk ketiga fitur. Yang tidak lolos dari
kriteria itu sengaja tidak dibuat.

### Dibuat (3, satu per fitur)

| Use case | Aturan bisnis yang dipegangnya |
|---|---|
| `Login` | "email harus berformat email" dan "kata sandi minimal 6 karakter" — sebelumnya tertulis di dalam `login_page.dart` |
| `GetAnnouncement` | Pintu masuk domain ke data pengumuman; dipanggil `AnnouncementPage` |
| `RegisterDevice` | "hanya kirim token kalau sesi sudah ada" — sebelumnya tersebar di `main.dart:135` dan `auth_provider.dart:62` |

### Ditolak, dengan alasan tertulis

| Operasinya | Alasan penolakan |
|---|---|
| `Logout` | Satu baris `tokenStore.clear()`. Tidak ada aturan apa pun. |
| `RestoreSession` | `readAccess() != null`. Tidak ada aturan apa pun. |
| `GetAnnouncements` | Tidak ada UI yang memakainya. Akan jadi dead code. |
| `fetchAll()` di kontrak | Kontrak_repository tidak boleh menebak kebutuhan masa depan. |
| `publishedAt` di `Announcement` | Tidak ada UI yang menampilkan tanggal. Generality spekulatif. |
| `RequestPermission` | Pembungkus satu panggilan; sudah mengembalikan record berisi `granted`. |
| `SetTopicSubscription` | Pembungkus satu panggilan; sudah mengembalikan record berisi `subscribed`. |
| Entity untuk `notifications` | Tidak ada data bisnis yang perlu digenggam — hanya token, topik, dan rute. Entity kosong akan jadi formalitas. |

**Pola yang muncul:**ima yang ditolak semuanya bertumpu pada "tidak ada yang
memakai" atau "tidak ada aturan". Yang Accepted semuanya punyaConsumer nyata dan
(atau) aturan yang bisa diuji.

### Deviasi dari contoh codelab

Contoh `FakeNoteRepository` di codelab menulis:

```dart
@override
Future<...> addNote(...) => throw UnimplementedError();
```

Itu persis gejala pelanggaran **Liskov Substitution** yang dicantumkan di bagian
SOLID halaman yang sama: *"Repository palsu untuk test malah melempar error
yang tak pernah dilempar repository asli."*

Di sini semua fake mengembalikan record kegagalan yang wajar. Konsekuensinya bisa
diuji: ada test `Liskov Substitution - fake benar-benar menggantikan repository
asli` yang memanggil **setiap** metode pada interface fake. Kalau ada satu yang
`throw UnimplementedError()`, test itu akan gagal.

---

## 5. Jawaban Tugas 4 — Wiring DI dengan Riverpod

Tanpa package DI tambahan. Hanya Riverpod yang sudah dipakai sejak Minggu 3.

### Titik wiring

Semua `new`Occurs di tiga file, semuanya bernama `*_providers.dart`:

```dart
// features/auth/presentation/providers/auth_providers.dart
final tokenStoreProvider      = Provider<TokenStore>((ref)      => SecureTokenStore());
final authRepositoryProvider  = Provider<AuthRepository>((ref)  => MockAuthRepository());
final loginProvider           = Provider<Login>((ref)          => Login(ref.watch(authRepositoryProvider)));
```

```dart
// features/notifications/presentation/providers/push_providers.dart
final _firebasePushProvider   = Provider<FirebasePushRepository>((ref) => FirebasePushRepository());
final pushTokenSourceProvider = Provider<PushTokenSource>((ref)    => ref.watch(_firebasePushProvider));
final topicSubscriptionProvider = Provider<TopicSubscription>((ref) => ref.watch(_firebasePushProvider));
final deviceRegistrarProvider = Provider<DeviceRegistrar>((ref) {
  return buildDeviceRegistrar(   // factory dari data/ - Dio dibuat di dalam
    store: ref.watch(tokenStoreProvider),
    auth: ref.watch(authRepositoryProvider),
    readToken: () => ref.read(_firebasePushProvider).currentToken,
    onSessionExpired: () => ref.read(authStateProvider.notifier).logout(),
  );
});
```

### Trik yang membuatnya bekerja

`presentation` **tidak pernah menyebut tipe `Dio`**. `buildApiClient()` membuat
`Dio` di dalam `data/`, dan yang dikembalikan ke presentation hanya kontrak
`DeviceRegistrar`. Karena itu grep

```
rg "Dio\(" lib/features/*/presentation
```

benar-benar nol — bukan nol karena grep-nya longgar, tapi karena tidak ada satu
pun `Dio(` di sana.

### Kenapa tidak `get_it`

Riverpod sudah memberi tiga hal yang justru dibutuhkan di sini:

1. **Testability** — `overrideWithValue` mengganti `SecureTokenStore()` dengan
   `InMemoryTokenStore()` tanpa satu baris kode produksi yang berubah.
2. **Siklus hidup** — `ref.onDispose` melepas router dan listener.
3. **Cache** — provider dibaca berkali-kali menghasilkan instance yang sama.

Menambah `get_it` berarti menambah satu konsep DI kedua tanpa kebutuhan baru.

---

## 6. AI Verification Checklist

Enam pertanyaan dari codelab, dijawab dengan bukti — bukan dengan membaca
sekilas. Output `rg` lengkap ada di `verification-grep.md`.

| # | Pertanyaan | Status | Bukti |
|---|---|---|---|
| 1 | Interface repository di `domain`, implementasi di `data`? | ✅ | 7 `abstract interface class` (di 4 file), semuanya di `domain/`. 6 kelas `implements`, semuanya di `data/`. Tidak ada satu pun interface di `data/` |
| 2 | `domain` bebas import Flutter/Dio/SQLite/Firebase? | ✅ | `rg "import 'package:flutter\|dio\|sqflite\|firebase" lib/features/*/domain lib/core` → **nol hasil** |
| 3 | AI membuat use case untuk tiap CRUD satu-baris? | ✅ **tidak** | Hanya 3 use case dari 11 operasi kandidat. 8 ditolak dengan alasan tertulis (bagian 4) |
| 4 | Entity bebas mapping? | ✅ | `rg "toMap\|fromMap\|toJson\|fromJson" lib/features/*/domain` → **nol hasil**. Mapping hanya di `auth_session_model.dart` dan `announcement_model.dart` |
| 5 | Wiring DI terpusat di provider, widget tidak `new Repository()`? | ✅ | `rg "Repository(\|SecureTokenStore(\|Dio\(" lib/features/*/presentation/pages` → **nol hasil**. Semua `new` ada di 3 file `providers/` |
| 6 | Keputusan final + alasan teknis? | ✅ | Bagian 4 dan 7. Tiga keputusan berbeda dari usulan awal |

### Dua temuan yang mengubah usulan

**Temuan 1 — FCM tidak bisa diletakkan di `lib/core/`.**
Usulan awal menaruh `push_service.dart` di `lib/core/messaging/` karena dipakai
lintas fitur. Tapi grep #2 codelab menyisir `lib/core` secara rekursif, dan file
itu mengimpor 4 package (`dio`, `firebase_messaging`, `flutter/foundation`,
`flutter_local_notifications`). Memindahkannya ke sana **otomatis membuat grep #2
tidak nol** — bertabrakan langsung dengan target "tiga grep nol".

Keputusan: FCM dijadikan fitur ketiga, `features/notifications/`. `lib/core/`
tetap murni Dart, sesuai makna `core` di codelab ("Failure domain (murni
Dart)").

**Temuan 2 — ada dua `AuthFailure` yang bertabrakan.**

```
lib/data/auth_repository.dart:11   class AuthFailure implements Exception
lib/core/failures.dart:32          class AuthFailure extends Failure
```

Nama sama, semantik berbeda. Selama `data/auth_repository.dart` masih ada, ini
bom waktu: begitu dua-duanya di-import, bentrok. Karena itu file lama dihapus
dalam commit yang sama, bukan ditunda.

---

## 7. Tabel usulan vs keputusan final

| # | Usulan awal AI | Keputusan final | Alasan perubahan |
|---|---|---|---|
| 1 | FCM di `lib/core/messaging/` | `features/notifications/` | Menjamin grep #2 nol. `core/` diperuntukkan bagi yang tidak punya pemilik fitur |
| 2 | `GetAnnouncements` ikut dibuat | **Ditolak** | Tidak ada UI yang memakainya |
| 3 | `fetchAll()` di kontrak repository | **Ditolak** | Kontrak tidak boleh menebak kebutuhan masa depan |
| 4 | `Logout` sebagai use case | **Ditolak** | Satu baris tanpa aturan bisnis |
| 5 | `publishedAt` di entity `Announcement` | **Ditolak** | Tidak ada UI yang menampilkan tanggal |
| 6 | Validasi email/sandi tetap di widget | **Pindah ke domain**, widget memanggil `Login.validateEmail()` | Kalau aturan hanya di widget, tidak bisa diuji tanpa widget. Kalau hanya di domain, pesan inline hilang dan UI berubah. Dipindah ke domain lalu **dipakai** widget menyelesaikan keduanya |
| 7 | Fake repository memakai `throw UnimplementedError()` | **Tidak** | Melanggar Liskov Substitution yang disebut di bagian SOLID codelab sendiri |
| 8 | `Login` mengembalikan `bool` | Mengembalikan `(session, failure)` | Notifier butuh token untuk disimpan; `bool` memaksa repository dipanggil dua kali |
| 9 | Router tetap di `main.dart` | Tetap di `routes.dart` | Struktur target codelab menyebut `routes.dart # GoRouter + konstanta rute` |

---

## 8. Trade-off yang diterima

**a. Ada satu tautan lintas fitur.**
`features/notifications/presentation/providers/push_providers.dart` mengimpor
`auth_providers.dart`. Alasannya nyata: `POST /devices` memakai header
`Authorization`, jadi mendaftarkan token perangkat memang butuh sesi milik auth.

Alternatif `lib/core/providers.dart` (untuk provider lintas fitur, yang memang
disediakan struktur target codelab) **ditolak**: `core/` untuk hal yang tidak
punya pemilik fitur, dan begitu sesi auth pindah tempat file itu ikut harus
diubah.

Untuk memutus siklus import, aturan "daftar ulang token setelah login" dipasang
di `main.dart` lewat `deviceRegistrationOnLoginProvider` — bukan di dalam
`AuthNotifier`. Kalau tidak, `auth` dan `notifications` saling mengimpor.

**b. Grep "DI bocor" masih menemukan 4 baris — dan itu memang seharusnya.**

```
push_providers.dart:32         return FirebasePushRepository();
announcement_providers.dart:12 return MockAnnouncementRepository();
auth_providers.dart:21          ... => SecureTokenStore()
auth_providers.dart:25          ... => MockAuthRepository()
```

Keempatnya ada di file `providers/`, yang oleh codelab ditunjuk sebagai
"notifier + DI" — satu-satunya tempat wiring. Yang terbukti nol adalah
instansiasi di folder `pages/`: tidak ada widget yang `new Repository()` sendiri.

**c. `Announcement.id` bertipe `String`.** Nilainya datang dari `data.route`
payload FCM yang selalu berupa teks. Mengubahnya ke `int` berarti menambah
konversi yang belum ada yang membutuhkannya.

**d. `formatDate` ditambahkan tapi belum dipakai.** Codelab menyebut "formatting
tanggal", padahal format yang benar-benar dipakai aplikasi adalah jam
(`HH:MM:SS`). Fungsi ini bisa dihapus tanpa efek apa pun, dan tidak
disembunyikan.