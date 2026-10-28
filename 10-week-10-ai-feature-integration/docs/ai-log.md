# AI Log

Dokumen wajib Minggu 10: prompt sistem, user prompt, dan output awal AI.

| | |
|---|---|
| Fitur | Pindai Pengumuman (OCR) |
| Provider | OpenRouter |
| Model default | `google/gemma-4-31b-it:free` |
| Endpoint | `POST https://openrouter.ai/api/v1/chat/completions` |
| Suhu | `0` |

## System prompt

Dipakai apa adanya dari `ocrSystemPrompt` di
`lib/features/ocr/data/repositories/openrouter_ocr_repository.dart`.

```
Kamu alat OCR. Ekstrak semua teks yang terlihat pada gambar, apa adanya, tanpa
menambah penjelasan, tanpa markdown, tanpa komentar. Pertahankan urutan baris.
Jika tidak ada teks terbaca, balas dengan teks kosong. Jangan pernah menebak isi
yang tidak terlihat.
```

### Alasan setiap batasan

| Kalimat | Alasannya |
|---|---|
| "Kamu alat OCR" | Menetapkan persona, bukan asisten umum. Tanpa ini model menjawab "Gambar ini berisi pengumuman tentang..." |
| "apa adanya" | Mencegah model merapikan ejaan. Untuk OCR, teks asli lebih penting daripada teks yang enak dibaca |
| "tanpa penjelasan, tanpa markdown" | Output langsung ditampilkan dan disalin. Pembungkus markdown mengotori hasil |
| "Pertahankan urutan baris" | Pengumuman sering berupa daftar bernomor. Urutan yang berubah mengubah makna |
| "balas dengan teks kosong" | Memberi jalan keluar yang jelas. Tanpa ini model mengarang isi |
| "Jangan pernah menebak" | Kesalahan OCR yang dikarang lebih berbahaya daripada tidak ada hasil, karena pengguna tidak tahu itu salah |

## User prompt

```
Ekstrak seluruh teks pada gambar ini.
```

Sengaja satu baris. Instruksi rinci sudah ada di system prompt, dan mengulanginya
di user prompt membuat model kadang menjawab dengan komentar tentang instruksi.

## Bentuk permintaan

```json
{
  "model": "google/gemma-4-31b-it:free",
  "temperature": 0,
  "messages": [
    { "role": "system", "content": "<system prompt di atas>" },
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "Ekstrak seluruh teks pada gambar ini." },
        { "type": "image_url", "image_url": { "url": "data:image/jpeg;base64,<...>" } }
      ]
    }
  ]
}
```

Header:

```
Authorization: Bearer <API key pengguna>
Content-Type: application/json
HTTP-Referer: https://github.com/oninonins
X-OpenRouter-Title: Campus Notify
```

Key dikirim lewat header, bukan query string seperti contoh Gemini di codelab.
Alasannya: query string tercatat di log server, proxy, dan riwayat akses.

## Output awal AI

Dijalankan di perangkat Android nyata pada 29 Oktober 2026, pukul 00.34.

| Item | Keterangan |
|---|---|
| Gambar uji | Kartu tanda mahasiswa **fiktif** (nama dan NRP karangan, dibuat khusus untuk menguji akurasi pada teks padat) |
| Model default | `google/gemma-4-31b-it:free` |
| Model yang benar-benar menjawab | `nvidia/nemotron-3.5-super-vl:free` |
| Kuota saat uji | 50 dari 50 request gratis, saldo 50.00 USD |
| Biaya | 0, model gratis |

Model default **tidak** yang menjawab. OpenRouter memindah ke model kedua, dan
fallback bekerja seperti yang dirancang. Ini juga membuktikan field `model` pada
respons memang dibaca dan ditampilkan di UI.

### Teks hasil, apa adanya

```
www.stiki.ac.id
Sekolah Tinggi Informatika dan Komputer
Indonesia
Kartu Tanda Mahasiswa
Nama :
Cha Eun Woo
NRP :
212111029
Program Studi :
Desain Komunikasi Visual
Email :
212111029@mhs.stiki.ac.id
Masa berlaku kartu :
Agustus 2026
STIKI Keluarkan KTM Digital Untuk Semua
```

### Penilaian hasil

| Aspek | Hasil |
|---|---|
| Urutan baris | Dipertahankan, sesuai instruksi system prompt |
| Label dan nilai | Terpisah di baris sendiri (`Nama :` lalu `Cha Eun Woo`), bukan digabung |
| Markdown atau komentar | Tidak ada. Instruksi "tanpa penjelasan, tanpa markdown" dipatuhi |
| Teks yang salah | Tidak ditemukan pada blok teks utama |
| Baris tambahan | `STIKI Keluarkan KTM Digital Untuk Semua` berasal dari teks watermark kecil di sisi kanan kartu, bukan dari blok teks utama |
| Format tabel | Hilang. Hubungan label dan nilai harus dibaca dari urutan baris |

Baris terakhir menarik: teks itu tercetak sangat kecil dan berulang sebagai
watermark. Model tetap membacanya, dan hasilnya ditempatkan di akhir sesuai
posisinya. Itu bukan karangan, tetapi juga menunjukkan bahwa **model tidak
membedakan teks utama dari teks hiasan.** Untuk pengumuman, watermark jarang ada,
jadi risikonya kecil di kasus pemakaian sebenarnya.

