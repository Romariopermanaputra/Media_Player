/// Utility statis untuk akses storage Android.
///
/// Menangani runtime permission berdasarkan versi SDK,
/// format ukuran file, format durasi, dan deteksi tipe media.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper statis untuk operasi terkait storage dan formatting.
class StorageHelper {
  StorageHelper._(); // Tidak bisa diinstansiasi.

  // ===========================================================================
  // Ekstensi yang didukung
  // ===========================================================================

  /// Ekstensi video yang didukung.
  static const List<String> supportedVideoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'flv', 'wmv', 'webm', '3gp',
  ];

  /// Ekstensi audio yang didukung.
  static const List<String> supportedAudioExtensions = [
    'mp3', 'flac', 'aac', 'ogg', 'wav', 'wma', 'm4a', 'opus',
  ];

  /// Gabungan semua ekstensi media yang didukung.
  static List<String> get allSupportedExtensions => [
        ...supportedVideoExtensions,
        ...supportedAudioExtensions,
      ];

  // ===========================================================================
  // Permissions
  // ===========================================================================

  /// Minta permission storage/media sesuai versi Android.
  ///
  /// - SDK < 30 (Android 10 ke bawah): `READ_EXTERNAL_STORAGE`
  /// - SDK 30-32 (Android 11-12): `MANAGE_EXTERNAL_STORAGE` untuk full scan
  /// - SDK >= 33 (Android 13+): `READ_MEDIA_VIDEO` + `READ_MEDIA_AUDIO`
  ///   + `MANAGE_EXTERNAL_STORAGE` untuk recursive directory scan
  ///
  /// Mengembalikan `true` jika permission minimal sudah diberikan.
  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    // 1) Minta granular media permissions (Android 13+) dan storage (older).
    final statuses = await [
      Permission.videos,
      Permission.audio,
      Permission.storage,
    ].request();

    final videosGranted = statuses[Permission.videos]?.isGranted ?? false;
    final audioGranted = statuses[Permission.audio]?.isGranted ?? false;
    final storageGranted = statuses[Permission.storage]?.isGranted ?? false;

    debugPrint(
      '[StorageHelper] Basic permissions: '
      'storage=$storageGranted, videos=$videosGranted, audio=$audioGranted',
    );

    // 2) Minta MANAGE_EXTERNAL_STORAGE agar bisa scan direktori secara rekursif.
    //    Pada Android 11+ tanpa ini, dir.list() akan gagal dengan Permission Denied.
    final manageStatus = await Permission.manageExternalStorage.status;
    if (!manageStatus.isGranted) {
      debugPrint('[StorageHelper] Meminta MANAGE_EXTERNAL_STORAGE...');
      final result = await Permission.manageExternalStorage.request();
      debugPrint('[StorageHelper] MANAGE_EXTERNAL_STORAGE: $result');
    }

    final manageGranted = await Permission.manageExternalStorage.isGranted;
    final basicGranted = storageGranted || (videosGranted && audioGranted);

    debugPrint(
      '[StorageHelper] Final: basic=$basicGranted, manage=$manageGranted',
    );

    // Berhasil jika salah satu permission terpenuhi.
    return basicGranted || manageGranted;
  }

  /// Cek apakah permission storage/media sudah diberikan.
  static Future<bool> checkPermissions() async {
    if (!Platform.isAndroid) return true;

    final manageGranted = await Permission.manageExternalStorage.isGranted;
    if (manageGranted) return true;

    final storageGranted = await Permission.storage.isGranted;
    final videosGranted = await Permission.videos.isGranted;
    final audioGranted = await Permission.audio.isGranted;

    return storageGranted || (videosGranted && audioGranted);
  }

  // ===========================================================================
  // Storage Paths
  // ===========================================================================

  /// Mendapatkan daftar path storage yang tersedia di device.
  ///
  /// Menggabungkan hasil [getExternalStorageDirectories] dengan path
  /// umum yang biasa digunakan pengguna (Download, Music, dsb).
  static Future<List<String>> getStoragePaths() async {
    final paths = <String>{};

    try {
      // Path dari path_provider (mencakup internal + external SD card).
      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null) {
        for (final dir in externalDirs) {
          // getExternalStorageDirectories mengembalikan path seperti
          // /storage/emulated/0/Android/data/<pkg>/files
          // Kita naik ke root storage.
          final root = _extractStorageRoot(dir.path);
          if (root != null) paths.add(root);
        }
      }
    } catch (e) {
      debugPrint('[StorageHelper] Error getting external dirs: $e');
    }

    // Tambahkan path umum Android.
    const commonPaths = [
      '/storage/emulated/0',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Movies',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Videos',
    ];

    for (final path in commonPaths) {
      if (await Directory(path).exists()) {
        paths.add(path);
      }
    }

    return paths.toList()..sort();
  }

  /// Ekstrak root storage dari path Android/data/.../files.
  ///
  /// Contoh: `/storage/emulated/0/Android/data/com.x/files`
  ///       → `/storage/emulated/0`
  static String? _extractStorageRoot(String path) {
    final androidIndex = path.indexOf('/Android/');
    if (androidIndex != -1) {
      return path.substring(0, androidIndex);
    }
    return null;
  }

  // ===========================================================================
  // Formatting
  // ===========================================================================

  /// Format ukuran file dalam bytes ke bentuk yang mudah dibaca.
  ///
  /// Contoh: `formatFileSize(1536)` → `"1.5 KB"`
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    // Tampilkan tanpa desimal untuk Bytes, 1 desimal untuk yang lain.
    if (unitIndex == 0) return '${size.toInt()} B';
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  /// Format durasi dari milidetik ke format waktu yang mudah dibaca.
  ///
  /// - Kurang dari 1 jam: `MM:SS`  (contoh: `03:45`)
  /// - 1 jam atau lebih:  `HH:MM:SS` (contoh: `01:23:45`)
  static String formatDuration(int milliseconds) {
    if (milliseconds <= 0) return '00:00';

    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }

  // ===========================================================================
  // File type detection
  // ===========================================================================

  /// Deteksi tipe media berdasarkan ekstensi file.
  ///
  /// Mengembalikan `'video'`, `'audio'`, atau `'unknown'`.
  static String getFileType(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (supportedVideoExtensions.contains(ext)) return 'video';
    if (supportedAudioExtensions.contains(ext)) return 'audio';
    return 'unknown';
  }

  /// Cek apakah file memiliki ekstensi media yang didukung.
  static bool isSupportedMedia(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return allSupportedExtensions.contains(ext);
  }
}
