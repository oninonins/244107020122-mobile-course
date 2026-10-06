# Week 6 — Authentication, Security & FCM

Campus Notify: aplikasi notifikasi pengumuman kampus dengan login terlindungi,
penyimpanan token aman, dan Firebase Cloud Messaging.

## Tujuan

- Menjelaskan alur autentikasi dan perbedaan ID token, access token, dan refresh token.
- Menyimpan token di secure storage dengan token refresh otomatis.
- Mengelola FCM: permission, token lifecycle, tiga app state, dan topic messaging.

## Fitur Utama

| Fitur | Implementasi |
|---|---|
| Login + guard route | GoRouter `redirect`, belum login selalu ke `/login` |
| Penyimpanan token aman | `flutter_secure_storage` (Keychain/Keystore), bukan SharedPreferences |
| Refresh otomatis | Dio interceptor mencoba refresh **sekali** saat 401, lalu mengulang request |
| Logout paksa | Refresh token ditolak → secure storage dikosongkan → guard ke `/login` |
| Permission notifikasi | Jalur terpisah Android (plugin) dan iOS (`requestPermission`) |
| Token lifecycle | `getToken()` + listener `onTokenRefresh` (wajib) |
| Topic messaging | Subscribe/unsubscribe `pengumuman-kampus` |
| Deep link | `data.route` → `routeFromMessage()` → navigasi GoRouter |

## Stack Teknologi

- Flutter 3.47.5 / Dart 3.13.4
- Riverpod 3 (`AsyncNotifier`) — status autentikasi
- GoRouter 18 — routing + guard + deep link
- Dio 5 — HTTP client + interceptor refresh token
- flutter_secure_storage 11 — penyimpanan token
- firebase_core 4 / firebase_messaging 16 / flutter_local_notifications 22

## Cara Menjalankan

```bash
cd campus_notify
flutter pub get

# Salin google-services.json ke android/app/ (jangan di-commit)
flutter run
```

**Akun demo:** email bebas berformat email, kata sandi minimal 6 karakter.

Login → kartu **Debug token** menampilkan token terpotong 12 karakter.
Kartu **Debug FCM** berisi status izin, token perangkat, tombol kirim token,dan toggle topik.

## Payload Notifikasi

Backend mengirim gabungan `notification` + `data`:

```json
{
  "message": {
    "topic": "pengumuman-kampus",
    "notification": {
      "title": "Jadwal kuliah berubah",
      "body": "Kelas Mobile pindah ke Ruang A2 jam 13.00"
    },
    "data": {
      "route": "/pengumuman/3",
      "id": "3"
    }
  }
}
```

`notification` adalah teks yang dibaca manusia; `data.route` menentukan tujuan
saat notifikasi diklik. Keduanya wajib dikirim bersama karena `notification`
saja tidak membawa rute, dan `data` saja tidak menampilkan banner otomatis.

## Matriks Pengujian Tiga App State

Uji ketiga state memakai payload yang sama.

| State | Yang diharapkan | Cara uji | Bukti |
|---|---|---|---|
| Foreground | Banner lokal muncul, klik masuk ke `/pengumuman/3` | Aplikasi terbuka, kirim dari console/backend | `screenshots/dasboard.jpeg` |
| Background | Banner sistem muncul, klik masuk ke rute yang benar | Tekan Home, kirim, klik banner | `screenshots/fcm-console-test.jpeg` |
| Terminated | Aplikasi terbuka ke rute yang benar via `getInitialMessage` | Swipe-close aplikasi, kirim, klik banner | `screenshots/fcm-console-test2.jpeg` |

Screenshot lain:

| Berkas | Isi |
|---|---|
| `screenshots/loginPage.jpeg` | Halaman login |
| `screenshots/dasboard.jpeg` | Dashboard, kartu debug token terpotong |
| `screenshots/fcm-console-test.jpeg` | Pengiriman dari Firebase Console |
| `screenshots/fcm-console-test2.jpeg` | setelah menekan notifikasi |

