import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/api_errors.dart';
import '../data/auth_repository.dart';

final _local = FlutterLocalNotificationsPlugin();

/// Id channel Android. Harus sama dengan `default_notification_channel_id` di
/// AndroidManifest supaya payload `notification` yang tiba saat aplikasi
/// background atau mati tampil memakai channel yang benar.
const androidChannelId = 'pengumuman';
const androidChannelName = 'Pengumuman Kampus';

/// Topik untuk broadcast ke semua mahasiswa. Pesan personal (nilai, tagihan)
/// tidak boleh memakai topik, melainkan token perangkat.
const campusTopic = 'pengumuman-kampus';

/// Route deep link dari klik notifikasi, baik yang arrives dari
/// `getInitialMessage` (terminated) maupun payload notifikasi lokal
/// (foreground). Routerocumented lewat [deepLinkStream] supaya pemilik router
/// tidak perlu mem-polling.
final _deepLinkController = StreamController<String>.broadcast();

Stream<String> get deepLinkStream => _deepLinkController.stream;

/// Menyerahkan route deep link yang terpendam dan mengosongkan buffer.
String? takePendingDeepLink() {
  final route = _pendingDeepLink;
  _pendingDeepLink = null;
  return route;
}

String? _pendingDeepLink;

void _emitDeepLink(String route) {
  _pendingDeepLink = route;
  if (_deepLinkController.isClosed) return;
  _deepLinkController.add(route);
}

/// Token perangkat terakhir yang diketahui. Disimpan supaya debug card dan
/// [registerDevice] tidak perlu memanggil `getToken()` berulang kali.
String? _cachedToken;

/// Handler background wajib fungsi top-level dengan `@pragma('vm:entry-point')`
/// karena berjalan di isolate terpisah. Di sini tidak boleh menyentuh
/// BuildContext maupun Riverpod; navigasi baru dilakukan setelah aplikasi
/// dibuka kembali.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    '[FCM background] route=${message.data['route']} '
    'title=${message.notification?.title}',
  );
}

void registerBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

/// Minta izin notifikasi runtime.
///
/// Android 13+ dan iOS wajib meminta izin secara eksplisit. Perhatikan bahwa
/// `FirebaseMessaging.instance.requestPermission()` hanya benar-benar
/// menampilkan dialog di iOS/macOS; di Android dialognya diambil lewat plugin
/// local notifications.
Future<bool> requestNotificationPermission() async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    announcement: false,
    carPlay: false,
    criticalAlert: false,
  );
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}

/// Inisialisasi plugin local notifications dan channel Android.
Future<void> initLocalNotifications() async {
  await _local.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (response) {
      // Klik banner saat aplikasi foreground: rute diserahkan lewat stream
      // supaya router tidak perlu mem-polling.
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) _emitDeepLink(payload);
    },
  );

  await _local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          androidChannelId,
          androidChannelName,
          importance: Importance.high,
        ),
      );
}

/// Lifecycle token: ambil token saat ini, kirim ke backend, lalu pantau
/// setiap perubahan.
///
/// Listener `onTokenRefresh` WAJIB ada. Token berubah setelah reinstall,
/// clear data aplikasi, atau rotasi keamanan. Tanpa listener ini backend
/// menyimpan token basi dan notifikasi tidak pernah sampai.
Future<void> initFcmToken({
  required Future<void> Function(String token) onToken,
  bool subscribeTopic = true,
}) async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    _cachedToken = token;
    await onToken(token);
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((fresh) {
    _cachedToken = fresh;
    unawaited(onToken(fresh));
  });

  if (subscribeTopic) {
    await subscribeCampusTopic();
  }
}

/// Berlangganan topik broadcast. Nama topik tidak boleh mengandung spasi.
Future<void> subscribeCampusTopic() async {
  await FirebaseMessaging.instance.subscribeToTopic(campusTopic);
  _topicSubscribed = true;
}

