import 'package:campus_notify/data/auth_repository.dart';
import 'package:campus_notify/data/token_store.dart';
import 'package:campus_notify/main.dart';
import 'package:campus_notify/providers/auth_provider.dart';
import 'package:campus_notify/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mengganti `InMemoryTokenStore` supaya guard route dan alur login bisa diuji
/// tanpa Keychain/Keystore sungguhan.
Widget _app(TokenStore store) => ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      ],
      child: const CampusNotifyApp(),
    );

void main() {
  testWidgets('guard route mengarahkan tamu ke /login', (tester) async {
    await tester.pumpWidget(_app(InMemoryTokenStore()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(find.byKey(const Key('home-logout')), findsNothing);
  });

  testWidgets('validasi form menahan login yang tidak sah', (tester) async {
    await tester.pumpWidget(_app(InMemoryTokenStore()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login-email')), 'bukan-email');
    await tester.enterText(find.byKey(const Key('login-password')), '123');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();

    expect(find.text('Format email tidak valid'), findsOneWidget);
    expect(find.text('Minimal 6 karakter'), findsOneWidget);
  });

  testWidgets('login valid menyimpan token dan masuk ke home', (tester) async {
    final store = InMemoryTokenStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'mhs@polinema.ac.id',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'rahasia123');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-logout')), findsOneWidget);
    expect(await store.readAccess(), isNotNull);
    expect(await store.readRefresh(), isNotNull);
  });

  testWidgets('debug token tidak pernah menampilkan token penuh', (tester) async {
    final store = InMemoryTokenStore();
    await store.save(
      access: 'mock-access-token-1234567890.sig',
      refresh: 'refresh:mhs@polinema.ac.id|1',
    );

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // Hanya 12 karakter pertama yang boleh tampil.
    expect(find.text('mock-access-...'), findsOneWidget);
    expect(find.textContaining('mock-access-token-1234567890'), findsNothing);
  });

  testWidgets('kartu pengumuman membuka /pengumuman/:id', (tester) async {
    final store = InMemoryTokenStore();
    await store.save(access: 'a', refresh: 'refresh:mhs@polinema.ac.id|1');

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // Kartu pengumuman berada di bawah kartu debug FCM, jadi harus digulir dulu.
await tester.scrollUntilVisible(
      find.byKey(const Key('home-announcement')),
      200,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-announcement')));
    await tester.pumpAndSettle();

    expect(find.text('Pengumuman #3'), findsOneWidget);
  });

  testWidgets('logout menghapus token dan kembali ke /login', (tester) async {
    final store = InMemoryTokenStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'mhs@polinema.ac.id',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'rahasia123');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-logout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(await store.readAccess(), isNull);
    expect(Routes.login, '/login');
  });
}