/// Sisa jatah pemakaian AI pada akun.
///
/// Dipakai untuk menjawab pertanyaan yang paling sering muncul saat demo:
/// apakah request gagal karena kuota harian habis, atau karena penyedia sedang
/// penuh. Tanpa data ini, keduanya terlihat sama dari sisi aplikasi.
class AiQuota {
  const AiQuota({
    required this.isFreeTier,
    this.dailyUsed,
    this.dailyLimit,
    this.dailyRemaining,
    this.creditRemaining,
  });

  /// Benar bila akun belum pernah membeli kredit.
  ///
  /// Akun tanpa kredit dibatasi 50 request gratis per hari. Akun yang pernah
  /// membeli minimal 10 kredit mendapat 1000 per hari.
  final bool isFreeTier;

  /// Request gratis yang sudah terpakai hari ini.
  final int? dailyUsed;

  /// Batas request gratis per hari.
  final int? dailyLimit;

  /// Sisa request gratis hari ini.
  final int? dailyRemaining;

  /// Sisa saldo kredit. Negatif berarti akun tidak bisa memakai model gratis.
  final double? creditRemaining;

  bool get dailyExhausted => dailyRemaining != null && dailyRemaining! <= 0;

  bool get creditNegative => creditRemaining != null && creditRemaining! < 0;

  @override
  String toString() =>
      'AiQuota(freeTier: $isFreeTier, sisa: $dailyRemaining/$dailyLimit)';
}
