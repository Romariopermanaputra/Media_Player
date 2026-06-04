/// Service untuk scan dan indexing file media dari storage device.
///
/// [MediaIndexer] melakukan:
/// 1. Scan rekursif di semua storage yang tersedia.
/// 2. Filter berdasarkan ekstensi media yang didukung.
/// 3. Delta scan — hanya proses file yang baru/berubah.
/// 4. Simpan hasil ke SQLite via [DatabaseHelper].
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:media_player/models/media_item.dart';
import 'package:media_player/services/database_helper.dart';
import 'package:media_player/utils/storage_helper.dart';
import 'package:media_player/utils/thumbnail_helper.dart';
import 'package:media_player/utils/metadata_helper.dart';

/// Scan dan index semua file media di device ke database lokal.
class MediaIndexer {
  /// Buat instance [MediaIndexer].
  ///
  /// [databaseHelper] digunakan untuk menyimpan hasil scan ke SQLite.
  MediaIndexer({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  /// Direktori yang di-skip saat scan (folder sistem / tersembunyi).
  static const Set<String> _skipDirectories = {
    '.thumbnails',
    '.trash',
    '.Trash',
    'lost+found',
  };

  /// Path prefix yang harus di-skip seluruhnya.
  static const List<String> _skipPathSegments = [
    '/Android/data',
    '/Android/obb',
    '/Android/media',
  ];



  // ===========================================================================
  // Public API
  // ===========================================================================

  /// Scan semua storage yang tersedia dan simpan hasilnya ke database.
  ///
  /// Strategi scan:
  /// 1. Scan direktori umum user terlebih dahulu (Download, Music, Movies, dll)
  /// 2. Scan root storage untuk menangkap file di lokasi custom
  /// 3. Cleanup entry database yang file-nya sudah dihapus
  ///
  /// Mengembalikan jumlah file media baru/ter-update yang ditemukan.
  Future<int> scanAll() async {
    debugPrint('[MediaIndexer] Memulai full scan...');
    var totalFound = 0;

    // Kumpulkan semua root storage (internal + external SD).
    final storageRoots = <String>{};
    try {
      final storagePaths = await StorageHelper.getStoragePaths();
      for (final p in storagePaths) {
        // Hanya ambil root storage, bukan subdirektorinya
        if (p == '/storage/emulated/0' ||
            (p.startsWith('/storage/') && !p.contains('/storage/emulated/0/'))) {
          storageRoots.add(p);
        }
      }
    } catch (e) {
      debugPrint('[MediaIndexer] Error getting storage paths: $e');
    }

    // Fallback jika tidak dapat root
    if (storageRoots.isEmpty) {
      storageRoots.add('/storage/emulated/0');
    }

    // 1) Scan direktori umum terlebih dahulu (paling sering berisi media user)
    final scannedPaths = <String>{};
    for (final root in storageRoots) {
      final commonDirs = [
        '$root/Download',
        '$root/Downloads',
        '$root/Music',
        '$root/Movies',
        '$root/Videos',
        '$root/DCIM',
        '$root/Pictures',
        '$root/Recordings',
        '$root/Ringtones',
        '$root/Podcasts',
        '$root/Audiobooks',
      ];

      for (final dirPath in commonDirs) {
        if (await Directory(dirPath).exists()) {
          debugPrint('[MediaIndexer] Scanning: $dirPath');
          final count = await scanDirectory(dirPath);
          totalFound += count;
          scannedPaths.add(dirPath);
        }
      }
    }

    // 2) Scan root storage untuk menangkap media di folder custom
    for (final root in storageRoots) {
      debugPrint('[MediaIndexer] Scanning root: $root');
      try {
        final rootDir = Directory(root);
        if (!await rootDir.exists()) continue;

        // List hanya level pertama dari root, scan subfolder yang belum ter-scan
        await for (final entity in rootDir.list(followLinks: false)) {
          if (entity is! Directory) {
            // File di root langsung — proses jika media
            if (entity is File && StorageHelper.isSupportedMedia(entity.path)) {
              try {
                final updated = await _processFile(entity);
                if (updated) totalFound++;
              } catch (_) {}
            }
            continue;
          }

          final dirName = entity.path.split('/').last;
          // Skip jika sudah di-scan atau di-skip
          if (scannedPaths.contains(entity.path)) continue;
          if (dirName.startsWith('.')) continue;
          if (dirName == 'Android') continue;
          if (_skipDirectories.contains(dirName)) continue;

          debugPrint('[MediaIndexer] Scanning subfolder: ${entity.path}');
          final count = await scanDirectory(entity.path);
          totalFound += count;
        }
      } catch (e) {
        debugPrint('[MediaIndexer] Error scanning root $root: $e');
      }
    }

    // 3) Bersihkan entry database yang file-nya sudah tidak ada.
    await _cleanupDeletedFiles();

    debugPrint('[MediaIndexer] Scan selesai. Total ditemukan: $totalFound');
    return totalFound;
  }

  /// Scan satu direktori secara rekursif dan simpan hasil ke database.
  ///
  /// Mengembalikan jumlah file yang baru ditambahkan atau diperbarui.
  Future<int> scanDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      debugPrint('[MediaIndexer] Direktori tidak ada: $path');
      return 0;
    }

    var count = 0;

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        // Hanya proses file, bukan direktori.
        if (entity is! File) continue;

        // Skip hidden directories (path mengandung folder yang dimulai titik).
        if (_isInHiddenOrSystemDir(entity.path)) continue;

        // Cek apakah ekstensi didukung.
        if (!StorageHelper.isSupportedMedia(entity.path)) continue;

        // Delta scan: cek apakah perlu di-update.
        try {
          final updated = await _processFile(entity);
          if (updated) count++;
        } catch (e) {
          // Permission denied atau file error — skip, lanjutkan.
          debugPrint('[MediaIndexer] Skip file ${entity.path}: $e');
        }
      }
    } catch (e) {
      // Permission denied pada level direktori — log dan lanjutkan.
      debugPrint('[MediaIndexer] Error scan dir $path: $e');
    }

    debugPrint('[MediaIndexer] Selesai scan $path → $count file baru/update.');
    return count;
  }

  /// Hitung jumlah media yang sudah ter-index di database.
  Future<int> getMediaCount() async {
    return _db.getMediaCount();
  }

  // ===========================================================================
  // Internal
  // ===========================================================================

  /// Proses satu file: bandingkan dengan DB, insert/update jika perlu.
  ///
  /// Mengembalikan `true` jika file baru ditambahkan atau diperbarui.
  Future<bool> _processFile(File file) async {
    final filePath = file.path;
    final stat = await file.stat();

    // Cek apakah sudah ada di database.
    final existing = await _db.getMediaByPath(filePath);

    if (existing != null) {
      // Delta scan: bandingkan last modified.
      final dbModified = existing.lastModified;
      // Bandingkan dalam detik untuk menghindari perbedaan milidetik.
      final dbSeconds = dbModified.millisecondsSinceEpoch ~/ 1000;
      final fileSeconds = stat.modified.millisecondsSinceEpoch ~/ 1000;
      if (dbSeconds >= fileSeconds) {
        // File tidak berubah — skip.
        return false;
      }
    }

    // Buat MediaItem dari file.
    final name = p.basename(filePath);
    final folderPath = p.dirname(filePath);
    final type = StorageHelper.getFileType(filePath);

    // Generate thumbnail untuk video baru (jika belum ada).
    String? thumbnailPath = existing?.thumbnailPath;
    if (type == 'video' && thumbnailPath == null) {
      try {
        thumbnailPath = await ThumbnailHelper.generateOrGetCached(filePath);
      } catch (e) {
        debugPrint('[MediaIndexer] Gagal generate thumbnail: $e');
      }
    }

    String? artist = existing?.artist;
    String? album = existing?.album;
    String? coverArtPath = existing?.coverArtPath;

    // Jika audio dan belum ada metadata, extract
    if (type == 'audio' && (existing == null || existing.artist == null)) {
      try {
        final meta = await MetadataHelper.extractMetadata(filePath);
        artist = meta['artist'];
        album = meta['album'];
        coverArtPath = meta['coverArtPath'];
      } catch (e) {
        debugPrint('[MediaIndexer] Gagal extract metadata audio: $e');
      }
    }

    final item = MediaItem(
      path: filePath,
      name: name,
      folderPath: folderPath,
      sizeBytes: stat.size,
      type: type,
      lastModified: stat.modified,
      thumbnailPath: thumbnailPath,
      artist: artist,
      album: album,
      coverArtPath: coverArtPath,
      durationMs: existing?.durationMs,
      addedAt: existing?.addedAt,
    );

    await _db.insertOrUpdateMedia(item);
    return true;
  }

  /// Cek apakah path berada di dalam hidden directory (dimulai dengan `.`)
  /// atau system directory yang harus di-skip.
  bool _isInHiddenOrSystemDir(String filePath) {
    // Cek path prefix yang harus di-skip (Android/data, dll).
    for (final segment in _skipPathSegments) {
      if (filePath.contains(segment)) return true;
    }

    final parts = filePath.split('/');
    for (final part in parts) {
      // Hidden directory (dimulai dengan titik).
      if (part.startsWith('.') && part.length > 1) return true;
      // Directory dalam daftar skip.
      if (_skipDirectories.contains(part)) return true;
    }
    return false;
  }

  /// Hapus entry database yang file fisiknya sudah tidak ada.
  Future<void> _cleanupDeletedFiles() async {
    debugPrint('[MediaIndexer] Membersihkan file yang sudah dihapus...');
    final allMedia = await _db.getAllMedia();
    var removedCount = 0;

    for (final item in allMedia) {
      if (!await File(item.path).exists()) {
        await _db.deleteMedia(item.path);
        removedCount++;
      }
    }

    if (removedCount > 0) {
      debugPrint('[MediaIndexer] $removedCount entry dihapus dari database.');
    }
  }
}