## Topik vs Token Perangkat

- **Topik** untuk broadcast: pengumuman umum, perubahan jadwal, info seminar.
  Aturan: nama tanpa spasi, semua penerima berada di channel yang sama.
- **Token perangkat** untuk pesan personal: nilai akademik, tagihan, absensi.
  Jangan pernah mengirim tagihan ke topik karena akan terlihat semua mahasiswa.

## Catatan Teknis

- **Refresh hanya dicoba sekali.** Request yang gagal 401 diberi penanda
  `auth_retried` sebelum dikirim ulang, tanpa itu endpoint yang selalu 401 akan
  loop. Kalau refresh juga gagal, token dihapus dan pengguna dipaksa login.
- **Background handler wajib top-level** dengan `@pragma('vm:entry-point')`
  karena berjalan di isolate terpisah. Fungsi ini tidak boleh menyentuh
  `BuildContext` maupun Riverpod.
- **`getInitialMessage()` dipanggil paling awal**, sebelum `getToken()` yang
  menunggu jaringan. Kalau ditunda, navigasi deep link tertahan sampai token
  selesai diambil dan gagal total saat jaringan buruk.
- **Permission Android diambil dari plugin local notifications.**
  `FirebaseMessaging.instance.requestPermission()` hanya bekerja di iOS/macOS.
- **Token tidak pernah ditampilkan penuh** di UI maupun screenshot laporan —
  hanya 12 karakter pertama.
- **`flutter_local_notifications` 22.x** memakai named parameter
  (`initialize(settings: ...)`, `show(id: ...)`), berbeda dari versi lama yang
  memakai parameter posisional.

## AI Challenge

### Prompt yang diberikan

```text
Aplikasi Flutter Campus Notification App.
Stack: firebase_messaging, flutter_local_notifications,
flutter_secure_storage, go_router, Riverpod.
Buatkan PushService dengan:
- requestPermission + getToken + onTokenRefresh (kirim ke POST /devices)
- onMessage (tampilkan local notification manual)
- onMessageOpenedApp + getInitialMessage (navigasi ke data.route)
- subscribe/unsubscribe topic pengumuman-kampus
- background handler top-level dengan @pragma('vm:entry-point')
Tandai bagian yang BERBEDA untuk Android 13+ vs iOS,
dan bagian yang tidak boleh mengakses BuildContext.
```

### Hasil verifikasi checklist

Checklist diambil dari codelab, lalu dicocokkan dengan kode yang benar-benar
terimplementasi di `campus_notify/lib/messaging/push_service.dart`.

| Checklist | Status | Bukti |
|---|---|---|
| Background handler **fungsi top-level** dengan `@pragma('vm:entry-point')`, bukan method kelas | ✅ | `push_service.dart:54` |
| `onTokenRefresh` benar-benar **mengirim** token baru ke backend, bukan hanya dicetak ke log | ⚠️ **belum** | listener ada dan token tersimpan, tapi belum memanggil `POST /devices` — masih manual dari debug card |
| Foreground memakai local notification **manual** | ✅ | `push_service.dart:199` → `showNotification()` |
| Klik dari ketiga state masuk ke rute yang benar | ✅ | `routeFromMessage()` + `deepLinkStream` |
| Token/secret tidak di-hardcode dan tidak di-log penuh | ✅ | `maskedToken()` hanya 12 karakter |
| Bagian Android 13+ vs iOS ditandai jelas | ✅ | `requestNotificationPermission()` |

### Bagian yang berbeda: Android 13+ vs iOS

