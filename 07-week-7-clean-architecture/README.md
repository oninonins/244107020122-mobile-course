# Week 7 — Clean Architecture

Refactor `campus_notify` (Week 6) menjadi struktur **feature-first** dengan tiga
layer terpisah: `presentation → domain ← data`.

## Tujuan

- Menjelaskan prinsip SOLID dan separation of concerns pada kode Flutter nyata.
- Membedakan struktur feature-first vs layer-first beserta trade-off-nya.
- Menegakkan aturan dependensi: dependensi hanya mengarah ke dalam.
- Membedakan entity vs model, serta peran repository, use case, dan DI.
- Menguji use case dengan repository palsu tanpa database atau jaringan.

## Praktikum 1 — Petakan File ke Layer

Baseline diambil sebelum refactor. Tabel ini adalah kondisi "sebelum";
kolom **Layer target** diisi pada Praktikum 3.

### Layer saat ini

| File | Layer saat ini | Masalah |
|---|---|---|
| `lib/main.dart` | presentation | Import langsung `messaging/push_service.dart:8` (Firebase). `registerDevice(ref.read(apiClientProvider))` di `:137` mengirim Dio dari presentation ke data layer. Composition root bercampur dengan logika messaging. |
| `lib/routes.dart` | presentation | **OK.** Hanya konstanta rute + `routeFromMessage()` yang murni dan bebas Firebase. |
| `lib/pages/login_page.dart` | presentation | Import `../data/auth_repository.dart:4` hanya untuk `AuthFailure`. `:39` `error is AuthFailure` membuat presentation memeriksa tipe milik data layer. |
| `lib/pages/home_page.dart` | presentation | Import `data/auth_repository.dart:7` dan `messaging/push_service.dart:8`. `:117` mengirim Dio (`apiClientProvider`) ke `registerDevice()`. `_formatTime()` `:53-57` dan `_emailFromRefresh()` `:103-106` adalah logika format/parsing di dalam widget. |
| `lib/pages/announcement_page.dart` | presentation | **OK.** Stateless, hanya bergantung pada `routes.dart`. |
| `lib/providers/auth_provider.dart` | presentation | DI bocor: `SecureTokenStore()` `:12`, `MockAuthRepository()` `:17`, `buildApiClient()` `:24`. Import `package:dio` `:3`. `registerDevice(dio)` `:62`. Kontrak, implementasi, dan wiring menyatu dalam satu file. |
| `lib/data/auth_repository.dart` | data (kontrak tercampur) | Satu file berisi entity `AuthSession`, `AuthFailure`, kontrak `AuthRepository`, implementasi `MockAuthRepository`, dan util `maskToken`. Interface tidak tinggal di `domain`; domain dan data tercampur. |
| `lib/data/token_store.dart` | data (kontrak tercampur) | `TokenStore` interface dan `SecureTokenStore` berada di file yang sama. |
| `lib/data/api_client.dart` | data | **OK.** Murni Dio + interceptor, responsibilities-nya benar. Masalahnya bukan di file ini, melainkan di pemanggilnya yang berada di presentation. |
| `lib/data/api_errors.dart` | data | **OK.** Pemetaan error ke pesan ramah pengguna sudah berada di tempat yang benar. |
| `lib/messaging/push_service.dart` | data (infrastruktur) | Monolitik 280 baris: Firebase, local notification, cache token, dan HTTP `POST /devices` dalam satu file. Tidak punya lapisan domain, dan `registerDevice(Dio)` dipanggil dari presentation. |

### Ringkasan

| Kategori | Jumlah | File |
|---|---|---|
| Perlu dipindah dan/atau dipecah | 6 | `main.dart`, `login_page.dart`, `home_page.dart`, `auth_provider.dart`, `auth_repository.dart`, `token_store.dart` |
| Perlu dipecah tanpa pindah layer | 1 | `push_service.dart` |
| Sudah sesuai | 4 | `routes.dart`, `announcement_page.dart`, `api_client.dart`, `api_errors.dart` |

### Layer target

