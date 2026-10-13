/// Fungsi-fungsi murni untuk formatting dan parsing.
///
/// Semua yang di sini tadinya berada di dalam widget (`home_page.dart`
/// `_formatTime` dan `_emailFromRefresh`) atau di `data/auth_repository.dart`
/// (`maskToken`). Dipindah ke sini supaya bisa diuji dengan `test()` biasa —
/// tanpa `pumpWidget`, tanpa `BuildContext`.
///
/// Tidak ada satupun fungsi di file ini yang mengimpor Flutter atau package
/// apa pun. Kalau suatu saat butuh `intl` atau `DateFormat`, aturan grep
/// sterilitas `domain`/`core` akan menangkapnya — dan itu memang harus:
/// pemformatan tanggal berlocale layak berada di lapisan `presentation`.
///
/// ## Apakah ini over-engineering?
///
/// Tiga fungsi, nol dependensi, nol state. Justru sebaliknya: tanpa file ini,
/// `formatClock` hanya bisa diuji lewat `testWidgets` yang harus memompa
/// `HomePage`, memanggil `initState`, lalu menunggu plugin Firebase. Biaya
/// test-nya naik dua orde besaran untuk satu baris `padLeft`.
library;

// ---------------------------------------------------------------- formatting

/// Memotong token agar aman ditampilkan di kartu debug dan aman masuk
/// screenshot laporan.
///
/// Token hanya boleh tampil 12 karakter pertama. Kalau aturan ini diabaikan
/// saja, siapa pun yang memegang screenshot laporan memegang tiket akses.
String maskToken(String? token, {int visible = 12}) {
  if (token == null || token.isEmpty) return '(kosong)';
  if (token.length <= visible) return '$token...';
  return '${token.substring(0, visible)}...';
}

/// Format waktu menjadi `HH:MM:SS`.
///
/// Dibangun manual dengan [padLeft], bukan `intl`. Alasannya bukan sekadar
/// menghindari dependency: `HH:MM:SS` adalah format debug yang dipakai kartu
/// debug token, sementara `intl` masuk akal justru di `presentation`.
String formatClock(DateTime? time) {
  if (time == null) return '-';
  return '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}';
}

/// Format tanggal lengkap `DD MMM YYYY` untuk ditampilkan ke pengguna.
String formatDate(DateTime? time) {
  if (time == null) return '-';
  return '${_two(time.day)} ${_months[time.month - 1]} ${time.year}';
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _two(int n) => n.toString().padLeft(2, '0');

// ------------------------------------------------------------------- parsing

/// Prefix refresh token mock `refresh:<email>|<timestamp>`.
const _refreshPrefix = 'refresh:';

/// Mengambil email dari refresh token mock.
///
/// Backend sungguhan akan mengembalikan profil lewat `GET /me`; ini hanya
/// untuk accommodate mock Week 6. Mengembalikan `null` — bukan melempar —
/// kalau formatnya tidak dikenali, supaya satu token aneh tidak menjatuhkan
/// seluruh kartu debug.
String? emailFromRefresh(String? refresh) {
  if (refresh == null || !refresh.startsWith(_refreshPrefix)) return null;
  final email = refresh.substring(_refreshPrefix.length).split('|').first;
  // `refresh:` tanpa isi menghasilkan string kosong, dan string kosong bukan
  // email yang valid. Tanpa pengecekan ini, kartu debug menampilkan baris
  // kosong, bukan tanpa isi sama sekali.
  return email.isEmpty ? null : email;
}
