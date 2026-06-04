# Rencana Implementasi Flutter VLC Player

> Versi lengkap — termasuk thumbnail, history, gesture, background audio, dan media_kit

---

## Dependencies (`pubspec.yaml`)

| Package | Keterangan |
|---|---|
| `media_kit` *(ganti VLC)* | Playback modern, aktif dikembangkan, support semua platform |
| `file_picker ^8.0.0` | System file picker bawaan OS |
| `permission_handler` | Minta izin storage runtime |
| `path_provider ^2.1.0` | Path direktori device yang aman |
| `video_thumbnail` 🆕 | Generate thumbnail dari file video lokal |
| `audio_service` 🆕 | Background audio + notifikasi media |
| `audio_session` 🆕 | Manajemen sesi audio OS |
| `shared_preferences` | Simpan history & cache scan |
| `provider ^6.1.0` | State management |
| `sqflite` 🆕 | Database lokal untuk index media |

---

## Struktur Folder

```
lib/
├── main.dart                    — setup audio_service & provider
│
├── screens/
│   ├── home_screen.dart         — tab: file saya, browser, recents
│   ├── file_browser_screen.dart
│   ├── player_screen.dart
│   └── history_screen.dart      🆕
│
├── widgets/
│   ├── player_controls.dart     — incl. gesture overlay
│   ├── gesture_overlay.dart     🆕
│   ├── equalizer_panel.dart
│   ├── playlist_panel.dart
│   └── media_tile.dart          — list item + thumbnail
│
├── providers/
│   ├── player_provider.dart
│   ├── playlist_provider.dart
│   ├── file_browser_provider.dart
│   └── history_provider.dart    🆕
│
├── services/                    🆕
│   ├── audio_handler.dart       — background playback service
│   └── media_indexer.dart       — scan + simpan ke SQLite
│
└── utils/
    ├── storage_helper.dart      — scan storage aman
    └── thumbnail_helper.dart    🆕
```

---

## Tahapan Pengerjaan

### Phase 1 — Izin & Akses Storage
*Manifest + runtime permission handler*

- Tambahkan `READ_EXTERNAL_STORAGE`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` di `AndroidManifest`
- Tambahkan `requestLegacyExternalStorage` untuk Android 10–12
- Minta izin runtime via `permission_handler` saat app pertama dibuka
- Tangani kasus user menolak izin — tampilkan dialog penjelasan dan fallback ke file picker

---

### Phase 2 — Scan & Indexing Media
*Scan cepat + cache SQLite agar tidak lambat*

- Gunakan `getExternalStorageDirectories()` dari `path_provider` — lebih aman dari hardcoded path
- Scan rekursif lalu simpan hasil ke SQLite via `media_indexer.dart`
- Pada buka app berikutnya, baca dari DB dulu — scan ulang hanya jika ada file baru (bandingkan modified date)
- Jalankan scan di background isolate agar UI tidak freeze ✦ *baru*

---

### Phase 3 — Thumbnail Video ✦
*Tampilan daftar lebih menarik dengan preview frame*

- Gunakan package `video_thumbnail` untuk generate frame pertama tiap video
- Simpan thumbnail ke cache dir (`getTemporaryDirectory()`) agar tidak digenerate ulang
- Tampilkan di `media_tile.dart` — lazy load hanya saat ListTile terlihat di viewport
- Fallback icon `Icons.movie` jika generate gagal (file corrupt / audio)

---

### Phase 4 — File Browser & File Picker
*Dua cara membuka file — browser manual & system picker*

- **Tab "File saya"** — daftar semua media dari hasil scan, dikelompokkan per folder
- **Tab "Browser"** — jelajah folder bebas, tap folder masuk, tap file langsung putar
- **Tombol "Buka"** — system file picker via `FilePicker.platform.pickFiles()`
- Support multi-select di browser untuk menambah beberapa file ke playlist sekaligus

---

### Phase 5 — Player & Gesture Control ✦
*Kontrol sentuh standar media player modern*

- Putar dari path lokal via `media_kit` — lebih stabil dari `flutter_vlc_player`
- **Swipe kanan layar atas–bawah** → ubah kecerahan (brightness)
- **Swipe kiri layar atas–bawah** → ubah volume
- **Swipe horizontal** → seek maju/mundur dengan preview durasi
- Double tap kiri/kanan → skip ±10 detik
- Speed playback: 0.25× – 4×, rotasi layar manual

---

### Phase 6 — Background Audio & Notifikasi ✦
*Putar musik saat app di background*

- Implementasi `audio_handler.dart` yang extend `BaseAudioHandler` dari `audio_service`
- Tampilkan notifikasi media dengan tombol play/pause/skip di lock screen
- Integrasikan `audio_session` agar audio pause otomatis saat ada telepon masuk
- Support Android Auto media controls

---

### Phase 7 — History & Recently Played ✦
*Akses cepat ke file yang baru diputar*

- Simpan riwayat file yang diputar ke `shared_preferences` (maks. 50 item)
- Simpan juga posisi terakhir video — saat dibuka lagi, tawarkan "Lanjut dari menit X"
- Tampilkan di tab "Terakhir" di HomeScreen dengan thumbnail
- Tombol hapus history individual atau semua

---

### Phase 8 — Equalizer & Playlist
*Fitur lanjutan audio & manajemen antrian*

- Equalizer 5-band via API equalizer `media_kit` — preset & manual
- Playlist dengan drag-reorder, shuffle, repeat (off / one / all)
- Tambah file ke playlist dari browser tanpa keluar player
- Simpan playlist ke file `.m3u` untuk interoperabilitas

---

## Kompatibilitas Android Per Versi

| Versi Android | Izin yang Dibutuhkan | Catatan |
|---|---|---|
| ≤ 9 | `READ_EXTERNAL_STORAGE` | Paling simpel |
| 10 – 12 | `READ_EXTERNAL_STORAGE` | + `requestLegacyExternalStorage` di manifest |
| 13+ | `READ_MEDIA_VIDEO` `READ_MEDIA_AUDIO` | Per jenis media, tidak perlu storage umum |

---

## Alur Lengkap Aplikasi

```
Buka app
  ├── Tab "File saya"  → scan/baca DB → daftar + thumbnail
  ├── Tab "Browser"    → jelajah folder bebas
  ├── Tab "Terakhir"   → recently played + resume posisi ✦
  └── Tombol "Buka"    → system file picker
                             ↓
               Tap file → PlayerScreen → media_kit
                             ↓
               Kontrol: gesture · speed · rotasi · equalizer · playlist
               Background: notifikasi lock screen · audio_service ✦
```

---

> ✦ = fitur tambahan yang disarankan