/// Berhenti berlangganan topik. Notifikasi broadcast berikutnya tidak lagi
/// sampai ke perangkat ini.
Future<void> unsubscribeCampusTopic() async {
  await FirebaseMessaging.instance.unsubscribeFromTopic(campusTopic);
  _topicSubscribed = false;
}

/// Status langganan topik lokal.
///
/// `firebase_messaging` 16.7.0 hanya menyediakan `subscribeToTopic` dan
/// `unsubscribeFromTopic` tanpa API untuk menanyakannya, jadi status di sini
/// dicatat dari hasil panggilan terakhir.
bool _topicSubscribed = false;

/// Status langganan topik, dipakai debug card untuk membuktikan
/// subscribe/unsubscribe benar-benar bekerja.
bool get isSubscribedToCampusTopic => _topicSubscribed;

/// Mengirim token ke backend. Endpoint `/devices` di codelab adalah
/// contoh; belum ada server sungguhan, jadi kegagalan network sengaja
/// ditampilkan di debug card sebagai bukti alur token benar-benar memanggil
/// jaringan.
Future<void> registerDevice(
  Dio dio, {
  void Function(String status)? onStatus,
}) async {
  final token = _cachedToken;
  if (token == null) {
    onStatus?.call('Token belum tersedia');
    return;
  }

  try {
    await dio.post<void>(
      '/devices',
      data: {'fcm_token': token, 'platform': 'android'},
    );
    onStatus?.call('POST /devices berhasil');
  } on DioException catch (e) {
    onStatus?.call('POST /devices gagal: ${readableApiError(e)}');
  }
}

/// Mendaftarkan listener pesan foreground dan background-terbuka.
///
/// Foreground: sistem Android TIDAK menampilkan banner otomatis, jadi
/// [showNotification] dipanggil manual. Navigasi sendiri TIDAK dilakukan di
/// sini; menunggu notifikasi diklik.
void listenForeground({void Function(RemoteMessage message)? onMessage}) {
  FirebaseMessaging.onMessage.listen((message) async {
    await showNotification(
      title: message.notification?.title ?? 'Pengumuman',
      body: message.notification?.body ?? '',
      payload: message.data['route'],
    );
    onMessage?.call(message);
  });

  // Background lalu diklik.
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    _emitDeepLink(routeFromMessage(message.data));
  });
}

/// Menampilkan notifikasi lokal secara manual.
///
/// Saat aplikasi foreground, sistem tidak menampilkan banner otomatis untuk
/// payload `notification`. Tanpa pemanggilan ini notifikasi hanya diam-diam
/// masuk tanpa jejak.
Future<void> showNotification({
  required String title,
  required String body,
  String? payload,
}) {
  return _local.show(
    id: DateTime.now().millisecondsSinceEpoch % 100000,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        androidChannelId,
        androidChannelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    payload: payload,
  );
}

/// Notifikasi buatan sendiri untuk membuktikan alur foreground dan klik
/// notifikasi tanpa menunggu Firebase Console.
Future<void> simulateNotification({String route = '/pengumuman/3'}) {
  return showNotification(
    title: 'Jadwal kuliah berubah',
    body: 'Kelas Mobile pindah ke Ruang A2 jam 13.00',
    payload: route,
  );
}

/// Membaca `data.route` dari payload FCM menjadi rute GoRouter yang valid.
String routeFromMessage(Map<String, dynamic> data) {
  final route = data['route'] as String? ?? '/';
  return route.startsWith('/') ? route : '/$route';
}

/// Menangani kasus terminated: aplikasi dibuka dari notifikasi. Panggil
/// setelah router siap.
Future<void> handleTerminated() async {
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) _emitDeepLink(routeFromMessage(initial.data));
}

/// Token hanya ditampilkan 12 karakter pertama, tidak pernah penuh.
String maskedToken() => maskToken(_cachedToken);
