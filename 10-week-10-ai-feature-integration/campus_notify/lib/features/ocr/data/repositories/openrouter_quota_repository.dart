import 'package:dio/dio.dart';

import '../../../../core/failures.dart';
import '../../domain/entities/ai_quota.dart';
import '../../domain/repositories/ai_quota_repository.dart';
import '../../domain/repositories/api_key_store.dart';

/// Membaca sisa kuota lewat `GET /api/v1/key`.
///
/// Endpoint ini dipakai untuk menjawab pertanyaan saat demo: apakah request
/// gagal karena kuota harian habis, atau karena penyedia sedang penuh. Tanpa
/// data ini, keduanya terlihat sama dari sisi aplikasi.
class OpenRouterQuotaRepository implements AiQuotaRepository {
  OpenRouterQuotaRepository({
    required this.dio,
    required this.keyStore,
    this.baseUrl = 'https://openrouter.ai/api/v1',
  });

  final Dio dio;
  final ApiKeyStore keyStore;
  final String baseUrl;

  @override
  Future<({AiQuota? quota, Failure? failure})> fetch() async {
    final apiKey = await keyStore.read();
    if (apiKey == null || apiKey.isEmpty) {
      return (
        quota: null,
        failure: const AiFailure(
          'API key belum diatur. Buka pengaturan lalu masukkan key OpenRouter.',
        ),
      );
    }

    try {
      final response = await dio.get<Map<String, Object?>>(
        '$baseUrl/key',
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );

      final quota = _parse(response.data);
      if (quota == null) {
        return (
          quota: null,
          failure: const AiFailure('Format data kuota tidak dikenali.'),
        );
      }
      return (quota: quota, failure: null);
    } on DioException catch (e) {
      // 401 di sini berarti key ditolak. Selain itu, pesan penyedia diteruskan.
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return (
          quota: null,
          failure: const AiFailure(
            'API key ditolak. Periksa kembali key OpenRouter di pengaturan.',
          ),
        );
      }
      return (
        quota: null,
        failure: AiFailure(
          'Gagal membaca kuota: ${status != null ? 'HTTP $status' : 'masalah jaringan'}',
        ),
      );
    }
  }

  AiQuota? _parse(Map<String, Object?>? body) {
    if (body == null) return null;
    final data = body['data'];
    if (data is! Map) return null;

    final daily = data['free_model_daily_requests'];
    final dailyMap = daily is Map ? daily : const <String, Object?>{};

    return AiQuota(
      isFreeTier: data['is_free_tier'] == true,
      dailyUsed: _asInt(dailyMap['used']),
      dailyLimit: _asInt(dailyMap['limit']),
      dailyRemaining: _asInt(dailyMap['remaining']),
      creditRemaining: _asDouble(data['limit_remaining']),
    );
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}

/// Membangun [AiQuotaRepository] lengkap dengan klien HTTP-nya.
///
/// Sama seperti [buildOcrRepository]: tujuannya supaya `Dio` tidak pernah dibuat
/// di presentation.
AiQuotaRepository buildQuotaRepository({required ApiKeyStore keyStore}) {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  return OpenRouterQuotaRepository(dio: dio, keyStore: keyStore);
}
