/// Utility statis untuk generate dan cache thumbnail video.
///
/// Thumbnail di-generate dari frame pertama video menggunakan package
/// `video_thumbnail`, lalu disimpan di temporary directory agar tidak
/// perlu di-generate ulang.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Helper statis untuk generate, cache, dan mengelola thumbnail video.
class ThumbnailHelper {
  ThumbnailHelper._(); // Tidak bisa diinstansiasi.

  /// Subdirektori di dalam temp dir untuk menyimpan thumbnail.
  static const String _cacheSubDir = 'media_thumbnails';

  // ===========================================================================
  // Public API
  // ===========================================================================

  /// Generate thumbnail dari file video, simpan ke cache, dan kembalikan
  /// path file thumbnail.
  ///
  /// Mengembalikan `null` jika generate gagal (file corrupt, audio-only,
  /// atau error lainnya).
  static Future<String?> generateThumbnail(String videoPath) async {
    try {
      final cacheDir = await _ensureCacheDir();
      final fileName = _hashFileName(videoPath);
      final outputPath = p.join(cacheDir.path, fileName);

      final result = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: outputPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 256, // Ukuran cukup untuk list tile.
        quality: 75,
      );

      if (result != null && await File(result).exists()) {
        debugPrint('[ThumbnailHelper] Thumbnail dibuat: $result');
        return result;
      }

      debugPrint('[ThumbnailHelper] Generate gagal untuk: $videoPath');
      return null;
    } catch (e) {
      // File corrupt, format tidak didukung, atau audio-only.
      debugPrint('[ThumbnailHelper] Error generate thumbnail: $e');
      return null;
    }
  }

  /// Cek apakah thumbnail untuk [videoPath] sudah ada di cache.
  ///
  /// Mengembalikan path thumbnail jika ada, `null` jika belum di-generate.
  /// Method ini sinkron terhadap filesystem check.
  static Future<String?> getCachedThumbnail(String videoPath) async {
    try {
      final cacheDir = await _getCacheDir();
      if (cacheDir == null) return null;

      final fileName = _hashFileName(videoPath);
      final file = File(p.join(cacheDir.path, fileName));

      if (await file.exists()) return file.path;
      return null;
    } catch (e) {
      debugPrint('[ThumbnailHelper] Error cek cache: $e');
      return null;
    }
  }

  /// Ambil thumbnail dari cache jika sudah ada, kalau belum generate baru.
  ///
  /// Ini adalah method utama yang sebaiknya dipanggil dari UI.
  static Future<String?> generateOrGetCached(String videoPath) async {
    // Cek cache terlebih dahulu.
    final cached = await getCachedThumbnail(videoPath);
    if (cached != null) return cached;

    // Belum ada di cache — generate baru.
    return generateThumbnail(videoPath);
  }

  /// Hapus semua thumbnail dari cache.
  static Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDir();
      if (cacheDir != null && await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('[ThumbnailHelper] Cache thumbnail dihapus.');
      }
    } catch (e) {
      debugPrint('[ThumbnailHelper] Error hapus cache: $e');
    }
  }

  // ===========================================================================
  // Internal
  // ===========================================================================

  /// Dapatkan atau buat direktori cache thumbnail.
  static Future<Directory> _ensureCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, _cacheSubDir));

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  /// Dapatkan direktori cache (tanpa membuat jika belum ada).
  static Future<Directory?> _getCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, _cacheSubDir));
    if (await cacheDir.exists()) return cacheDir;
    return null;
  }

  /// Buat nama file hash dari path video.
  ///
  /// Menggunakan hash code sederhana yang deterministik untuk menghindari
  /// dependency tambahan ke package crypto. Hasilnya berupa hex string
  /// yang unik untuk setiap path + ekstensi `.jpg`.
  static String _hashFileName(String videoPath) {
    // Simple deterministic hash — cukup untuk cache key.
    var hash = 0x811c9dc5; // FNV offset basis (32-bit).
    for (var i = 0; i < videoPath.length; i++) {
      hash ^= videoPath.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime.
    }
    return '${hash.toRadixString(16).padLeft(8, '0')}.jpg';
  }
}
