import '../../../../core/failures.dart';

/// Kontrak-primitives untuk fitur notifikasi.
///
/// Codelab menyebut satu interface raksasa `AppRepository` sebagai gejala
/// pelanggaran Interface Segregation. Karena itu kontrak di sini dipecah
/// menjadi empat, masing-masing untuk satu kelompok pemakai yang berbeda:
///
/// | Interface              | Yang memakainya                          |
/// |------------------------|------------------------------------------|
/// | [PushTokenSource]      | kartu Debug FCM, orchestrator messaging   |
/// | [TopicSubscription]    | tombol toggle topik                      |
/// | [DeepLinkSource]       | router GoRouter                          |
/// | `DeviceRegistrar`      | use case `RegisterDevice`                |
///
/// Kalau keempatnya digabung, menguji `RegisterDevice` berarti harus membuat
/// fake Firebase beserta seluruh permintaannya.

/// Sumber token perangkat dan hak akses notifikasi.
abstract interface class PushTokenSource {
  /// Token terakhir yang diketahui, sudah ter-mask aman untuk ditampilkan.
  String? get maskedToken;

  /// Kapan token terakhir diterima. Dipakai kartu debug untuk membuktikan
  /// `onTokenRefresh` benar-benar terpanggil.
  DateTime? get tokenUpdatedAt;

  /// Emit setiap token baru (pertama maupun hasil refresh) supaya kartu debug
  /// ikut berubah seketika tanpa harus mem-polling.
  Stream<String> get tokenStream;

  /// Meminta izin notifikasi runtime.
  ///
  /// Android 13+ dan iOS wajib meminta izin secara eksplisit. Android diambil
  /// lewat plugin local notifications; `FirebaseMessaging` hanya memunculkan
  /// dialog di iOS/macOS. Salah pilih berarti banner tidak pernah tampil dan
  /// sulit didiagnosis.
  Future<({bool granted, Failure? failure})> requestPermission();

  /// Siklus hidup token: ambil token saat ini, lanjutkan lewat [onToken], lalu
  /// pantau setiap perubahan.
  ///
  /// Listener pembaruan WAJIB ada. Token berubah setelah uninstall, clear data,
  /// atau rotasi keamanan; tanpa listener itu backend menyimpan token mati dan
  /// notifikasi tidak pernah sampai tanpa error yang terlihat.
  Future<void> initialize({required Future<void> Function(String token) onToken});

  /// Inisialisasi plugin local notifications dan channel Android.
  Future<void> initLocalNotifications();

  /// Mendaftarkan listener pesan foreground dan background-terbuka.
  ///
  /// Foreground: sistem Android TIDAK menampilkan banner otomatis, jadi notif
  /// lokal ditampilkan manual.
  void listenForeground();

  /// Menangani kasus terminated: aplikasi dibuka dari notifikasi.
  ///
  /// Harus dipanggil SEBELUM [initialize] karena `getToken()` menunggu
  /// jaringan. Kalau ditunda, navigasi deep link tertahan sampai token selesai
  /// diambil, dan gagal total saat jaringan buruk.
  Future<void> handleTerminated();

  /// Notifikasi buatan sendiri untuk membuktikan alur foreground dan klik notif
  /// tanpa menunggu Firebase Console.
  Future<void> simulateNotification({required String route});
}

/// Langganan topik broadcast.
abstract interface class TopicSubscription {
  /// Topik untuk broadcast ke semua mahasiswa. Pesan personal (nilai, tagihan)
  /// tidak boleh memakai topik, melainkan token perangkat.
  String get topicName;

  /// Status langganan lokal. `firebase_messaging` hanya menyediakan
  /// subscribe/unsubscribe tanpa API untuk menanyakannya, jadi status dicatat
  /// dari hasil panggilan terakhir.
  bool get isSubscribed;

  Future<({bool subscribed, Failure? failure})> setSubscribed({required bool value});
}

/// Sumber deep link dari payload notifikasi.
abstract interface class DeepLinkSource {
  /// Rute tujuan yang berasal dari klik notifikasi.
  Stream<String> get deepLinks;

  /// Menyerahkan rute yang tertahan (kasus aplikasi dibuka dari notifikasi saat
  /// dalam keadaan terminated) lalu mengosongkan penyimpanannya.
  String? takePendingDeepLink();
}

/// Mendaftarkan token perangkat ke backend.
abstract interface class DeviceRegistrar {
  /// `status` yang dikembalikan adalah pesan yang sudah ramah pengguna untuk
  /// ditampilkan di debug card, karena endpoint contoh memang belum ada.
  Future<({String? status, Failure? failure})> registerDevice();
}
