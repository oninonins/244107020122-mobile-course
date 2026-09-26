Hasil Praktikum Minggu 5

![Praktikum](screenshots/praktikum.jpeg)

Keterangan: angka jumlah catatan yang disinkronkan tetap 0 dan tidak berubah. Belum ada catatan bertanda dirty, sehingga countDirty mengembalikan 0 dan syncNotes langsung keluar dengan hasil 0 tanpa menandai apapun, maka angka pada tampilan tidak berubah.


AI Challenge

Aplikasi Flutter Offline Notes: CRUD catatan + preferensi tema.
Bandingkan SharedPreferences, Hive, sqflite (SQLite), dan Drift
untuk dua kebutuhan ini. Requirements:
- Kriteria: kompleksitas query, kebutuhan relasi, reaktivitas (stream),
  type-safety, ukuran boilerplate, dan kemudahan testing.
- Beri rekomendasi final: mana untuk preferensi, mana untuk catatan,
  beserta alasannya dalam 1 tabel.
- Tunjukkan skema tabel/kotak untuk 1000+ catatan.
Jelaskan trade-off setiap pilihan.


Jawaban

Konteks: preferensi tema (satu nilai kecil) dan CRUD ribuan catatan.

Perbandingan kriteria

| Kriteria | SharedPreferences | Hive | sqflite (SQLite) | Drift |
|---|---|---|---|---|
| Kompleksitas query | tidak ada (get/set kunci) | sangat sederhana (baca seluruh box lalu filter manual) | SQL penuh (WHERE, JOIN, ORDER, LIMIT) | SQL atau query builder type-safe |
| Kebutuhan relasi | tidak ada | tidak ada | ya (FOREIGN KEY dan JOIN) | ya (FK dan relasi otomatis) |
| Reaktivitas (stream) | tidak ada | ada, box.watch() per key | tidak bawaan, harus re-query manual | watch() bawaan per query |
| Type-safety | rendah (dynamic) | rendah, type adapter opsional | rendah (Map dynamic) | tinggi, kelas hasil dari codegen |
| Ukuran boilerplate | paling kecil | kecil sampai medium (adapter tipe custom) | medium (string SQL plus mapping manual) | besar di setup (build_runner), kecil per fitur sesudahnya |
| Kemudahan testing | mudah, mock SharedPreferences | mudah, box di folder temp atau in-memory | mudah sampai medium, sqflite_common_ffi untuk in-memory | mudah, NativeDatabase.memory |

Rekomendasi final

| Kebutuhan | Pilihan | Alasan |
|---|---|---|
| Preferensi tema | SharedPreferences | Satu nilai boolean berkunci tetap, tanpa query, relasi, maupun stream. API sinkron paling sederhana, nol dependency, paling hemat untuk data konfigurasi kecil. |
| 1000+ catatan (CRUD) | sqflite (SQLite) | Butuh query nyata: cari, urut berdasarkan waktu, filter, transaksi, dan indeks. SQLite matang tanpa tambahan codegen. Drift layak dinaikkan bila nanti butuh reaktivitas dan type-safety bawaan. |

Trade-off setiap pilihan

- SharedPreferences untuk catatan tidak cocok karena tidak ada query maupun indeks. Memuat 1000+ catatan berarti deserialisasi seluruh file, tidak efisien dan sulit dipaginasi.
- Hive sangat cepat untuk nilai tunggal tetapi tanpa query berarti seluruh list dimuat dan difilter manual di memori. Ekosistem Hive v2 praktis usang (pengembang aslinya pindah ke Isar), sehingga berisiko sebagai fondasi data utama.
- sqflite tidak reaktif, mapping manual, dan type-safety rendah. Kelebihannya SQL penuh, dependency ringan, dan sudah terpakai di proyek ini sehingga cukup untuk offline-first.
- Drift terbaik untuk type-safety, stream, dan relasi tanpa string SQL yang rentan salah, tetapi menambah build_runner dan kurva belajar. Berlebihan untuk penyimpanan satu boolean tema.