### Catatan UX

Pemindaian berjalan tanpa perlu mengulang. Tidak ada 429 pada percobaan ini,
setelah fallback model ditambahkan. Sebelum fallback, percobaan pertama gagal
dengan 429 yang oleh versi awal kode disebut "kuota habis", padahal kuota saat
itu masih penuh. Itu yang memicu perbaikan pembacaan error di
`openrouter_ocr_repository.dart`.

### Kenapa KTM fiktif dipakai sebagai gambar uji

Bukan karena fitur ini untuk memindai KTM. Alasannya teknis: kartu identitas
punya kepadatan teks tinggi dengan campuran ukuran huruf, angka, dan teks kecil,
sehingga merupakan uji yang lebih berat daripada papan pengumuman biasa. Kalau
model berhasil pada teks sepadat itu, pengumuman cetak akan lebih mudah.

Datanya karangan: nama tokoh publik, NRP dan email dibuat-buat, dan tidak
merujuk ke orang sungguhan. Tidak ada data pribadi yang dikirim.

Perlu dinyatakan juga: **aplikasi tetap memperingatkan agar dokumen pribadi asli
tidak dipindai**, dan peringatan itu ada di halaman pindai. Gambar uji ini
dipilih untuk menguji batas kemampuan OCR, bukan untuk menyarankan pemakaian
tersebut.

## Variasi model yang tersedia (gratis, input gambar)

Diambil dari `GET /api/v1/models` pada 21 Oktober 2026:

| Model | Konteks |
|---|---|
| `google/gemma-4-31b-it:free` | 262144 |
| `google/gemma-4-26b-a4b-it:free` | 262144 |
| `nvidia/nemotron-3.5-super-vl:free` | 1000000 |
| `dots-studio/dots-3-note-preview:free` | 512000 |
| `thinkingmachines/inkling:free` | 1048576 |

Model bisa diganti lewat `ocrModelProvider` tanpa mengubah kode lain.

## Catatan tentang model gratis

Model `:free` punya batas laju dan kuota harian. Saat demo bisa muncul 429. Itu
ditangani sebagai `AiFailure` dengan `quotaExceeded: true`, dan UI menyarankan
menunggu lalu mencoba lagi. Kalau model gratis tidak tersedia sama sekali,
model bisa diganti dari daftar di atas.

---

## Diagnosa 429: kenapa pesan "kuota habis" bisa menyesatkan

Versi pertama kode memetakan **semua** 429 ke satu kalimat: "Batas pemakaian
model gratis tercapai". Itu tebakan, bukan bacaan. `error.message`,
`error.metadata`, `X-RateLimit-Remaining`, dan `Retry-After` semuanya dibuang.

Menurut dokumentasi OpenRouter, 429 datang dari dua tempat:

| Sumber | Arti | Penanda di respons |
|---|---|---|
| Batas platform | Kuota free model per menit atau per hari | Header `X-RateLimit-Remaining`, `X-RateLimit-Limit`, `X-RateLimit-Reset` |
| Provider upstream | Model sedang penuh di penyedia | Header `Retry-After`, dan `error.metadata.provider_code` |

Dua masalah itu butuh tindakan berbeda. Menyamakan pesannya membuat pengguna
menunggu kuota reset padahal masalahnya kapasitas provider, atau sebaliknya.

### Batas free model

| Kredit yang pernah dibeli | Request per menit | Request per hari |
|---|---|---|
| Kurang dari 10 | 20 | 50 |
| Minimal 10 | 20 | 1000 |

Akun yang belum pernah membeli kredit hanya mendapat **50 request gratis per
hari**, dihitung dalam UTC. Kuota diperbarui 00.00 UTC, sekitar 07.00 WIB.

### Perbaikan yang diterapkan

| Sebelum | Sesudah |
|---|---|
| Semua 429 dianggap kuota | Kuota hanya diklaim kalau `X-RateLimit-Remaining` bernilai `0` |
| Pesan penyedia dibuang | `error.message` diteruskan apa adanya |
| `Retry-After` diabaikan | Ditampilkan sebagai hitung mundur detik |
| `remedy_hint` diabaikan | Ditampilkan sebagai saran terpisah |
| 5xx ikut ditandai kuota | 5xx bukan kuota, `quotaExceeded` jadi false |

### Fallback model

Payload sekarang memakai `models`, bukan `model`:

```json
"models": [
  "google/gemma-4-31b-it:free",
  "nvidia/nemotron-3.5-super-vl:free",
  "dots-studio/dots-3-note-preview:free"
]
```

OpenRouter memindah otomatis saat model pertama rate-limited atau providernya
penuh. Semua entri `:free` dengan sengaja, karena dokumentasi memperingatkan
kalau daftar berisi model berbayar dan fallback ke sana, request jadi berbayar.
Model yang benar-benar menjawab dibaca dari field `model` di respons.

### Tombol cek kuota

Halaman pindai punya tombol **Cek sisa kuota** yang memanggil `GET /api/v1/key`
memakai key tersimpan. Yang ditampilkan:

- request gratis terpakai, batas, dan sisanya
- sisa saldo kredit
- peringatan kalau kuota harian habis
- peringatan kalau saldo negatif

Ini menjawab pertanyaan saat demo tanpa perlu membuka terminal.