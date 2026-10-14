# Peta Refactor

Peta setiap file `campus_notify` **sebelum** refactor ke letaknya **sesudah**.

## Acuan

| | |
|---|---|
| Baseline (commit "sebelum") | `ffe1706` — `chore: snapshot before clean architecture` |
| Hasil refactor | `6ed19f8` — `week 7: refactor campus_notify into feature-first clean architecture` |

Cara membandingkan apa pun yang berubah:

```bash
git diff ffe1706 6ed19f8 --stat
git diff ffe1706 6ed19f8 -- lib/
git checkout ffe1706 -- lib/      # kalau perlu melihat kondisi lama
```

---

## Ringkasan

| Aksi | Jumlah |
|---|---|
| Dipisah jadi beberapa file | 2 |
| Dipindah (isi tetap) | 4 |
| Dipindah + dimodifikasi | 3 |
| Dipertahankan, diperkecil | 1 |
| Dipangkas | 1 |
| **Folder dihapus seluruhnya** | **4** |

`lib/` berubah dari **12 file datar** menjadi **28 file** di 3 fitur vertikal.
Empat folder lama (`data/`, `pages/`, `providers/`, `messaging/`) dihapus
seluruhnya, bukan dibiarkan kosong — folder yang tidak pernah diimpor siapa pun
adalah kode mati, dan keberadaannya membuat grep sterilitas tidak akan pernah nol.

---

## 1. `lib/data/auth_repository.dart` — dipecah menjadi 4

File lama (89 baris) berisi lima hal sekaligus: entity, error, kontrak,
implementasi, dan fungsi util.

| Baris lama | Isi |	File baru |
|---|---|---|
| `:3-8` | `class AuthSession` | `features/auth/domain/entities/auth_session.dart` |
| `:11-18` | `class AuthFailure implements Exception` | `core/failures.dart` (jadi `extends Failure`) |
| `:20-30` | `abstract interface class AuthRepository` | `features/auth/domain/repositories/auth_repository.dart` |
| `:33-81` | `class MockAuthRepository` | `features/auth/data/repositories/mock_auth_repository.dart` |
| `:85-89` | `String maskToken(...)` | `core/format.dart` |

**Perubahan lain di file hasil:**

- Kontrak `AuthRepository` sekarang mengembalikan record
  `(session, failure)` dan tidak pernah melempar. Week 6 melempar
  `AuthFailure`, yang bocor sampai `login_page.dart:39`.
- `MockAuthRepository` memanggil `AuthSessionModel.fromJson(...).toEntity()` di
  jalur produksi, supaya kelas model bukan kode mati.

## 2. `lib/data/token_store.dart` — dipecah menjadi 2

| Baris lama | Isi |	File baru |
|---|---|---|
| `:4-12` | `abstract interface class TokenStore` | `features/auth/domain/repositories/token_store.dart` |
| `:19-42` | `class SecureTokenStore` | `features/auth/data/datasources/secure_token_store.dart` |
| `:46-67` | `class InMemoryTokenStore` | idem, file yang sama |

## 3. `lib/messaging/push_service.dart` — dipecah menjadi 2

File lama (280 baris) monolitik: Firebase, local notification, cache token, dan
HTTP `POST /devices` dalam satu tempat.

| Isi | File baru |
|---|---|
| Firebase, cache token, topik, deep link, local notification | `features/notifications/data/firebase_push_repository.dart` |
| `POST /devices` (`:196-215`) | `features/notifications/data/dio_device_registrar.dart` |
| Kontrak (`implements` baru) | `features/notifications/domain/repositories/push_repositories.dart` |

Kontrak dipecah menjadi **empat interface** — `PushTokenSource`,
`TopicSubscription`, `DeepLinkSource`, `DeviceRegistrar` — supaya menguji
`RegisterDevice` tidak berarti membuat fake Firebase beserta seluruh
permintaannya.

## 4. `lib/data/api_client.dart` — pindah

| File lama | File baru |
|---|---|
| `data/api_client.dart` (72 b) | `features/auth/data/api_client.dart` |

Tetap satu file utuh. Yang berubah hanya letaknya: interceptor refresh token
adalah urusan sesi, jadi ia milik fitur auth.

## 5. `lib/data/api_errors.dart` — pindah

| File lama | File baru |
|---|---|
| `data/api_errors.dart` (39 b) | `features/notifications/data/api_errors.dart` |

Fungsi `readableApiError` diganti `readableApiFailure` yang mengembalikan
`Failure?`. Versi teksnya dipertahankan untuk pemakaian non-UI.

## 6. `lib/providers/auth_provider.dart` — dipecah

