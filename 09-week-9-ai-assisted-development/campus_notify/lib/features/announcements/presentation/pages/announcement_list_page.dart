import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/failures.dart';
import '../../../../routes.dart';
import '../../domain/entities/announcement.dart';
import '../providers/announcement_providers.dart';

/// Halaman daftar pengumuman dengan pencarian.
///
/// Halaman ini hanya membaca state. Filter ada di `SearchAnnouncements.filter`
/// di lapisan domain, jadi tidak ada logika pencarian di sini.
class AnnouncementListPage extends ConsumerStatefulWidget {
  const AnnouncementListPage({super.key});

  @override
  ConsumerState<AnnouncementListPage> createState() =>
      _AnnouncementListPageState();
}

class _AnnouncementListPageState extends ConsumerState<AnnouncementListPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      body: Column(
        children: [
          _SearchField(
            controller: _controller,
            query: query,
            onChanged: (value) =>
                ref.read(searchQueryProvider.notifier).set(value),
            onClear: () {
              _controller.clear();
              ref.read(searchQueryProvider.notifier).clear();
            },
          ),
          Expanded(
            child: _ResultBody(state: state, query: query),
          ),
        ],
      ),
    );
  }
}

/// Kolom pencarian. Dipisah supaya `build()` halaman tetap pendek.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        key: const Key('search-field'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari pengumuman',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  key: const Key('search-clear'),
                  tooltip: 'Hapus',
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                ),
        ),
      ),
    );
  }
}

/// Isi daftar: loading, kegagalan, dua empty state, atau daftar.
class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.state, required this.query});

  final AsyncValue<({List<Announcement> announcements, Failure? failure})>
  state;
  final String query;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (result) {
        if (result.failure != null) {
          return _Message(
            icon: Icons.error_outline,
            text: result.failure!.message,
          );
        }

        if (result.announcements.isEmpty) {
          return _Message(
            key: const Key('search-empty'),
            icon: Icons.search_off,
            text: query.trim().isEmpty
                ? 'Belum ada pengumuman.'
                : 'Tidak ada pengumuman yang cocok dengan "${query.trim()}".',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: result.announcements.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _AnnouncementTile(item: result.announcements[index]),
        );
      },
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.item});

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: Key('announcement-${item.id}'),
        leading: const Icon(Icons.campaign_outlined),
        title: Text(item.title),
        subtitle: Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(Routes.announcementDetail(item.id)),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
