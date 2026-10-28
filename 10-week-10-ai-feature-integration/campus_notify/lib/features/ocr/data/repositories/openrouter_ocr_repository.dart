import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/failures.dart';
import '../../domain/entities/ocr_result.dart';
import '../../domain/repositories/api_key_store.dart';
import '../../domain/repositories/ocr_repository.dart';

/// Model vision gratis yang dipakai sebagai default.
///
/// Bisa diganti dari layar pengaturan karena model `:free` di OpenRouter bisa
/// berubah ketersediaannya. Slug disimpan di satu konstanta supaya penggantian
/// tidak perlu menyentuh kode lain.
const defaultOcrModel = 'google/gemma-4-31b-it:free';

/// Daftar cadangan saat model pertama sedang rate-limited atau providernya penuh.
///
/// Dikirim sebagai field `models`, bukan `model`, supaya OpenRouter memindah
/// otomatis ke model berikutnya. Dokumentasi menyebut fallback juga terpicu oleh
/// rate limit dan kapasitas provider.
///
/// Semuanya `:free` dengan sengaja. Dokumentasi memperingatkan: kalau daftar
/// berisi model berbayar dan fallback ke sana, request jadi berbayar. Karena itu
/// tidak ada satu pun slug berbayar di sini.
const freeVisionModels = <String>[
  'google/gemma-4-31b-it:free',
  'nvidia/nemotron-3.5-super-vl:free',
  'dots-studio/dots-3-note-preview:free',
];

/// Batas panjang teks yang dikembalikan.
///
/// Jawaban yang sangat panjang biasanya berarti model mengomentari gambar
/// daripada menyalin teksnya, dan hasil seperti itu tidak berguna untuk OCR.
const _maxChars = 8000;

/// System prompt. Ditaruh di satu tempat karena dipakai juga oleh
/// `docs/ai-log.md`.
const ocrSystemPrompt =
    'Kamu alat OCR. Ekstrak semua teks yang terlihat pada gambar, apa adanya, '
    'tanpa menambah penjelasan, tanpa markdown, tanpa komentar. '
    'Pertahankan urutan baris. Jika tidak ada teks terbaca, balas dengan '
    'teks kosong. Jangan pernah menebak isi yang tidak terlihat.';

/// Implementasi [OcrRepository] di atas OpenRouter chat completions.
///
/// API key dibaca dari [ApiKeyStore] setiap kali dipanggil, bukan disimpan di
/// field. Alasannya: pengguna bisa mengganti key dari layar pengaturan tanpa
/// aplikasi perlu di-restart.
class OpenRouterOcrRepository implements OcrRepository {
  OpenRouterOcrRepository({
    required this.dio,
    required this.keyStore,
    this.model = defaultOcrModel,
    this.baseUrl = 'https://openrouter.ai/api/v1',
  });

  final Dio dio;
  final ApiKeyStore keyStore;
  final String model;
  final String baseUrl;

  /// Model yang dicoba berurutan: model pilihan pengguna dulu, lalu cadangan.
  ///
  /// Duplikat dibuang supaya model pilihan tidak dikirim dua kali.
  List<String> get modelsToTry => [
    model,
    ...freeVisionModels.where((m) => m != model),
  ];

