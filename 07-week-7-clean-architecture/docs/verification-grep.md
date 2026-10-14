# Hasil Verifikasi Grep

Output **asli** dari perintah yang dijalankan, bukan rekonstruksi. Kalau ada
perintah yang hasilnya tidak nol, hasilnya ditulis apa adanya.

## Lingkungan

```
$ rg --version
ripgrep 15.2.0 (rev e89fff89ac)

features:+pcre2
simd(compile):+SSE2,-SSSE3,-AVX2
simd(runtime):+SSE2,+SSSE3,+AVX2

PCRE2 10.45 is available (JIT is available)

$ flutter --version
Flutter 3.47.5 • channel stable
Dart 3.13.4
```

Semua perintah dijalankan dari `campus_notify/`.

---

## Tiga grep wajib codelab

### Grep 1: Presentation steril dari data mentah

```powershell
rg "Dio\(|openDatabase|getDatabasesPath|FlutterSecureStorage|SharedPreferences\.getInstance|jsonDecode" `
   lib/features/auth/presentation lib/features/announcements/presentation lib/features/notifications/presentation
```

**Hasil: nol. `exit=1`** (ripgrep keluar dengan 1 saat tidak menemukan apa pun)

Path `lib/pages` yang dipakai codelab sengaja dihilangkan, folder tersebut
sudah tidak ada karena refactor memindahkannya ke `features/*/presentation`.

### Grep 2: Domain steril dari framework & package

```powershell
rg "import 'package:flutter|import 'package:dio|import 'package:sqflite|import 'package:firebase" `
   lib/features/auth/domain lib/features/announcements/domain lib/features/notifications/domain lib/core
```

**Hasil: nol. `exit=1`**

---

## Pemeriksaan tambahan

Dipakai untuk membuktikan butir-butir checklist yang tidak tertangkap dua grep
di atas.

### Entity bebas mapping

```powershell
rg "toMap|fromMap|toJson|fromJson" lib/features/*/domain
```

**Hasil: nol. `exit=1`**

Sebagai pembanding, mapping hanya ada di dua file model:

```powershell
$ rg -ln "toJson|fromJson" lib/features
lib\features\announcements\data\models\announcement_model.dart
lib\features\auth\data\models\auth_session_model.dart
lib\features\announcements\data\repositories\mock_announcement_repository.dart
```

### Halaman tidak menginstansiasi repository

```powershell
rg "Repository\(|SecureTokenStore\(|Dio\(" `
   lib/features/auth/presentation/pages lib/features/announcements/presentation/pages
```

**Hasil: nol. `exit=1`**

Tidak ada widget yang `new Repository()` sendiri.

### DI terpusat di provider

Perintah yang sama dijalankan di seluruh `presentation`, **hasilnya 4 baris,
dan itu memang diharapkan**:

```
lib/features/announcements/presentation\providers\announcement_providers.dart:12:  return MockAnnouncementRepository();
lib/features/auth/presentation\providers\auth_providers.dart:21:final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
lib/features/auth/presentation\providers\auth_providers.dart:25:final authRepositoryProvider = Provider<AuthRepository>((ref) => MockAuthRepository());
lib/features/notifications/presentation\providers\push_providers.dart:32:  return FirebasePushRepository();
```

Keempatnya ada di file `providers/`, yang oleh codelab ditunjuk sebagai
"notifier + DI — Inilah satu-satunya tempat wiring". Yang harus nol adalah
folder `pages/`, dan itu memang nol.

---

## Kontrak vs implementasi

```powershell
$ rg -n "^abstract interface class" lib/features
lib\features\auth\domain\repositories\auth_repository.dart:14:abstract interface class AuthRepository {
lib\features\announcements\domain\repositories\announcement_repository.dart:14:abstract interface class AnnouncementRepository {
lib\features\auth\domain\repositories\token_store.dart:12:abstract interface class TokenStore {
lib\features\notifications\domain\repositories\push_repositories.dart:20:abstract interface class PushTokenSource {
lib\features\notifications\domain\repositories\push_repositories.dart:70:abstract interface class TopicSubscription {
lib\features\notifications\domain\repositories\push_repositories.dart:84:abstract interface class DeepLinkSource {
lib\features\notifications\domain\repositories\push_repositories.dart:94:abstract interface class DeviceRegistrar {
```

7 kontrak, **semuanya di `domain/`**. Tidak ada satu pun interface di `data/`.

```powershell
$ rg -n "implements (AuthRepository|TokenStore|AnnouncementRepository|DeviceRegistrar|PushTokenSource)" lib/features
lib\features\notifications\data\firebase_push_repository.dart:66:class FirebasePushRepository implements PushTokenSource, TopicSubscription, DeepLinkSource {
lib\features\notifications\data\dio_device_registrar.dart:14:class DioDeviceRegistrar implements DeviceRegistrar {
lib\features\announcements\data\repositories\mock_announcement_repository.dart:16:class MockAnnouncementRepository implements AnnouncementRepository {
lib\features\auth\data\datasources\secure_token_store.dart:10:class SecureTokenStore implements TokenStore {
lib\features\auth\data\datasources\secure_token_store.dart:39:class InMemoryTokenStore implements TokenStore {
lib\features\auth\data\repositories\mock_auth_repository.dart:13:class MockAuthRepository implements AuthRepository {
```

6 kelas implementasi, **semuanya di `data/`**.

---

## Static analysis dan test

```
$ flutter analyze
Analyzing campus_notify...
No issues found! (ran in 9.1s)

$ flutter test
00:08 +43: All tests passed!
```

Rincian test:

| Berkas | Jumlah | Isi |
|---|---|---|
| `test/format_test.dart` | 13 | Fungsi murni, tanpa widget |
| `test/domain/login_test.dart` | 11 | Fake repository, tanpa Dio/storage |
| `test/domain/get_announcement_test.dart` | 4 | Fake repository |
| `test/domain/register_device_test.dart` | 3 | Fake registrar |
| `test/auth_push_test.dart` | 7 | Adaptasi test Week 6 |
| `test/widget_test.dart` | 6 | Adaptasi test Week 6 |
| **Total** | **43** | |

---

## Ringkasan

| Pemeriksaan | Target | Hasil |
|---|---|---|
| Grep 1: presentation steril | nol | ✅ nol |
| Grep 2: domain steril | nol | ✅ nol |
| Entity bebas mapping | nol | ✅ nol |
| Halaman tidak menginstansiasi repository | nol | ✅ nol |
| Kontrak hanya di `domain` | semua | ✅ 7/7 |
| Implementasi hanya di `data` | semua | ✅ 6/6 |
| `flutter analyze` | bersih | ✅ `No issues found!` |
| `flutter test` | hijau | ✅ 43 test |

### Yang tidak bisa diverifikasi dengan grep

- **Uji manual 5 menit tiap fitur**, butuh perangkat fisik dan interaksi nyata.
- **Perbandingan before/after**, dilakukan lewat screenshot; lihat catatan di
  `README.md` bagian Screenshot.

---

## Cara menjalankan ulang

```bash
cd campus_notify
flutter pub get
flutter analyze
flutter test

# ripgrep hanya dipakai untuk verifikasi, bukan untuk build
winget install BurntSushi.ripgrep.MSVC
```
