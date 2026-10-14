import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/announcements/presentation/pages/announcement_page.dart';
import 'features/announcements/presentation/pages/home_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/notifications/data/firebase_push_repository.dart';
import 'features/notifications/presentation/providers/push_providers.dart';
import 'routes.dart';

/// Composition root: satu-satunya tempat yang tahu semua fitur sekaligus.
///
/// Yang TIDAK ada di sini: `Dio`, `FlutterSecureStorage`, atau instantiate
/// repository. Semua wiring ada di `features/*/presentation/providers/`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wajib sebelum runApp: seluruh plugin Firebase bergantung pada instance
  // default ini.
  await Firebase.initializeApp();

  // Android 10+ tidak mengirim broadcast ke app yang sudah terminated, sehingga
  // handler harus didaftarkan lebih awal. Harus fungsi top-level dengan
  // `@pragma('vm:entry-point')` karena berjalan di isolate terpisah.
  registerBackgroundHandler();

  runApp(const ProviderScope(child: CampusNotifyApp()));
}

/// Jembatan status auth Riverpod ke `refreshListenable` milik GoRouter,
/// sehingga guard dievaluasi ulang setiap kali sesi berubah tanpa perlu
/// membangun ulang router.
class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// Router dibuat satu kali lewat Provider (bukan `autoDispose`), sehingga
/// stack navigasi tetap utuh ketika status auth berubah.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();

  // `Ref.listen` milik provider tidak punya guard `debugDoingBuild`, berbeda
  // dengan `WidgetRef.listen` yang hanya boleh dipanggil di dalam build().
  ref.listen<AsyncValue<bool>>(authStateProvider, (_, _) => refresh.refresh());

  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authStateProvider).value ?? false;
      final goingLogin = state.matchedLocation == Routes.login;
      if (!loggedIn && !goingLogin) return Routes.login;
      if (loggedIn && goingLogin) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
      GoRoute(
        path: Routes.announcementPattern,
        builder: (_, state) =>
            AnnouncementPage(id: state.pathParameters['id'] ?? ''),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Rute tidak ditemukan: ${state.uri}')),
    ),
  );

  ref.onDispose(() {
    refresh.dispose();
    router.dispose();
  });

  return router;
});

class CampusNotifyApp extends ConsumerStatefulWidget {
  const CampusNotifyApp({super.key});

  @override
  ConsumerState<CampusNotifyApp> createState() => _CampusNotifyAppState();
}

class _CampusNotifyAppState extends ConsumerState<CampusNotifyApp> {
  late final GoRouter _router;
  StreamSubscription<String>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _router = ref.read(routerProvider);
    _initMessaging();
  }

  /// Inisialisasi messaging dilakukan setelah router siap supaya deep link
  /// dari notifikasi selalu punya tujuan.
  Future<void> _initMessaging() async {
    final push = ref.read(pushTokenSourceProvider);

    // Berlangganan dulu agar deep link yang tiba saat kasus terminated berjalan
    // tidak hilang.
    _deepLinkSub = ref.read(deepLinkSourceProvider).deepLinks.listen(_go);

    // Kegagalan messaging tidak boleh menjatuhkan aplikasi: di unit test plugin
    // Firebase memang tidak terdaftar, dan di produksi konfigurasi yang salah
    // harus tetap bisa membuka login.
    try {
      // Kasus terminated: aplikasi dibuka dari notifikasi. Harus SEBELUM
      // `initialize()` karena `getToken()` menunggu jaringan — kalau ditunda,
      // navigasi deep link tertahan sampai token selesai diambil.
      await push.handleTerminated();

      await push.initLocalNotifications();
      push.listenForeground();

      await push.initialize(
        onToken: (String _) async {
          await ref.read(registerDeviceProvider).call();
        },
      );
    } on Object catch (error) {
      debugPrint('[messaging] inisialisasi gagal: $error');
    }
  }

  void _go(String route) {
    if (!mounted) return;
    _router.go(route);
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);

    // Pasang bridge "daftar ulang token perangkat setelah login". Ditempel di
    // sini, di composition root, supaya fitur auth tidak perlu tahu bahwa fitur
    // notifikasi ada.
    ref.watch(deviceRegistrationOnLoginProvider);

    return MaterialApp.router(
      title: 'Campus Notify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F7DC9)),
      ),
      routerConfig: _router,
      builder: (context, child) {
        // Tutup halaman di balik splash selama status login dibaca dari secure
        // storage, supaya guard route tidak berkedip ke /login dulu.
        if (auth.isLoading && !auth.hasValue) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}