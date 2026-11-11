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
/// ## Perubahan Week 11
///
/// Versi sebelumnya adalah satu `ConsumerStatefulWidget` 316 baris. Seluruh
/// halaman memakai satu `setState`, jadi setiap kali token FCM berubah, seluruh
/// halaman dibangun ulang: kartu sesi, kartu token, dua kartu menu, dan baris
/// teks yang tidak berubah sama sekali.
///
/// Sekarang halaman ini hanya `ConsumerWidget` yang membaca
/// [sessionDebugProvider]. State FCM dipindah ke [_FcmDebugCard] yang punya
/// `setState` sendiri, sehingga perubahan token hanya membangun ulang kartu itu.
///
/// `RepaintBoundary` di sekeliling kartu FCM memisahkan lapisan paint-nya, jadi
/// area lain tidak ikut di-repaint saat kartu itu berubah.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Notify'),
        actions: [
          IconButton(
            key: const Key('home-logout'),
            tooltip: 'Keluar',
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SessionCards(),
          const SizedBox(height: 8),
          const RepaintBoundary(child: _FcmDebugCard()),
          const SizedBox(height: 8),
          _MenuCard(
            itemKey: const Key('home-announcement'),
            icon: Icons.campaign_outlined,
            title: 'Pengumuman Campus',
            subtitle: 'Halaman tujuan deep link notifikasi (dari FCM).',
            route: Routes.announcementDetail('3'),
          ),
          const SizedBox(height: 8),
          _MenuCard(
            itemKey: const Key('home-announcement-list'),
            icon: Icons.list_alt_outlined,
            title: 'Daftar Pengumuman',
            subtitle: 'Lihat dan cari semua pengumuman kampus.',
            route: Routes.announcementList,
          ),
        ],
      ),
    );
  }
}

/// Penghitung build kartu sesi, hanya untuk test performa.
///
/// Dipakai `test/performance/rebuild_count_test.dart` untuk membuktikan bahwa
/// perubahan token FCM tidak membangun ulang kartu sesi. Angka ini tidak dipakai
/// di jalur produksi.
@visibleForTesting
int sessionCardsBuildCount = 0;

/// Kartu sesi aktif dan kartu Debug token.
///
/// Keduanya membaca [sessionDebugProvider], jadi digabung dalam satu widget
/// supaya provider itu hanya ditonton sekali. Kalau dipisah, satu perubahan
/// sesi akan membangun ulang dua widget, dan masing-masing melakukan
/// `ref.watch` sendiri.
///
/// Tidak ada `setState` di sini: seluruh isi berasal dari provider.
class _SessionCards extends ConsumerWidget {
  const _SessionCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    sessionCardsBuildCount++;
    final session = ref.watch(sessionDebugProvider);

    return Column(
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
                _TokenRow(label: 'Access', value: session.value?.maskedAccess),
                _TokenRow(
                  label: 'Refresh',
                  value: session.value?.maskedRefresh,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Kartu menu statis.
///
/// `const` di call site membuat widget ini tidak pernah dibangun ulang ketika
/// halaman induknya rebuild, karena seluruh argumennya sudah diketahui saat
/// kompilasi.
class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.itemKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final Key itemKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: itemKey,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}

/// Kartu Debug FCM.
///
/// State-nya dipisah dari halaman induk. Alasannya: kartu ini berubah paling
/// sering (token stream, izin, status device, langganan topik), sedangkan sisa
/// halaman hampir tidak pernah berubah. Sebelum dipisah, satu perubahan token
/// membangun ulang seluruh halaman 316 baris.
class _FcmDebugCard extends ConsumerStatefulWidget {
  const _FcmDebugCard();

  @override
  ConsumerState<_FcmDebugCard> createState() => _FcmDebugCardState();
}

class _FcmDebugCardState extends ConsumerState<_FcmDebugCard> {
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

    // Dengarkan token baru supaya kartu ini ikut berubah saat `onTokenRefresh`
    // berjalan, bukan hanya saat halaman dibuka.
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

    final topicName = ref.read(topicSubscriptionProvider).topicName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.subscribed
              ? 'Berlangganan topik $topicName'
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

  @override
  Widget build(BuildContext context) {
    final topicName = ref.watch(topicSubscriptionProvider).topicName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Debug FCM', style: Theme.of(context).textTheme.titleMedium),
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
              'Topik $topicName: ${_topicSubscribed ? 'aktif' : 'nonaktif'}',
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
