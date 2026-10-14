import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/failures.dart';
import '../../../core/format.dart';
import '../domain/repositories/push_repositories.dart';

final _local = FlutterLocalNotificationsPlugin();

/// Id channel Android. Harus sama dengan `default_notification_channel_id` di
/// AndroidManifest supaya payload `notification` yang tiba saat aplikasi
/// background atau mati tampil memakai channel yang benar.
const androidChannelId = 'pengumuman';
const androidChannelName = 'Pengumuman Kampus';

/// Topik untuk broadcast ke semua mahasiswa. Pesan personal (nilai, tagihan)
/// tidak boleh memakai topik, melainkan token perangkat.
const campusTopic = 'pengumuman-kampus';

/// Route deep link dari klik notifikasi, baik yang datang dari
/// `getInitialMessage` (terminated) maupun payload notifikasi lokal
/// (foreground). Disiarkan lewat [deepLinks] supaya pemilik router tidak perlu
/// mem-polling.
final _deepLinkController = StreamController<String>.broadcast();

/// Emit setiap token baru (pertama maupun hasil refresh) supaya debug card ikut
/// berubah seketika tanpa harus mem-polling.
final _tokenController = StreamController<String>.broadcast();

/// Token perangkat terakhir yang diketahui. Disimpan supaya debug card dan
/// device registrar tidak perlu memanggil `getToken()` berulang kali.
String? _cachedToken;

/// Momen token terakhir diterima, dipakai debug card untuk membuktikan bahwa
/// `onTokenRefresh` benar-benar terpanggil.
DateTime? _tokenUpdatedAt;

/// Status langganan topik lokal.
bool _topicSubscribed = false;

/// Handler background wajib fungsi top-level dengan `@pragma('vm:entry-point')`
/// karena berjalan di isolate terpisah.
///
/// Di sini tidak boleh menyentuh BuildContext maupun Riverpod — keduanya tidak
/// ada di isolate itu, dan menyentuhnya membuat crash. Navigasi baru dilakukan
/// setelah aplikasi dibuka kembali.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    '[FCM background] route=${message.data['route']} '
    'title=${message.notification?.title}',
  );
}

/// Dipanggil sekali dari `main()` sebelum `runApp` — harus sebelum aplikasi
/// masuk foreground, karena Android tidak mengirim broadcast ke aplikasi yang
/// sudah terminated.
void registerBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

/// Implementasi kontrak push di atas Firebase Cloud Messaging.
class FirebasePushRepository implements PushTokenSource, TopicSubscription, DeepLinkSource {
  @override
  Stream<String> get deepLinks => _deepLinkController.stream;

  @override
  Stream<String> get tokenStream => _tokenController.stream;

  @override
  String get maskedToken => maskToken(_cachedToken);

  @override
  DateTime? get tokenUpdatedAt => _tokenUpdatedAt;

  @override
  String get topicName => campusTopic;

  @override
  bool get isSubscribed => _topicSubscribed;

  /// Token mentah. Hanya dibaca dari `data/`, tidak pernah ditampilkan: debug
  /// card memakai [maskedToken].
  String? get currentToken => _cachedToken;

  @override
  String? takePendingDeepLink() {
    final route = _pendingDeepLink;
    _pendingDeepLink = null;
    return route;
  }

  String? _pendingDeepLink;

  @override
  Future<void> initialize({required Future<void> Function(String token) onToken}) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      _cacheToken(token);
      await onToken(token);
    }

    // Listener `onTokenRefresh` WAJIB ada.
    FirebaseMessaging.instance.onTokenRefresh.listen((fresh) {
      _cacheToken(fresh);
      unawaited(onToken(fresh));
    });

    await setSubscribed(value: true);
  }

  @override
  Future<({bool granted, Failure? failure})> requestPermission() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return (granted: await android?.requestNotificationsPermission() ?? false, failure: null);
      }

      // Di iOS/macOS hanya Firebase yang menangani dialog izin.
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      return (granted: granted, failure: null);
    } on Object catch (error) {
      return (granted: false, failure: LocalFailure('Gagal meminta izin: $error'));
    }
  }

  @override
  Future<({bool subscribed, Failure? failure})> setSubscribed({required bool value}) async {
    try {
      if (value) {
        await FirebaseMessaging.instance.subscribeToTopic(campusTopic);
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic(campusTopic);
      }
      _topicSubscribed = value;
      return (subscribed: value, failure: null);
    } on Object catch (error) {
      return (subscribed: _topicSubscribed, failure: LocalFailure('Gagal mengubah langganan topik: $error'));
    }
  }

  @override
  Future<void> simulateNotification({required String route}) {
    return showNotification(
      title: 'Jadwal kuliah berubah',
      body: 'Kelas Mobile pindah ke Ruang A2 jam 13.00',
      payload: route,
    );
  }

  /// Menyimpan token baru beserta waktu penerimaannya, lalu menyiarkannya.
  void _cacheToken(String token) {
    _cachedToken = token;
    _tokenUpdatedAt = DateTime.now();
    if (_tokenController.isClosed) return;
    _tokenController.add(token);
  }

  void _emitDeepLink(String route) {
    _pendingDeepLink = route;
    if (_deepLinkController.isClosed) return;
    _deepLinkController.add(route);
  }

  /// Inisialisasi plugin local notifications dan channel Android.
  @override
  Future<void> initLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        // Klik banner saat foreground: rute diserahkan lewat stream supaya
        // router tidak perlu mem-polling.
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

  /// Mendaftarkan listener pesan foreground dan background-terbuka.
  ///
  /// Foreground: sistem Android TIDAK menampilkan banner otomatis, jadi notif
  /// lokal ditampilkan manual. Navigasi sendiri tidak dilakukan di sini —
  /// menunggu notifikasi diklik.
  @override
  void listenForeground() {
    FirebaseMessaging.onMessage.listen((message) async {
      await showNotification(
        title: message.notification?.title ?? 'Pengumuman',
        body: message.notification?.body ?? '',
        payload: message.data['route'],
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _emitDeepLink(routeFromMessage(message.data));
    });
  }

  /// Menampilkan notifikasi lokal secara manual.
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

  /// Menangani kasus terminated: aplikasi dibuka dari notifikasi.
  ///
  /// Harus dipanggil SEBELUM `initialize()` karena `getToken()` menunggu
  /// jaringan. Kalau ditunda, navigasi deep link tertahan sampai token selesai
  /// diambil, dan gagal total saat jaringan buruk.
  @override
  Future<void> handleTerminated() async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _emitDeepLink(routeFromMessage(initial.data));
  }
}