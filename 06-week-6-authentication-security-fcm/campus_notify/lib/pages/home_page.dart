import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_repository.dart';
import '../messaging/push_service.dart';
import '../providers/auth_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _maskedAccess;
  String? _maskedRefresh;
  String? _email;
  String? _permissionStatus;
  String? _fcmToken;
  String? _deviceStatus;
  bool _topicSubscribed = false;

  @override
  void initState() {
    super.initState();
    _loadDebugTokens();
    _loadFcmToken();
  }

  Future<void> _loadDebugTokens() async {
    final store = ref.read(tokenStoreProvider);
    final access = await store.readAccess();
    final refresh = await store.readRefresh();
    if (!mounted) return;
    setState(() {
      _maskedAccess = maskToken(access);
      _maskedRefresh = maskToken(refresh);
      _email = _emailFromRefresh(refresh);
    });
  }

  Future<void> _loadFcmToken() async {
    // Token sudah diambil saat initFcmToken; ini hanya membaca salinan yang
    // disimpan supaya tidak memanggil getToken() berulang kali.
    final token = maskedToken();
    if (!mounted) return;
    setState(() {
      _fcmToken = token;
      _topicSubscribed = isSubscribedToCampusTopic;
    });
  }

  /// Topik hanya untuk broadcast (semua mahasiswa). Pesan personal seperti
  /// nilai atau tagihan harus dikirim ke token perangkat, bukan ke topik.
  Future<void> _toggleTopic() async {
    final subscribe = !_topicSubscribed;
    await (subscribe ? subscribeCampusTopic() : unsubscribeCampusTopic());
    if (!mounted) return;
    setState(() => _topicSubscribed = subscribe);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          subscribe
              ? 'Berlangganan topik $campusTopic'
              : 'Berhenti berlangganan topik $campusTopic',
        ),
      ),
    );
  }

  /// Refresh token mock berbentuk `refresh:<email>|<timestamp>`. Backend
  /// sungguhan akan mengembalikan profil lewat `GET /me`.
  String? _emailFromRefresh(String? refresh) {
    if (refresh == null || !refresh.startsWith('refresh:')) return null;
    return refresh.substring('refresh:'.length).split('|').first;
  }

  Future<void> _requestPermission() async {
    final granted = await requestNotificationPermission();
    if (!mounted) return;
    setState(() =>
        _permissionStatus = granted ? 'Izin diberikan' : 'Izin ditolak');
  }

  Future<void> _registerDevice() async {
    setState(() => _deviceStatus = 'Mengirim...');
    await registerDevice(
      ref.read(apiClientProvider),
      onStatus: (status) {
        if (mounted) setState(() => _deviceStatus = status);
      },
    );
  }

  Future<void> _logout() => ref.read(authStateProvider.notifier).logout();

  @override
  Widget build(BuildContext context) {
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
              subtitle: Text(_email ?? 'Pengguna campus'),
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
                  _TokenRow(label: 'Access', value: _maskedAccess),
                  _TokenRow(label: 'Refresh', value: _maskedRefresh),
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
                        onPressed: simulateNotification,
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
                    icon: Icon(_topicSubscribed
                        ? Icons.unsubscribe_outlined
                        : Icons.newspaper_outlined),
                    label: Text(_topicSubscribed
                        ? 'Berhenti berlangganan topik'
                        : 'Berlangganan topik'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Topik $campusTopic: '
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
              onTap: () => context.push('/pengumuman/3'),
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