Skema untuk 1000+ catatan

```sql
CREATE TABLE notes (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  title      TEXT    NOT NULL,
  body       TEXT    NOT NULL DEFAULT '',
  updated_at INTEGER NOT NULL,                 -- epoch millis, ringkas dan bisa range scan
  dirty      INTEGER NOT NULL DEFAULT 0,       -- 0/1 untuk sinkronisasi offline
  is_pinned  INTEGER NOT NULL DEFAULT 0
);

-- Indeks untuk sorting dan filter umum (daftar rumah, sync, pin)
CREATE INDEX idx_notes_updated ON notes (updated_at DESC);
CREATE INDEX idx_notes_pinned_dirty ON notes (is_pinned, dirty);

-- Opsional relasi one-to-many (tag) dengan FK dan JOIN
CREATE TABLE tags (
  id   INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);
CREATE TABLE note_tags (
  note_id INTEGER NOT NULL REFERENCES notes (id) ON DELETE CASCADE,
  tag_id  INTEGER NOT NULL REFERENCES tags (id)  ON DELETE CASCADE,
  PRIMARY KEY (note_id, tag_id)
);

-- Opsional pencarian teks cepat (FTS5) untuk ribuan catatan
CREATE VIRTUAL TABLE notes_fts USING fts5(
  title, body, content=notes, content_rowid=id
);
```

Catatan: proyek ini menyimpan updated_at sebagai TEXT ISO8601 via DateTime.toIso8601String. Untuk skala 1000+ sebaiknya INTEGER epoch millis karena lebih ringkas dan bisa dibandingkan numerik langsung di SQL.








AI Verification Checklist
Sebelum rekomendasi AI diterima, verifikasi dan catat temuan Anda di README:

Apakah AI menempatkan daftar catatan di SharedPreferences? (menolak: rapuh untuk koleksi).
Apakah skema AI mendukung antrean sync (dirty flag / updated_at) atau hanya CRUD polos?
Apakah klaim "real-time" AI didukung stream (Drift/watch) atau hanya asumsi?
Apakah estimasi boilerplate AI masuk akal setelah Anda mencoba instalasinya (flutter pub add + migrasi skema)?
Keputusan final Anda beserta alasannya, boleh berbeda dari rekomendasi AI selama berargumen.


Hasil verifikasi

1. AI tidak menempatkan daftar catatan di SharedPreferences. Lulus. Rekomendasi hanya menaruh boolean tema di SharedPreferences dan menolak SharedPreferences untuk koleksi karena tidak ada query maupun indeks, sehingga rapuh untuk daftar besar.
2. Skema AI mendukung antrean sync. Lulus. Skema menyertakan kolom dirty dan updated_at plus indeks, bukan CRUD polos. Konsisten dengan implementasi aktual di note_repository.dart (countDirty, markAllSynced, dan addNote yang menyetel dirty true).
3. Klaim stream pada Drift dan Hive didukung dokumentasi API resmi, bukan hasil uji lokal karena package tersebut belum diinstal di proyek. Aplikasi saat ini tidak memakai stream sama sekali, refresh cache-first memakai background fetch lalu ref.invalidateSelf di providers.dart.
4. Estimasi boilerplate belum diverifikasi dengan instalasi nyata. Berdasarkan pengalaman umum, setup Drift membutuhkan build_runner dan codegen, sedangkan sqflite menuntut mapping manual dengan string SQL. Secara kualitatif masuk akal, tetapi tidak diuji dengan flutter pub add maupun migrasi skema di proyek ini.

Keputusan final: tetap memakai sqflite untuk catatan dan SharedPreferences untuk preferensi. Alasannya proyek offline-first tidak membutuhkan stream dan cukup dengan refresh manual, dan sqflite sudah terinstal sehingga tidak menambah codegen.