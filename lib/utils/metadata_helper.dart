import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Utility untuk mengekstrak metadata dari file media audio (ID3/MP4 tags).
class MetadataHelper {
  MetadataHelper._();

  /// Cache directory untuk menyimpan hasil extract cover art.
  static Directory? _cacheDir;

  /// Inisialisasi cache directory.
  static Future<void> _initCache() async {
    if (_cacheDir != null) return;
    final tempDir = await getTemporaryDirectory();
    _cacheDir = Directory(p.join(tempDir.path, 'cover_art_cache'));
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  /// Ekstrak metadata dari file audio.
  /// 
  /// Akan mengembalikan Map berisi:
  /// - `artist`: (String?) Nama artist
  /// - `album`: (String?) Nama album
  /// - `coverArtPath`: (String?) Path lokal ke file gambar cover art yang di-cache
  static Future<Map<String, String?>> extractMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return {};

      // Pastikan cache directory siap
      await _initCache();

      final metadata = await MetadataRetriever.fromFile(file);

      String? coverArtPath;

      // Jika ada cover art, simpan ke cache file
      if (metadata.albumArt != null && metadata.albumArt!.isNotEmpty) {
        // Buat nama file unik berdasarkan hash path file asal + size, 
        // agar kalau file diubah, cover art juga bisa di-update.
        final fileStat = await file.stat();
        final rawKey = '$filePath-${fileStat.size}-${fileStat.modified.millisecondsSinceEpoch}';
        final hash = md5.convert(utf8.encode(rawKey)).toString();
        
        final cacheFile = File(p.join(_cacheDir!.path, '$hash.jpg'));
        
        // Cek apakah sudah di-cache sebelumnya
        if (await cacheFile.exists()) {
          coverArtPath = cacheFile.path;
        } else {
          // Tulis data gambar ke file cache
          await cacheFile.writeAsBytes(metadata.albumArt!);
          coverArtPath = cacheFile.path;
        }
      }

      return {
        'artist': metadata.trackArtistNames?.isNotEmpty == true 
            ? metadata.trackArtistNames!.join(', ') 
            : metadata.albumArtistName,
        'album': metadata.albumName,
        'coverArtPath': coverArtPath,
      };
    } catch (e) {
      debugPrint('[MetadataHelper] Gagal ekstrak metadata untuk $filePath: $e');
      return {};
    }
  }
}