  @override
  Future<({OcrResult? result, Failure? failure})> extractText({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final apiKey = await keyStore.read();
    if (apiKey == null || apiKey.isEmpty) {
      return (
        result: null,
        failure: const AiFailure(
          'API key belum diatur. Buka pengaturan lalu masukkan key OpenRouter.',
        ),
      );
    }

    final dataUri = 'data:$mimeType;base64,${base64Encode(imageBytes)}';

    try {
      final response = await dio.post<Map<String, Object?>>(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            // Key dikirim lewat header, tidak lewat query string, supaya tidak
            // ikut tercatat di log server maupun proxy.
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            // Dua header ini opsional, dipakai OpenRouter untuk atribusi.
            'HTTP-Referer': 'https://github.com/oninonins',
            'X-OpenRouter-Title': 'Campus Notify',
          },
        ),
        data: {
          // `models`, bukan `model`: OpenRouter memindah otomatis ke model
          // berikutnya kalau yang pertama rate-limited atau providernya penuh.
          'models': modelsToTry,
          'messages': [
            {'role': 'system', 'content': ocrSystemPrompt},
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Ekstrak seluruh teks pada gambar ini.',
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': dataUri},
                },
              ],
            },
          ],
          // Menekan variasi jawaban. OCR butuh hasil yang sama untuk gambar
          // yang sama, bukan jawaban kreatif.
          'temperature': 0,
        },
      );

      return _parse(response.data);
    } on DioException catch (e) {
      return (result: null, failure: _mapDioFailure(e));
    } on Object catch (e) {
      return (
        result: null,
        failure: AiFailure('Gagal memproses gambar: ${_safeMessage(e)}'),
      );
    }
  }

  ({OcrResult? result, Failure? failure}) _parse(Map<String, Object?>? body) {
    if (body == null) {
      return (
        result: null,
        failure: const AiFailure('Jawaban AI kosong. Coba lagi.'),
      );
    }

    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      return (
        result: null,
        failure: const AiFailure('AI tidak mengembalikan hasil. Coba lagi.'),
      );
    }

    final first = choices.first;
    if (first is! Map) {
      return (
        result: null,
        failure: const AiFailure('Format jawaban AI tidak dikenali.'),
      );
    }

    final message = first['message'];
    final content = message is Map ? message['content'] : null;

    // Sebagian penyedia mengembalikan content sebagai daftar bagian, bukan
    // string tunggal. Keduanya ditangani supaya tidak pecah di model lain.
    final raw = switch (content) {
      String s => s,
      List parts =>
        parts
            .whereType<Map>()
            .map((p) => p['text'])
            .whereType<String>()
            .join('\n'),
      _ => '',
    };

    final text = raw.trim();
    if (text.isEmpty) {
      return (
        result: null,
        failure: const AiFailure(
          'Tidak ada teks yang terbaca. Coba foto lebih dekat dan lebih terang.',
        ),
      );
    }

    final truncated = text.length > _maxChars;
    final modelName = (body['model'] as String?) ?? model;

    return (
      result: OcrResult(
        text: truncated ? text.substring(0, _maxChars) : text,
        model: modelName,
        truncated: truncated,
      ),
      failure: null,
    );
  }

  /// Memetakan kegagalan HTTP ke [Failure] dengan membaca alasan asli.
  ///
  /// Versi pertama fungsi ini membuang `error.message` dan semua header, lalu
  /// menampilkan satu kalimat yang sama untuk semua 429. Akibatnya aplikasi
  /// menebak, dan pengguna mendapat saran yang salah ketika masalahnya bukan
  /// kuota. Sekarang alasan penyedia dibaca dan diteruskan apa adanya.
  Failure _mapDioFailure(DioException e) {
    final response = e.response;
    if (response == null || response.statusCode == null) {
      return AiFailure('Permintaan ke AI gagal: ${_describe(e)}');
    }
    final status = response.statusCode!;

    final providerMessage = _providerMessage(response.data);
    final remedyHint = _providerMetadata(response.data, 'remedy_hint');
    final providerCode = _providerMetadata(response.data, 'provider_code');
    final retryAfter = _retryAfterSeconds(response.headers);
    final rateLimitRemaining = response.headers.value('x-ratelimit-remaining');

    return switch (status) {
      401 || 403 => AiFailure(
        providerMessage ??
            'API key ditolak. Periksa kembali key OpenRouter di pengaturan.',
        hint: remedyHint,
      ),
      402 => AiFailure(
        providerMessage ?? 'Kredit OpenRouter tidak cukup. Gunakan model gratis atau isi ulang.',
        hint: remedyHint,
      ),
      429 => _rateLimitFailure(
        providerMessage: providerMessage,
        remedyHint: remedyHint,
        providerCode: providerCode,
        retryAfter: retryAfter,
        rateLimitRemaining: rateLimitRemaining,
      ),
      >= 500 => AiFailure(
        providerMessage ?? 'Layanan AI sedang bermasalah. Coba lagi nanti.',
        hint: remedyHint,
      ),
      _ => AiFailure(
        providerMessage ?? 'Permintaan ke AI gagal: ${_describe(e)}',
        hint: remedyHint,
      ),
    };
  }

  /// Membedakan dua sumber 429 menurut dokumentasi OpenRouter.
  ///
  /// 1. Batas platform: kuota free model per hari atau per menit. Responsnya
  ///    membawa header `X-RateLimit-*`.
  /// 2. Kapasitas provider upstream: model sedang penuh. Responsnya membawa
  ///    `Retry-After` dan `error.metadata.provider_code`.
  ///
  /// Keduanya butuh tindakan berbeda, jadi pesannya tidak boleh disamakan.
  Failure _rateLimitFailure({
    required String? providerMessage,
    required String? remedyHint,
    required String? providerCode,
    required int? retryAfter,
    required String? rateLimitRemaining,
  }) {
    final exhausted = rateLimitRemaining != null && rateLimitRemaining == '0';

    if (exhausted) {
      // Batas platform. Pesan utama dalam Bahasa Indonesia karena ini tindakan
      // yang harus diambil pengguna. Pesan asli penyedia tetap diteruskan
      // sebagai petunjuk, supaya tidak ada informasi yang hilang.
      return AiFailure(
        'Kuota harian model gratis sudah habis. Kuota diperbarui 00.00 UTC '
        '(sekitar 07.00 WIB).',
        quotaExceeded: true,
        hint: remedyHint ?? providerMessage,
        retryAfterSeconds: retryAfter,
      );
    }

    // Tanpa bukti kuota, jangan mengaku kuota. Versi pertama fungsi ini
    // menampilkan "batas pemakaian tercapai" untuk semua 429, padahal alasan
    // sebenarnya bisa "tidak ada provider yang cocok dengan kebijakan data".
    // Pengguna jadi menunggu sia-sia padahal masalahnya lain.
    return AiFailure(
      providerMessage ??
          'Batas pemakaian AI tercapai. Coba lagi beberapa saat lagi.',
      quotaExceeded: false,
      hint:
          remedyHint ??
          (providerCode == null ? null : 'Kode penyedia: $providerCode'),
      retryAfterSeconds: retryAfter,
    );
  }

  /// Mengambil `error.message` dari body respons.
  ///
  /// Body bisa berbentuk Map (Dio sudah mem-parse JSON) atau String mentah.
  /// Keduanya ditangani, karena sebagian error tidak membawa content-type JSON.
  String? _providerMessage(Object? body) {
    if (body is Map) {
      final error = body['error'];
      if (error is Map) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
      final message = body['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    }
    if (body is String && body.trim().isNotEmpty && body.length < 300) {
      return body.trim();
    }
    return null;
  }

  /// Mengambil satu field dari `error.metadata`.
  String? _providerMetadata(Object? body, String key) {
    if (body is! Map) return null;
    final error = body['error'];
    if (error is! Map) return null;
    final metadata = error['metadata'];
    if (metadata is! Map) return null;
    final value = metadata[key];
    return value == null ? null : '$value';
  }

  /// Membaca `Retry-After` dalam detik.
  ///
  /// Header ini boleh berisi angka detik atau tanggal HTTP. Bentuk tanggal
  /// diabaikan karena menghitung selisihnya tidak berguna untuk pesan singkat.
  int? _retryAfterSeconds(Headers? headers) {
    final raw = headers?.value('retry-after');
    if (raw == null) return null;
    return int.tryParse(raw.trim());
  }

  /// Pesan singkat yang tidak pernah memuat header permintaan.
  ///
  /// Penting: `DioException.toString()` bisa memuat `requestOptions.headers`,
  /// dan di situlah `Authorization: Bearer <key>` berada. Karena itu pesan
  /// disusun dari status dan tipe saja, bukan dari objek exception.
  String _describe(DioException e) {
    final status = e.response?.statusCode;
    if (status != null) return 'HTTP $status';
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => 'koneksi lambat',
      DioExceptionType.connectionError => 'tidak ada koneksi',
      DioExceptionType.badCertificate => 'sertifikat tidak valid',
      DioExceptionType.cancel => 'permintaan dibatalkan',
      DioExceptionType.badResponse ||
      DioExceptionType.unknown => 'masalah jaringan',
    };
  }

  String _safeMessage(Object error) {
    // Sengaja tidak memakai `error.toString()` untuk objek Dio, karena bisa
    // memuat header. Selain Dio, tipe yang sampai ke sini hanya error parsing.
    if (error is FormatException) return 'format jawaban tidak dikenali';
    return 'kesalahan tak terduga';
  }
}

/// Membangun [OcrRepository] lengkap dengan klien HTTP-nya.
///
/// Dipanggil dari `presentation/providers/ocr_providers.dart`. Fungsi ini ada
/// supaya `Dio` tidak pernah dibuat di presentation: grep sterilitas Week 7
/// mensyaratkan folder `presentation` bebas `Dio(`, dan aturan itu tetap
/// berlaku untuk fitur baru.
OcrRepository buildOcrRepository({
  required ApiKeyStore keyStore,
  required String model,
}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  return OpenRouterOcrRepository(dio: dio, keyStore: keyStore, model: model);
}
