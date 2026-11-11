import 'dart:async';

import 'package:campus_notify/core/failures.dart';
import 'package:campus_notify/features/announcements/presentation/pages/home_page.dart';
import 'package:campus_notify/features/auth/data/datasources/secure_token_store.dart';
import 'package:campus_notify/features/auth/presentation/providers/auth_providers.dart';
import 'package:campus_notify/features/notifications/domain/repositories/push_repositories.dart';
import 'package:campus_notify/features/notifications/presentation/providers/push_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sumber push tiruan dengan stream yang bisa dikendalikan test.
class FakePushTokenSource implements PushTokenSource {
  FakePushTokenSource();

  final _tokens = StreamController<String>.broadcast();

  String? _masked;
  DateTime? _updatedAt;

  void emitToken(String token) {
    _masked = token;
    _updatedAt = DateTime(2026, 10, 29, 14, 30);
    _tokens.add(token);
  }

  @override
  String? get maskedToken => _masked;

  @override
  DateTime? get tokenUpdatedAt => _updatedAt;

  @override
  Stream<String> get tokenStream => _tokens.stream;

  @override
  Future<({bool granted, Failure? failure})> requestPermission() async =>
      (granted: true, failure: null);

  @override
  Future<void> initialize({
    required Future<void> Function(String token) onToken,
  }) async {}

  @override
  Future<void> initLocalNotifications() async {}

  @override
  void listenForeground() {}

  @override
  Future<void> handleTerminated() async {}

  @override
  Future<void> simulateNotification({required String route}) async {}
}

class FakeTopicSubscription implements TopicSubscription {
  bool _subscribed = false;

  @override
  String get topicName => 'pengumuman-kampus';

  @override
  bool get isSubscribed => _subscribed;

  @override
  Future<({bool subscribed, Failure? failure})> setSubscribed({
    required bool value,
  }) async {
    _subscribed = value;
    return (subscribed: value, failure: null);
  }
}

class FakeDeepLinkSource implements DeepLinkSource {
  @override
  Stream<String> get deepLinks => const Stream.empty();

  @override
  String? takePendingDeepLink() => null;
}

void main() {
  testWidgets('token FCM berubah tanpa membangun ulang kartu sesi', (
    tester,
  ) async {
    final push = FakePushTokenSource();
    final topic = FakeTopicSubscription();
    final store = InMemoryTokenStore()
      ..access = 'mock-access-token-1234567890.sig'
      ..refresh = 'refresh:mhs@polinema.ac.id|1';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          pushTokenSourceProvider.overrideWithValue(push),
          topicSubscriptionProvider.overrideWithValue(topic),
          deepLinkSourceProvider.overrideWithValue(FakeDeepLinkSource()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    sessionCardsBuildCount = 0;

    // Token baru tiba, seperti saat `onTokenRefresh` berjalan.
    push.emitToken('token-baru-dari-refresh');
    await tester.pumpAndSettle();

    // Kartu FCM berubah, tetapi kartu sesi tidak ikut dibangun ulang.
    expect(
      sessionCardsBuildCount,
      0,
      reason:
          'state FCM ada di _FcmDebugCard, jadi setState-nya tidak boleh '
          'menyentuh _SessionCards. Sebelum dipisah, satu setState di halaman '
          'membangun ulang seluruh halaman termasuk kartu sesi.',
    );

    // Bukti bahwa token baru memang diterima dan ditampilkan.
    expect(find.textContaining('token-baru-'), findsOneWidget);
  });

  testWidgets('perubahan sesi membangun ulang kartu sesi, bukan kartu FCM', (
    tester,
  ) async {
    final push = FakePushTokenSource();
    final store = InMemoryTokenStore()
      ..access = 'mock-access-token-1234567890.sig'
      ..refresh = 'refresh:mhs@polinema.ac.id|1';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          pushTokenSourceProvider.overrideWithValue(push),
          topicSubscriptionProvider.overrideWithValue(FakeTopicSubscription()),
          deepLinkSourceProvider.overrideWithValue(FakeDeepLinkSource()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    sessionCardsBuildCount = 0;

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    await tester.runAsync(() async {
      container.read(authStateProvider.notifier).logout();
    });
    await tester.pumpAndSettle();

    expect(
      sessionCardsBuildCount,
      greaterThan(0),
      reason: 'sesi berubah, jadi kartu sesi memang harus dibangun ulang',
    );
  });

  testWidgets('select tidak menghemat rebuild pada authStateProvider', (
    tester,
  ) async {
    // Ini BUKAN test yang memastikan optimasi berhasil. Ini test yang mencatat
    // bahwa `select` pada `isLoading` tidak berguna di sini, supaya perubahan
    // itu tidak pernah ditulis sebagai "optimasi" di laporan.
    //
    // Alasannya: `login()` dan `logout()` sama-sama memulai dengan
    // `state = const AsyncLoading()`, lalu diakhiri `AsyncData`. Jadi
    // `isLoading` benar-benar berubah false -> true -> false, dan kedua rebuild
    // itu diperlukan.
    final selectCounter = _BuildCounter();
    await tester.pumpWidget(
      _app(_SelectWatcher(counter: selectCounter), InMemoryTokenStore()),
    );
    await tester.pumpAndSettle();
    final selectAwal = selectCounter.count;

    await _logout(tester, _SelectWatcher);
    final selectTambahan = selectCounter.count - selectAwal;

    final wholeCounter = _BuildCounter();
    await tester.pumpWidget(
      _app(_WholeStateWatcher(counter: wholeCounter), InMemoryTokenStore()),
    );
    await tester.pumpAndSettle();
    final wholeAwal = wholeCounter.count;

    await _logout(tester, _WholeStateWatcher);
    final wholeTambahan = wholeCounter.count - wholeAwal;

    expect(
      selectTambahan,
      wholeTambahan,
      reason:
          'jumlah rebuild sama, jadi select tidak menghemat apa pun di sini. '
          'Kalau angka ini berbeda, optimasi select layak dipertimbangkan.',
    );
    expect(selectTambahan, greaterThan(0));
  });
}

/// Menghitung berapa kali `build` dijalankan.
class _BuildCounter {
  int count = 0;
}

/// Widget yang hanya menonton `isLoading` lewat `select`.
class _SelectWatcher extends ConsumerWidget {
  const _SelectWatcher({required this.counter});

  final _BuildCounter counter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    counter.count++;
    final busy = ref.watch(authStateProvider.select((s) => s.isLoading));
    return Text(busy ? 'sibuk' : 'diam', textDirection: TextDirection.ltr);
  }
}

/// Pembanding: menonton seluruh `AsyncValue`, seperti versi tanpa `select`.
class _WholeStateWatcher extends ConsumerWidget {
  const _WholeStateWatcher({required this.counter});

  final _BuildCounter counter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    counter.count++;
    final busy = ref.watch(authStateProvider).isLoading;
    return Text(busy ? 'sibuk' : 'diam', textDirection: TextDirection.ltr);
  }
}

Widget _app(Widget child, InMemoryTokenStore store) => ProviderScope(
  overrides: [tokenStoreProvider.overrideWithValue(store)],
  child: MaterialApp(home: Scaffold(body: child)),
);

/// Menjalankan logout lewat notifier, yang memicu `invalidateSelf` sehingga
/// state auth berubah dan seluruh listener ikut diberi tahu.
Future<void> _logout(WidgetTester tester, Type watcher) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(watcher)),
  );
  await tester.runAsync(() async {
    container.read(authStateProvider.notifier).logout();
  });
  await tester.pumpAndSettle();
}
