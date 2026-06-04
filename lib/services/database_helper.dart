/// Helper singleton untuk mengelola database SQLite aplikasi.
///
/// Menangani dua tabel utama:
/// - `media_files`  — indeks semua file media yang ditemukan di device.
/// - `play_history` — riwayat pemutaran beserta posisi terakhir.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:media_player/models/history_item.dart';
import 'package:media_player/models/media_item.dart';
import 'package:media_player/models/saved_playlist.dart';

/// Versi skema database saat ini.
const int _kDatabaseVersion = 3;

/// Nama file database.
const String _kDatabaseName = 'media_player.db';

/// Singleton yang menyediakan akses ke database SQLite.
///
/// Gunakan [DatabaseHelper.instance] untuk mendapatkan instance tunggal,
/// lalu panggil method CRUD sesuai kebutuhan.
class DatabaseHelper {
  DatabaseHelper._();

  /// Instance tunggal (singleton).
  static final DatabaseHelper instance = DatabaseHelper._();

  /// Database instance yang di-cache.
  Database? _database;

  /// Mendapatkan koneksi database. Akan membuat database baru jika
  /// belum ada, atau membuka yang sudah ada.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inisialisasi database — buat file dan tabel jika belum ada.
  Future<Database> _initDatabase() async {
    // Gunakan path_provider agar lokasi file aman lintas device.
    final documentsDir = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDir.path, _kDatabaseName);

    debugPrint('[DatabaseHelper] Membuka database di: $path');