| File lama | File baru |
|---|---|
| `lib/data/auth_repository.dart` (bagian entity) | `features/auth/domain/entities/auth_session.dart` |
| `lib/data/auth_repository.dart` (bagian kontrak) | `features/auth/domain/repositories/auth_repository.dart` |
| `lib/data/auth_repository.dart` (bagian impl) | `features/auth/data/repositories/mock_auth_repository.dart` |
| `lib/data/auth_repository.dart` (`maskToken`) | `core/format.dart` |
| `lib/data/auth_repository.dart` (`AuthFailure`) | `core/failures.dart` |
| `lib/data/token_store.dart` (interface) | `features/auth/domain/repositories/token_store.dart` |
| `lib/data/token_store.dart` (`SecureTokenStore`) | `features/auth/data/datasources/secure_token_store.dart` |
| `lib/data/api_client.dart` | `features/notifications/data/api_client.dart` |
| `lib/messaging/push_service.dart` (FCM, token, topic) | `features/notifications/data/firebase_push_repository.dart` |
| `lib/messaging/push_service.dart` (`POST /devices`) | `features/notifications/data/dio_device_registrar.dart` |
| `lib/providers/auth_provider.dart` | `features/auth/presentation/providers/auth_providers.dart` |
| `lib/pages/login_page.dart` | `features/auth/presentation/pages/login_page.dart` |
| `lib/pages/home_page.dart` | `features/announcements/presentation/pages/home_page.dart` |
| `lib/pages/announcement_page.dart` | `features/announcements/presentation/pages/announcement_page.dart` |
| `lib/main.dart` | tetap di `lib/main.dart` (composition root) |
| `lib/routes.dart` | tetap di `lib/routes.dart` |
| `lib/data/api_errors.dart` | tetap di `features/notifications/data/api_errors.dart` |

## Praktikum 2 — Tiga Pelanggaran Klasik

Ditemukan dengan pencarian di `lib/pages`, `lib/providers`, dan `lib/main.dart`.

### 1. Presentation menyentuh jaringan dan penyimpanan langsung

```
providers/auth_provider.dart:12: final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
```

Menyimpan token lewat plugin `flutter_secure_storage` di dalam presentation.

### 2. Instansiasi manual — DI bocor

```
providers/auth_provider.dart:12: final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
providers/auth_provider.dart:17: (ref) => MockAuthRepository(),
providers/auth_provider.dart:24: return buildApiClient(
```

Provider di presentation meng-*instantiate* `SecureTokenStore`, `MockAuthRepository`,
dan `Dio`. Widget dan notifier sebaiknya hanya membaca provider, bukan tahu
bagaimana implementasinya dibuat.

### 3. Logika format dan parsing di dalam widget

```
pages/home_page.dart:55:  String two(int n) => n.toString().padLeft(2, '0');
pages/home_page.dart:105: return refresh.substring('refresh:'.length).split('|').first;
```

`_formatTime()` dan `_emailFromRefresh()` adalah fungsi murni yang layak dipindah ke
`core/format.dart` supaya bisa diuji tanpa widget.

### 4. Tipe milik data layer bocor ke presentation

```
pages/login_page.dart:39:           error is AuthFailure ? error.message : '...',
pages/home_page.dart:117:            await registerDevice(
pages/home_page.dart:118:              ref.read(apiClientProvider),
main.dart:137:          await registerDevice(ref.read(apiClientProvider));
```

Tiga tempat ini harus hilang setelah refactor: presentation tidak boleh
menyebut `AuthFailure`, `Dio`, atau `apiClientProvider`.

## Arah Dependensi

### Sebelum

```
presentation (pages, providers, main)
   |  import ../data/... , import messaging/push_service.dart
   v
data (auth_repository, token_store, api_client, push_service)
```

Aturan yang dilanggar: interface dan implementasi tercampur, dan presentation
bergantung langsung pada infrastruktur.

### Target

```
presentation (widget, notifier, router)
      |
      v  bergantung ke
domain (entity, repository interface, use case, Failure)
      ^
      |  diimplementasikan oleh
data (model, repository impl, Dio, Firebase, secure storage)
```

## Catatan tentang `rg`

Codelab memverifikasi dengan ripgrep, yang belum terpasang di mesin ini. Semua
pemetaan di atas memakai `Select-String` PowerShell dengan pola yang sama.
Perintah verifikasi pada Praktikum 3 ditulis dalam dua bentuk: `rg` (sesuai
codelab) dan `Select-String` (ekuivalen di PowerShell).

## Struktur Folder

```
07-week-7-clean-architecture/
├── campus_notify/          # aplikasi Flutter (hasil refactor)
├── docs/                   # catatan AI challenge, peta refactor, hasil verifikasi
├── screenshots/            # bukti before/after
└── README.md
```