File lama (71 baris) adalah presentation yang juga menjadi tempat seluruh wiring
DI, lengkap dengan `new SecureTokenStore()`, `new MockAuthRepository()`, dan
`new Dio`.

| Baris lama | Isi |	File baru |
|---|---|---|
| `:12` | `tokenStoreProvider` | `features/auth/presentation/providers/auth_providers.dart` |
| `:16-18` | `authRepositoryProvider` | idem |
| `:23-29` | `apiClientProvider` | dihapus — `Dio` dibuat di `data/`, tidak lagi diekspos ke presentation |
| `:31-71` | `AuthNotifier` | idem, tapi `login()` mengembalikan `(session, failure)` |

## 7. `lib/pages/login_page.dart` — pindah + dimodifikasi

| Perubahan | Baris lama | Kenapa |
|---|---|---|
| `error is AuthFailure ? error.message : ...` | `:39` | **Hilang.** Ganti `result.failure?.message` |
| `import '../data/auth_repository.dart'` | `:4` | **Hilang.** Halaman tidak lagi tahu `AuthFailure` pernah ada |
| Validasi format email + min 6 karakter | `:84-119` | **Pindah ke domain.** Validator field sekarang memanggil `Login.validateEmail()` dan `Login.validatePassword()` |

Poin terakhir penting: aturan bisnis pindah ke `Login` **tetapi** pesan
validasinya tetap muncul di bawah field seperti semula, karena widget memanggil
aturan yang sama. Kalau aturan hanya di widget, tidak bisa diuji tanpa widget;
kalau hanya di domain, pesan inline hilang dan UI berubah.

## 8. `lib/pages/home_page.dart` — pindah + dimodifikasi

Dari 291 baris menjadi 253, dan turun drastis di sisi kebocoran.

| Perubahan | Baris lama |
|---|---|
| `_formatTime()` | `:53-57` → `core/format.dart` sebagai `formatClock()` |
| `_emailFromRefresh()` | `:103-106` → `core/format.dart` |
| `ref.read(tokenStoreProvider).readAccess()` | `:60-61` → `sessionDebugProvider` |
| `registerDevice(ref.read(apiClientProvider))` | `:115-122` → `registerDeviceProvider` (use case) |
| `maskedToken()`, `tokenStream`, `subscribeCampusTopic()`, `requestNotificationPermission()`, `simulateNotification()` | `:41,74,87,109,217` → kontrak `PushTokenSource` |

Tidak ada lagi `Dio`, `FirebaseMessaging`, atau plugin penyimpanan di file ini.

## 9. `lib/pages/announcement_page.dart` — pindah + dimodifikasi

Teks `'Jadwal kuliah berubah'` dan `'Kelas Mobile pindah ke Ruang A2 jam 13.00'`
yang tadinya hardcoded di `:24,26` dipindahkan ke
`MockAnnouncementRepository.defaultSeed`. **Isi teksnya sengaja dibuat identik**
— pemindahan ini tidak boleh mengubah apa pun yang dilihat pengguna.

## 10. `lib/main.dart` — dipertahankan, diperkecil

| Yang hilang | Baris lama |
|---|---|
| `import 'messaging/push_service.dart'` untuk logika | `:8` → hanya `registerBackgroundHandler()` yang tetap, karena harus dipanggil sebelum `runApp` |
| `registerDevice(ref.read(apiClientProvider))` | `:134-138` → `deviceRegistrationOnLoginProvider` |
| `_registerDevice` | `:134` |

Yang ditambahkan: `ref.watch(deviceRegistrationOnLoginProvider)` di `build()` —
ruang lingkup lintas fitur antar fitur dipegang composition root, bukan salah satu
fitur.

## 11. `lib/routes.dart` — dipangkas

| Yang dipindah | Ke mana |
|---|---|
| `routeFromMessage()` | `core/format.dart`, sesuai Refactoring Challenge |

Tinggal `abstract final class Routes` dengan konstantanya.

---

## Verifikasi hasil

```
# Kontrak hanya di domain
rg -n "^abstract interface class" lib/features
-> 7 kontrak, 4 file, semua di domain/

# Implementasi hanya di data
rg -n "implements (AuthRepository|TokenStore|AnnouncementRepository|DeviceRegistrar|PushTokenSource)" lib/features
-> 6 kelas, semua di data/

# Entity bebas mapping
rg -n "toMap|fromMap|toJson|fromJson" lib/features/*/domain
-> nol hasil

# Halaman tidak menginstansiasi repository
rg -n "Repository\(|SecureTokenStore\(|Dio\(" lib/features/*/presentation/pages
-> nol hasil
```

Output lengkap ada di `verification-grep.md`.