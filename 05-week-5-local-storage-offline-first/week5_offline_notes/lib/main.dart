import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

void main() => runApp(const ProviderScope(child: OfflineNotesApp()));

class OfflineNotesApp extends StatelessWidget {
  const OfflineNotesApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Offline Notes',
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        // Routing berbasis URL (GoRouter) menggantikan `home:` langsung.
        routerConfig: router,
      );
}