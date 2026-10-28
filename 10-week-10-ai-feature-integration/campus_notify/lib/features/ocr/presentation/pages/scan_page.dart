import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/failures.dart';
import '../../domain/entities/ai_quota.dart';
import '../providers/ocr_providers.dart';

/// Halaman pindai pengumuman.
///
/// Fitur ini sengaja dibingkai sebagai "pindai pengumuman", bukan "pindai
/// dokumen". Alasannya privasi: gambar dikirim ke penyedia AI di luar
/// aplikasi, jadi yang dipindai harus dokumen publik. KTM, rapor, dan surat
/// pribadi tidak boleh.
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final _picker = ImagePicker();
  Uint8List? _preview;

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      // Kompres di sisi aplikasi sebelum dikirim. Tanpa ini, foto kamera 12 MP
      // bisa 5 MB lebih dan langsung ditolak validasi ukuran.
      maxWidth: 1280,
      imageQuality: 60,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _preview = bytes);

    await ref
        .read(ocrControllerProvider.notifier)
        .scan(bytes: bytes, mimeType: _mimeOf(file));
  }

  /// `image_picker` tidak selalu mengisi `mimeType`, jadi ditebak dari ekstensi.
  String _mimeOf(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _openSettings() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _ApiKeyDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ocrControllerProvider);
    final hasKey = ref.watch(hasApiKeyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pindai Pengumuman'),
        actions: [
          IconButton(
            key: const Key('scan-settings'),
            tooltip: 'Pengaturan API key',
            onPressed: _openSettings,
            icon: const Icon(Icons.key_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasKey.value == false)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: const Text('API key belum diatur'),
                subtitle: const Text(
                  'Masukkan key OpenRouter lewat tombol kunci di kanan atas.',
                ),
                trailing: TextButton(
                  onPressed: _openSettings,
                  child: const Text('Atur'),
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cara pakai',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Foto papan pengumuman atau selebaran kampus, lalu teksnya '
                    'akan diekstrak. Jangan memindai KTM, rapor, atau dokumen '
                    'pribadi: gambar dikirim ke penyedia AI di luar aplikasi.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('scan-camera'),
                  onPressed: state.busy
                      ? null
                      : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('scan-gallery'),
                  onPressed: state.busy
                      ? null
                      : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeri'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('scan-check-quota'),
              onPressed: state.busy
                  ? null
                  : () => ref.invalidate(aiQuotaProvider),
              icon: const Icon(Icons.speed_outlined),
              label: const Text('Cek sisa kuota'),
            ),
          ),
          _QuotaCard(quota: ref.watch(aiQuotaProvider)),
          if (_preview != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _preview!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (state.busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(child: Text('Membaca teks...')),
          ],
          if (state.failure != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.failure!.message,
                            key: const Key('scan-error-message'),
                          ),
                        ),
                      ],
                    ),
                    // Saran dari penyedia ditampilkan terpisah, karena isinya
                    // berbeda-beda: kadang soal kuota, kadang soal kapasitas.
                    if (state.failure is AiFailure) ...[
                      if ((state.failure! as AiFailure).retryAfterSeconds !=
                          null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Coba lagi dalam '
                          '${(state.failure! as AiFailure).retryAfterSeconds} detik.',
                          key: const Key('scan-error-retry'),
                        ),
                      ],
                      if ((state.failure! as AiFailure).hint != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          (state.failure! as AiFailure).hint!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (state.result != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Hasil',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          key: const Key('scan-copy'),
                          tooltip: 'Salin teks',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: state.result!.text),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Teks disalin')),
                            );
                          },
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ],
                    ),
                    if (state.result!.truncated)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Teks dipotong karena terlalu panjang.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    SelectableText(
                      state.result!.text,
                      key: const Key('scan-result-text'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Model: ${state.result!.model}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog pengaturan API key.
///
/// Key ditulis ke secure storage lalu dialog langsung ditutup. Key tidak
/// ditampilkan kembali, tidak di-log, dan tidak disimpan di state widget.
class _ApiKeyDialog extends ConsumerStatefulWidget {
  const _ApiKeyDialog();

  @override
  ConsumerState<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends ConsumerState<_ApiKeyDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API key OpenRouter'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Key disimpan di penyimpanan aman perangkat dan tidak pernah '
            'dikirim ke mana pun selain OpenRouter.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('scan-api-key-field'),
            controller: _controller,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'sk-or-...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await ref.read(apiKeyStoreProvider).clear();
            ref.invalidate(hasApiKeyProvider);
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Hapus'),
        ),
        FilledButton(
          key: const Key('scan-api-key-save'),
          onPressed: () async {
            await ref.read(apiKeyStoreProvider).save(_controller.text);
            ref.invalidate(hasApiKeyProvider);
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Kartu ringkasan sisa kuota.
///
/// Ditampilkan hanya setelah pengguna menekan tombol cek kuota, supaya tidak
/// ada request tambahan setiap kali halaman dibuka.
class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.quota});

  final AsyncValue<({AiQuota? quota, Failure? failure})> quota;

  @override
  Widget build(BuildContext context) {
    return quota.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (value) {
        if (value.quota == null && value.failure == null) {
          return const SizedBox.shrink();
        }

        final failure = value.failure;
        if (failure != null) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(failure.message),
            ),
          );
        }

        final q = value.quota!;
        final sisa = q.dailyRemaining == null
            ? 'tidak diketahui'
            : '${q.dailyRemaining} dari ${q.dailyLimit ?? '?'}';

        return Card(
          key: const Key('scan-quota-card'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sisa kuota hari ini',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text('Request gratis: $sisa'),
                if (q.creditRemaining != null)
                  Text(
                    'Sisa saldo: \$${q.creditRemaining!.toStringAsFixed(2)}',
                  ),
                if (q.dailyExhausted) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Kuota harian habis. Kuota diperbarui 00.00 UTC '
                    '(sekitar 07.00 WIB).',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (q.creditNegative) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Saldo akun negatif. Model gratis ikut ditolak sampai '
                    'saldo diisi.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