    return openDatabase(
      path,
      version: _kDatabaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Callback saat database pertama kali dibuat.
  Future<void> _onCreate(Database db, int version) async {
    // -- Tabel media_files --
    await db.execute('''
      CREATE TABLE media_files (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        path            TEXT    UNIQUE NOT NULL,
        name            TEXT    NOT NULL,
        folder_path     TEXT,
        size_bytes      INTEGER NOT NULL DEFAULT 0,
        duration_ms     INTEGER,
        type            TEXT    NOT NULL,
        thumbnail_path  TEXT,
        artist          TEXT,
        album           TEXT,
        cover_art_path  TEXT,
        last_modified   INTEGER NOT NULL,
        added_at        INTEGER,
        is_favorite     INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_media_folder ON media_files (folder_path)',
    );
    await db.execute(
      'CREATE INDEX idx_media_type ON media_files (type)',
    );
    await db.execute(
      'CREATE INDEX idx_media_artist ON media_files (artist)',
    );

    // -- Tabel play_history --
    await db.execute('''
      CREATE TABLE play_history (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        media_path       TEXT    NOT NULL,
        media_name       TEXT    NOT NULL,
        thumbnail_path   TEXT,
        last_position_ms INTEGER NOT NULL DEFAULT 0,
        duration_ms      INTEGER,
        played_at        INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_history_path ON play_history (media_path)',
    );
    await db.execute(
      'CREATE INDEX idx_history_played ON play_history (played_at DESC)',
    );

    // -- Tabel saved_playlists --
    await db.execute('''
      CREATE TABLE saved_playlists (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // -- Tabel playlist_items --
    await db.execute('''
      CREATE TABLE playlist_items (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        media_path  TEXT    NOT NULL,
        position    INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (playlist_id) REFERENCES saved_playlists(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_playlist_items_pid ON playlist_items (playlist_id)',
    );

    debugPrint('[DatabaseHelper] Tabel berhasil dibuat (v$version).');
  }

  /// Callback untuk migrasi skema saat versi naik.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint(
      '[DatabaseHelper] Migrasi database v$oldVersion → v$newVersion',
    );
    if (oldVersion < 2) {
      // Tambah kolom metadata audio
      await db.execute('ALTER TABLE media_files ADD COLUMN artist TEXT');
      await db.execute('ALTER TABLE media_files ADD COLUMN album TEXT');
      await db.execute('ALTER TABLE media_files ADD COLUMN cover_art_path TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_media_artist ON media_files (artist)',
      );

      // Tabel playlist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS saved_playlists (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          name       TEXT    NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS playlist_items (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          playlist_id INTEGER NOT NULL,
          media_path  TEXT    NOT NULL,
          position    INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (playlist_id) REFERENCES saved_playlists(id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_playlist_items_pid ON playlist_items (playlist_id)',
      );
      debugPrint('[DatabaseHelper] Migrasi v1 → v2 selesai.');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE media_files ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
      );
      debugPrint('[DatabaseHelper] Migrasi v2 → v3 selesai.');
    }
  }

  // ===========================================================================
  // MEDIA FILES — CRUD
  // ===========================================================================

  /// Insert satu [MediaItem] ke database.
  ///
  /// Mengembalikan row ID. Jika path sudah ada, operasi diabaikan
  /// (karena kolom `path` UNIQUE) dan mengembalikan -1.
  Future<int> insertMedia(MediaItem item) async {
    final db = await database;
    try {
      return await db.insert(
        'media_files',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      debugPrint('[DatabaseHelper] insertMedia error: $e');
      return -1;
    }
  }

  /// Insert atau update (upsert) satu [MediaItem].
  ///
  /// Jika path sudah ada, baris yang ada akan di-replace.
  Future<int> insertOrUpdateMedia(MediaItem item) async {
    final db = await database;
    try {
      return await db.insert(
        'media_files',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[DatabaseHelper] insertOrUpdateMedia error: $e');
      return -1;
    }
  }

  /// Ambil semua media dari database, diurutkan berdasarkan nama.
  Future<List<MediaItem>> getAllMedia() async {
    final db = await database;
    final rows = await db.query('media_files', orderBy: 'name ASC');
    return rows.map(MediaItem.fromMap).toList();
  }

  /// Ambil media berdasarkan folder path tertentu.
  Future<List<MediaItem>> getMediaByFolder(String folderPath) async {
    final db = await database;
    final rows = await db.query(
      'media_files',
      where: 'folder_path = ?',
      whereArgs: [folderPath],
      orderBy: 'name ASC',
    );
    return rows.map(MediaItem.fromMap).toList();
  }

  /// Hapus media berdasarkan path file.
  Future<int> deleteMedia(String path) async {
    final db = await database;
    return db.delete('media_files', where: 'path = ?', whereArgs: [path]);
  }

  /// Toggle status favorit.
  Future<int> toggleFavorite(String path, bool isFavorite) async {
    final db = await database;
    return await db.update(
      'media_files',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  /// Ambil semua lagu favorit.
  Future<List<MediaItem>> getFavorites() async {
    final db = await database;
    final rows = await db.query(
      'media_files',
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return rows.map(MediaItem.fromMap).toList();
  }

  /// Ambil daftar folder unik yang mengandung media.
  ///
  /// Mengembalikan list path folder, diurutkan secara alfabet.
  Future<List<String>> getFolders() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT folder_path FROM media_files '
      'WHERE folder_path IS NOT NULL '
      'ORDER BY folder_path ASC',
    );
    return rows
        .map((row) => row['folder_path'] as String?)
        .whereType<String>()
        .toList();
  }

  /// Ambil satu [MediaItem] berdasarkan path.
  ///
  /// Mengembalikan `null` jika tidak ditemukan.
  Future<MediaItem?> getMediaByPath(String path) async {
    final db = await database;
    final rows = await db.query(
      'media_files',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MediaItem.fromMap(rows.first);
  }

  /// Hitung total jumlah media di database.
  Future<int> getMediaCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM media_files');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ===========================================================================
  // PLAY HISTORY — CRUD
  // ===========================================================================

  /// Tambahkan entry baru ke riwayat pemutaran.
  Future<int> insertHistory(HistoryItem item) async {
    final db = await database;
    try {
      final id = await db.insert('play_history', item.toMap());
      // Batasi maksimal 50 lagu di database
      await db.rawDelete('''
        DELETE FROM play_history 
        WHERE id NOT IN (
          SELECT id FROM play_history 
          ORDER BY played_at DESC 
          LIMIT 50
        )
      ''');
      return id;
    } catch (e) {
      debugPrint('[DatabaseHelper] insertHistory error: $e');
      return -1;
    }
  }

  /// Ambil riwayat pemutaran, diurutkan dari yang terbaru.
  ///
  /// [limit] membatasi jumlah hasil (default 50).
  Future<List<HistoryItem>> getHistory({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'play_history',
      orderBy: 'played_at DESC',
      limit: limit,
    );
    return rows.map(HistoryItem.fromMap).toList();
  }

  /// Update posisi terakhir pemutaran untuk history tertentu.
  Future<int> updateHistoryPosition(int historyId, int positionMs) async {
    final db = await database;
    return db.update(
      'play_history',
      {
        'last_position_ms': positionMs,
        'played_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [historyId],
    );
  }

  /// Hapus semua riwayat pemutaran.
  Future<int> clearHistory() async {
    final db = await database;
    return db.delete('play_history');
  }

  /// Hapus satu entry riwayat berdasarkan ID.
  Future<int> deleteHistoryItem(int id) async {
    final db = await database;
    return db.delete('play_history', where: 'id = ?', whereArgs: [id]);
  }

  /// Cari history berdasarkan media path.
  ///
  /// Mengembalikan entry terbaru jika ada, `null` jika tidak ditemukan.
  Future<HistoryItem?> getHistoryByPath(String mediaPath) async {
    final db = await database;
    final rows = await db.query(
      'play_history',
      where: 'media_path = ?',
      whereArgs: [mediaPath],
      orderBy: 'played_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return HistoryItem.fromMap(rows.first);
  }
  // ===========================================================================
  // SAVED PLAYLISTS — CRUD
  // ===========================================================================

  /// Buat playlist baru dengan nama tertentu.
  Future<int> createPlaylist(String name) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('saved_playlists', {
      'name': name,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Ambil semua saved playlists beserta jumlah item masing-masing.
  Future<List<SavedPlaylist>> getSavedPlaylists() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT sp.*, COUNT(pi.id) as item_count
      FROM saved_playlists sp
      LEFT JOIN playlist_items pi ON pi.playlist_id = sp.id
      GROUP BY sp.id
      ORDER BY sp.updated_at DESC
    ''');
    return rows.map(SavedPlaylist.fromMap).toList();
  }

  /// Tambah media ke playlist.
  Future<void> addToSavedPlaylist(int playlistId, List<String> mediaPaths) async {
    final db = await database;
    final batch = db.batch();
    // Ambil posisi terakhir
    final maxPos = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT MAX(position) FROM playlist_items WHERE playlist_id = ?',
      [playlistId],
    )) ?? -1;

    for (var i = 0; i < mediaPaths.length; i++) {
      batch.insert('playlist_items', {
        'playlist_id': playlistId,
        'media_path': mediaPaths[i],
        'position': maxPos + 1 + i,
      });
    }
    batch.update('saved_playlists',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [playlistId],
    );
    await batch.commit(noResult: true);
  }

  /// Ambil semua media items dalam sebuah playlist.
  Future<List<MediaItem>> getPlaylistItems(int playlistId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT mf.* FROM playlist_items pi
      JOIN media_files mf ON mf.path = pi.media_path
      WHERE pi.playlist_id = ?
      ORDER BY pi.position ASC
    ''', [playlistId]);
    return rows.map(MediaItem.fromMap).toList();
  }

  /// Hapus saved playlist beserta semua itemnya.
  Future<void> deleteSavedPlaylist(int playlistId) async {
    final db = await database;
    await db.delete('playlist_items',
        where: 'playlist_id = ?', whereArgs: [playlistId]);
    await db.delete('saved_playlists',
        where: 'id = ?', whereArgs: [playlistId]);
  }

  /// Rename saved playlist.
  Future<void> renameSavedPlaylist(int playlistId, String newName) async {
    final db = await database;
    await db.update('saved_playlists',
      {'name': newName, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [playlistId],
    );
  }

  /// Hapus item dari playlist.
  Future<void> removeFromSavedPlaylist(int playlistId, String mediaPath) async {
    final db = await database;
    await db.delete('playlist_items',
      where: 'playlist_id = ? AND media_path = ?',
      whereArgs: [playlistId, mediaPath],
    );
  }

  // ===========================================================================
  // QUERIES — Aggregasi
  // ===========================================================================

  /// Ambil daftar artist unik beserta jumlah lagu.
  Future<List<Map<String, dynamic>>> getArtists() async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        COALESCE(artist, 'Unknown Artist') as artist_name,
        COUNT(*) as song_count,
        MIN(cover_art_path) as sample_cover
      FROM media_files
      WHERE type = 'audio'
      GROUP BY COALESCE(artist, 'Unknown Artist')
      ORDER BY artist_name ASC
    ''');
  }

  /// Ambil semua media berdasarkan artist.
  Future<List<MediaItem>> getMediaByArtist(String artist) async {
    final db = await database;
    final rows = await db.query(
      'media_files',
      where: artist == 'Unknown Artist'
          ? '(artist IS NULL OR artist = ?)'
          : 'artist = ?',
      whereArgs: [artist],
      orderBy: 'name ASC',
    );
    return rows.map(MediaItem.fromMap).toList();
  }

  // ===========================================================================
  // UTILITY
  // ===========================================================================

  /// Tutup koneksi database.
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
      debugPrint('[DatabaseHelper] Database ditutup.');
    }
  }

  /// Hapus seluruh database (untuk debugging / reset).
  Future<void> deleteDatabase_() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDir.path, _kDatabaseName);
    await close();
    await deleteDatabase(path);
    debugPrint('[DatabaseHelper] Database dihapus: $path');
  }
}
