import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = path == '/stats' ? 1 : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          context.go(index == 0 ? '/' : '/stats');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list),
            label: 'Daftar',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats),
            label: 'Statistik',
          ),
        ],
      ),
    );
  }
}