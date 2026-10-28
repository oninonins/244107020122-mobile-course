import '../../../../core/failures.dart';
import '../entities/ai_quota.dart';

/// Kontrak pemeriksaan sisa kuota akun AI.
///
/// Dipisah dari [OcrRepository] karena tujuannya berbeda: OCR memproses gambar,
/// ini hanya membaca status akun. Menggabungkannya akan melanggar Interface
/// Segregation, sama seperti yang dihindari di fitur notifications Week 7.
abstract interface class AiQuotaRepository {
  Future<({AiQuota? quota, Failure? failure})> fetch();
}
