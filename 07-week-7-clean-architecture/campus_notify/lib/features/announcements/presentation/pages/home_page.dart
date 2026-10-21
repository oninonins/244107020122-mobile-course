import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format.dart';
import '../../../../routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/providers/push_providers.dart';

/// Dashboard.
///
/// Bandingkan dengan versi Week 6:
///
/// | Dulu (291 baris)                              | Sekarang                          |
/// |-----------------------------------------------|-----------------------------------|
/// | `ref.read(apiClientProvider)` -> `registerDevice` | lewat use case `registerDeviceProvider` |
/// | `_formatTime()` sendiri                       | `core/format.dart`                |
/// | `_emailFromRefresh()` sendiri                  | `core/format.dart`                |
/// | `maskedToken()`, `tokenStream`, `subscribeCampusTopic()` | kontrak `PushTokenSource` |
/// | `ref.read(tokenStoreProvider).readAccess()`    | `sessionDebugProvider`            |
///
/// Tidak ada lagi `Dio`, `FirebaseMessaging`, atau plugin penyimpanan di file ini.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _permissionStatus;
  String? _deviceStatus;
  bool _topicSubscribed = false;
  String? _fcmToken;
  String? _tokenUpdatedAt;
  StreamSubscription<String>? _tokenSub;

  @override
  void initState() {
    super.initState();

    // Token sudah diambil saat `initialize()`; ini hanya membaca salinan yang
    // disimpan supaya tidak memanggil getToken() berulang kali.
    _syncPushDebug();

    // Dengarkan token baru supaya kartu debug ikut berubah saat
    // `onTokenRefresh` berjalan, bukan hanya saat halaman dibuka.
    _tokenSub = ref.read(pushTokenSourceProvider).tokenStream.listen((token) {
      if (!mounted) return;
      setState(() {
        _fcmToken = maskToken(token);
        _tokenUpdatedAt = formatClock(
          ref.read(pushTokenSourceProvider).tokenUpdatedAt,
        );
      });
    });
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    super.dispose();
  }

  void _syncPushDebug() {
    final push = ref.read(pushTokenSourceProvider);
    final topic = ref.read(topicSubscriptionProvider);
    setState(() {
      _fcmToken = push.maskedToken;
      _tokenUpdatedAt = formatClock(push.tokenUpdatedAt);
      _topicSubscribed = topic.isSubscribed;
    });
  }

  Future<void> _requestPermission() async {
    final result = await ref.read(pushTokenSourceProvider).requestPermission();
    if (!mounted) return;
    setState(
      () => _permissionStatus = result.granted
          ? 'Izin diberikan'
          : 'Izin ditolak',
    );
  }

  Future<void> _registerDevice() async {
    setState(() => _deviceStatus = 'Mengirim...');
    final result = await ref.read(registerDeviceProvider).call();
    if (!mounted) return;
    setState(() => _deviceStatus = result.status ?? result.failure?.message);
  }

  /// Topik hanya untuk broadcast (semua mahasiswa). Pesan personal seperti
  /// nilai atau tagihan harus dikirim ke token perangkat, bukan ke topik.
  Future<void> _toggleTopic() async {
    final subscribe = !_topicSubscribed;
    final result = await ref
        .read(topicSubscriptionProvider)
        .setSubscribed(value: subscribe);
    if (!mounted) return;
    setState(() => _topicSubscribed = result.subscribed);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.subscribed
              ? 'Berlangganan topik ${result.subscribed ? topicName : ''}'
                    .trim()
              : 'Berhenti berlangganan topik $topicName',
        ),
      ),
    );
  }

  Future<void> _simulateNotification() {
    return ref
        .read(pushTokenSourceProvider)
        .simulateNotification(route: Routes.announcementDetail('3'));
  }

  String get topicName => ref.read(topicSubscriptionProvider).topicName;

  Future<void> _logout() => ref.read(authStateProvider.notifier).logout();

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionDebugProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Notify'),
        actions: [
          IconButton(
            key: const Key('home-logout'),
            tooltip: 'Keluar',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Sesi aktif'),
              subtitle: Text(
                session.value?.email ??
                    session.error?.toString() ??
                    'Pengguna campus',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug token',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hanya 12 karakter pertama yang ditampilkan. Jangan pernah '
                    'menampilkan token penuh di screenshot laporan.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _TokenRow(
                    label: 'Access',
                    value: session.value?.maskedAccess,
                  ),
                  _TokenRow(
                    label: 'Refresh',
                    value: session.value?.maskedRefresh,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug FCM',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _TokenRow(label: 'Token', value: _fcmToken),
                  _TokenRow(label: 'Diperbarui', value: _tokenUpdatedAt),
                  if (_permissionStatus != null)
                    _TokenRow(label: 'Izin', value: _permissionStatus),
                  if (_deviceStatus != null)
                    _TokenRow(label: 'Device', value: _deviceStatus),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('home-ask-permission'),
                        onPressed: _requestPermission,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Minta izin'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('home-register-device'),
                        onPressed: _registerDevice,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Kirim token'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('home-simulate-push'),
                        onPressed: _simulateNotification,
                        icon: const Icon(Icons.notification_important_outlined),
                        label: const Text('Simulasikan notifikasi'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('home-toggle-topic'),
                    onPressed: _toggleTopic,
                    icon: Icon(
                      _topicSubscribed
                          ? Icons.unsubscribe_outlined
                          : Icons.newspaper_outlined,
                    ),
                    label: Text(
                      _topicSubscribed
                          ? 'Berhenti berlangganan topik'
                          : 'Berlangganan topik',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Topik $topicName: '
                    '${_topicSubscribed ? 'aktif' : 'nonaktif'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Topik untuk broadcast ke semua mahasiswa. Nilai dan '
                    'tagihan dikirim ke token perangkat, bukan topik.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              key: const Key('home-announcement'),
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('Pengumuman Campus'),
              subtitle: const Text(
                'Halaman tujuan deep link notifikasi (dari FCM).',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.announcementDetail('3')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  const _TokenRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
