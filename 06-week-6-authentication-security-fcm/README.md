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