```dart
Future<bool> requestNotificationPermission() async {
  // ANDROID 13+ (API 33): dialog izin diambil dari plugin local
  // notifications, BUKAN dari Firebase. Firebase hanya memunculkan dialog
  // di iOS/macOS. Kalau salah, notifikasi tidak pernah tampil dan sulit
  // didiagnosis.
  if (defaultTargetPlatform == TargetPlatform.android) {
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  // iOS / macOS: hanya di sini Firebase yang menangani dialog izin.
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true, badge: true, sound: true,
    announcement: false, carPlay: false, criticalAlert: false,
  );
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}
```

Perbedaan lain:

| Aspek | Android | iOS |
|---|---|---|
| Dialog izin runtime | Plugin local notifications | `FirebaseMessaging.instance.requestPermission()` |
| `@mipmap/ic_launcher` sebagai ikon | `AndroidInitializationSettings` | Tidak dipakai, iOS memakai `DarwinInitializationSettings()` |
| Channel notifikasi | Wajib (`createNotificationChannel`) | Tidak ada konsep channel |

### Bagian yang tidak boleh mengakses `BuildContext`

```dart
// WAJIB top-level + @pragma('vm:entry-point').
// Jangan pernah menambah BuildContext, ref Riverpod, atau navigasi di sini.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM background] route=${message.data['route']}');
}
```

Alasannya: handler ini berjalan di **isolate terpisah** yang di-*spin up* oleh
engine ketika pesan tiba, terpisah dari isolate UI. `BuildContext`, `ref`
Riverpod, dan router tidak ada di sana — menyentuh salah satunya akan crash
dengan `Null check operator used on a null value` atau `ProviderNotFound`.

Tugasnya hanya mencatat. Navigasi dilakukan setelah aplikasi dibuka, melalui
`getInitialMessage()` atau `onMessageOpenedApp()`.

### Perbaikan manual terhadap draf awal

| Masalah | Gejala | Perbaikan |
|---|---|---|
| `flutter_local_notifications` 22.x breaking change | Kode codelab tidak bisa dikompilasi | Pakai named parameter: `initialize(settings: ...)` dan `show(id:, title:, ...)` |
| Izin notifikasi Android tidak muncul | Banner tidak pernah tampil saat diuji | Dialog Android diambil dari plugin local notifications, bukan dari Firebase |
| `getInitialMessage()` dipanggil paling akhir | Deep link tertahan sampai `getToken()` selesai | Dipindah sebelum `initFcmToken()` supaya tidak menunggu jaringan |
| `ref.listen` dipanggil dari `initState()` | Crash: *"ref.listen can only be used within the build method of a ConsumerWidget"* | Router dipindah ke `Provider`, memakai `Ref.listen` provider yang tidak punya guard tersebut |
| Refresh token diulang tanpa batas | Endpoint 401 loop | Penanda `auth_retried` pada `RequestOptions.extra` |
| `TokenStore` tidak bisa di-fake untuk test | `InMemoryTokenStore` gagal di-*implement* | `TokenStore` dipecah jadi `abstract interface class` + dua implementasi |
| Kotlin incremental cache gagal | *"this and base files have different roots"* (pub cache di `C:`, project di `D:`) | `kotlin.incremental=false` di `android/gradle.properties` |

### Keputusan akhir

- **`POST /devices` tetap dipanggil dari debug card** sementara, bukan otomatis,
  karena belum ada backend sungguhan. Endpoint `example-campus-api.test` pasti
  gagal dan kegagalannya justru dipakai sebagai bukti bahwa alur token benar
  memanggil jaringan.
- **Status topik dilacak lokal.** `firebase_messaging` 16.7.0 hanya punya
  `subscribeToTopic` dan `unsubscribeFromTopic` tanpa API untuk menanyakan
  status, jadi state disimpan manual dari panggilan terakhir.
- **Firebase BoM tidak ditambahkan.** Pola `firebase-bom` + `implementation(...)`
  itu untuk Android native. Di Flutter, versi SDK sudah dibawa plugin
  `firebase_core`/`firebase_messaging`; menambahkannya manual berisiko
  konflik versi.
