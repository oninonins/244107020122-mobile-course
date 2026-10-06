import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'messaging/push_service.dart';
import 'pages/announcement_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wajib sebelum runApp: seluruh plugin Firebase bergantung pada instance
  // default ini.
  await Firebase.initializeApp();

  // Android 10+ tidak mengirim broadcast ke app yang sudah terminated, sehingga
  // handler harus didaftarkan lebih awal.
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
/// stack navigasi tetap utuh ketika status auth berubah. Provider di-cache,
/// jadi `ref.watch` di bawah selalu mengembalikan instance yang sama.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();

  // `Ref.listen` milik provider tidak punya guard `debugDoingBuild`, berbeda
  // dengan `WidgetRef.listen` yang hanya boleh dipanggil di dalam build().
  ref.listen<AsyncValue<bool>>(
    authStateProvider,
    (_, _) => refresh.refresh(),
  );

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authStateProvider).value ?? false;
      final goingLogin = state.matchedLocation == '/login';
      if (!loggedIn && !goingLogin) return '/login';
      if (loggedIn && goingLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/pengumuman/:id',
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
    // Berlangganan dulu agar deep link yang tiba saat
    // `handleTerminated` berjalan tidak hilang.
    _deepLinkSub = deepLinkStream.listen(_go);

    // Kasus terminated: aplikasi dibuka dari notifikasi.
    //
    // Harus dipanggil SEBELUM `initFcmToken` karena `getToken()` menunggu
    // jaringan. Kalau ditunda, navigasi ke deep link tertahan sampai token
    // selesai diambil, dan gagal total saat jaringan sedang buruk.
    await handleTerminated();

    await initLocalNotifications();
    listenForeground();

    // Token diambil lalu dikirim ke backend lewat `onToken`. Endpoint
    // `POST /devices` dipanggil dari debug card di HomePage supaya
    // kegagalannya bisa diamati.
    await initFcmToken(onToken: (_) async {});
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
