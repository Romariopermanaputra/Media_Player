import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_player/models/media_item.dart';

/// Mode pengurutan isi direktori.
enum SortMode {
  /// Urutkan berdasarkan nama file (A–Z).
  name,

  /// Urutkan berdasarkan tanggal modifikasi (terbaru di atas).
  date,

  /// Urutkan berdasarkan ukuran file (terbesar di atas).
  size,

  /// Urutkan berdasarkan tipe/ekstensi file.
  type,
}

/// Provider untuk menjelajahi file-system perangkat.
///
/// Memfilter hanya file media (video & audio), mendukung multi-select,
/// breadcrumb navigation, dan pengurutan.
class FileBrowserProvider extends ChangeNotifier {
  // ──────────────────────────── State fields ───────────────────────────
  String _currentPath = '';
  List<FileSystemEntity> _entries = [];
  bool _isLoading = false;
  List<String> _pathHistory = [];
  bool _isMultiSelectMode = false;
  final Set<String> _selectedPaths = {};
  SortMode _sortMode = SortMode.name;
  String? _error;

  // ──────────────────────────── Getters ─────────────────────────────────
  String get currentPath => _currentPath;
  List<FileSystemEntity> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  List<String> get pathHistory => List.unmodifiable(_pathHistory);
  bool get isMultiSelectMode => _isMultiSelectMode;
  Set<String> get selectedPaths => Set.unmodifiable(_selectedPaths);
  SortMode get sortMode => _sortMode;
  String? get error => _error;

  /// Jumlah item yang dipilih saat multi-select aktif.
  int get selectedCount => _selectedPaths.length;

  /// Daftar direktori saja dari entries.
  List<Directory> get directories =>
      _entries.whereType<Directory>().toList();

  /// Daftar file saja dari entries.
  List<File> get files => _entries.whereType<File>().toList();

  // ──────────────────────── Ekstensi media yang didukung ───────────────
  /// Ekstensi video yang dikenali.
  static const Set<String> videoExtensions = {
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm',
    '.m4v', '.3gp', '.ts', '.mpg', '.mpeg',
  };

  /// Ekstensi audio yang dikenali.
  static const Set<String> audioExtensions = {
    '.mp3', '.flac', '.aac', '.ogg', '.wav', '.wma',
    '.m4a', '.opus', '.aiff', '.alac',
  };

  /// Semua ekstensi media (gabungan video + audio).
  static Set<String> get allMediaExtensions =>
      {...videoExtensions, ...audioExtensions};

  // ──────────────────────────── Navigation ─────────────────────────────

  /// Muat isi direktori pada [path].
  ///
  /// Memfilter hanya file media dan direktori, lalu mengurutkan hasilnya.
  /// Jika terjadi error (misal permission denied), akan disimpan di [error].
  Future<void> loadDirectory(String path) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        _error = 'Direktori tidak ditemukan: $path';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _currentPath = path;

      // Update breadcrumb history
      _updatePathHistory(path);

      // Ambil semua entity di dalam direktori
      final List<FileSystemEntity> allEntities = [];
      try {
        await for (final entity in dir.list(followLinks: false)) {
          allEntities.add(entity);
        }
      } on FileSystemException catch (e) {
        _error = 'Gagal membaca direktori: ${e.message}';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Filter: ambil direktori + file media saja
      final List<FileSystemEntity> filtered = [];
      for (final entity in allEntities) {
        if (entity is Directory) {
          // Sembunyikan direktori tersembunyi (dimulai dengan titik)
          final name = _entityName(entity);
          if (!name.startsWith('.')) {
            filtered.add(entity);
          }
        } else if (entity is File) {
          if (_isMediaFile(entity.path)) {
            filtered.add(entity);
          }
        }
      }

      // Urutkan: direktori dulu, lalu file – masing-masing sesuai sortMode
      _entries = _sortEntries(filtered);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Terjadi kesalahan: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Navigasi ke direktori parent.
  Future<void> navigateUp() async {
    if (_currentPath.isEmpty) return;
    final parent = Directory(_currentPath).parent;
    await loadDirectory(parent.path);
  }

  /// Navigasi langsung ke [path] tertentu.
  Future<void> navigateTo(String path) async {
    await loadDirectory(path);
  }

  // ──────────────────────────── Multi-select ───────────────────────────

  /// Toggle mode multi-select on/off. Saat dimatikan, selection di-clear.
  void toggleMultiSelect() {
    _isMultiSelectMode = !_isMultiSelectMode;
    if (!_isMultiSelectMode) {
      _selectedPaths.clear();
    }
    notifyListeners();
  }

  /// Toggle seleksi pada file/direktori tertentu berdasarkan [path].
  void toggleSelection(String path) {
    if (_selectedPaths.contains(path)) {
      _selectedPaths.remove(path);
    } else {
      _selectedPaths.add(path);
    }
    notifyListeners();
  }

  /// Hapus semua seleksi tanpa mematikan mode multi-select.
  void clearSelection() {
    _selectedPaths.clear();
    notifyListeners();
  }

  /// Konversi file-file yang dipilih menjadi [List<MediaItem>].
  ///
  /// Hanya file media yang dikonversi; direktori di-skip.
  List<MediaItem> getSelectedMediaItems() {
    final List<MediaItem> items = [];

    for (final path in _selectedPaths) {
      if (!_isMediaFile(path)) continue;

      final file = File(path);
      final name = _entityName(file);
      final type = MediaItem.detectType(path);
      int fileSize = 0;
      DateTime lastModified = DateTime.now();
      try {
        final stat = file.statSync();
        fileSize = stat.size;
        lastModified = stat.modified;
      } catch (_) {}

      items.add(
        MediaItem(
          path: path,
          name: name,
          sizeBytes: fileSize,
          type: type,
          lastModified: lastModified,
        ),
      );
    }

    return items;
  }

  // ──────────────────────────── Sorting ─────────────────────────────────

  /// Atur mode pengurutan dan muat ulang tampilan.
  void setSortMode(SortMode mode) {
    if (_sortMode == mode) return;
    _sortMode = mode;
    // Re-sort entries yang sudah ada tanpa reload dari disk
    _entries = _sortEntries(List.of(_entries));
    notifyListeners();
  }

  // ──────────────────────────── Helpers ─────────────────────────────────

  /// Cek apakah file pada [path] adalah file media berdasarkan ekstensi.
  bool _isMediaFile(String path) {
    final ext = _fileExtension(path);
    return allMediaExtensions.contains(ext);
  }

  /// Ambil ekstensi file (lowercase, termasuk titik).
  String _fileExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1 || lastDot == path.length - 1) return '';
    return path.substring(lastDot).toLowerCase();
  }

  /// Ambil nama entity (file/directory) dari path.
  String _entityName(FileSystemEntity entity) {
    final path = entity.path;
    final sep = path.contains('\\') ? '\\' : '/';
    // Hapus trailing separator jika ada (untuk directory)
    final trimmed = path.endsWith(sep) ? path.substring(0, path.length - 1) : path;
    final segments = trimmed.split(sep);
    return segments.isNotEmpty ? segments.last : trimmed;
  }

  /// Update daftar breadcrumb [_pathHistory] berdasarkan [path].
  void _updatePathHistory(String path) {
    final sep = path.contains('\\') ? '\\' : '/';
    final parts = path.split(sep).where((p) => p.isNotEmpty).toList();

    _pathHistory = [];
    String accumulated = '';

    // Untuk Windows, sertakan drive letter
    if (path.contains(':\\')) {
      for (int i = 0; i < parts.length; i++) {
        if (i == 0) {
          accumulated = '${parts[i]}$sep';
        } else {
          accumulated = '$accumulated${parts[i]}$sep';
        }
        _pathHistory.add(accumulated);
      }
    } else {
      // Unix-like path
      for (final part in parts) {
        accumulated = '$accumulated$sep$part';
        _pathHistory.add(accumulated);
      }
    }
  }

  /// Urutkan [entities] sesuai [_sortMode].
  ///
  /// Direktori selalu ditampilkan terlebih dahulu, diikuti oleh file.
  List<FileSystemEntity> _sortEntries(List<FileSystemEntity> entities) {
    final dirs = entities.whereType<Directory>().toList();
    final fileList = entities.whereType<File>().toList();

    // Sort direktori berdasarkan nama (selalu)
    dirs.sort((a, b) => _entityName(a).toLowerCase().compareTo(
          _entityName(b).toLowerCase(),
        ));

    // Sort file berdasarkan mode yang dipilih
    switch (_sortMode) {
      case SortMode.name:
        fileList.sort((a, b) => _entityName(a).toLowerCase().compareTo(
              _entityName(b).toLowerCase(),
            ));

      case SortMode.date:
        fileList.sort((a, b) {
          try {
            return b.lastModifiedSync().compareTo(a.lastModifiedSync());
          } catch (_) {
            return 0;
          }
        });

      case SortMode.size:
        fileList.sort((a, b) {
          try {
            return b.lengthSync().compareTo(a.lengthSync());
          } catch (_) {
            return 0;
          }
        });

      case SortMode.type:
        fileList.sort((a, b) {
          final extA = _fileExtension(a.path);
          final extB = _fileExtension(b.path);
          final cmp = extA.compareTo(extB);
          if (cmp != 0) return cmp;
          return _entityName(a).toLowerCase().compareTo(
                _entityName(b).toLowerCase(),
              );
        });
    }

    return [...dirs, ...fileList];
  }

  /// Cek apakah file pada [path] adalah video.
  static bool isVideoFile(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return false;
    final ext = path.substring(lastDot).toLowerCase();
    return videoExtensions.contains(ext);
  }

  /// Cek apakah file pada [path] adalah audio.
  static bool isAudioFile(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return false;
    final ext = path.substring(lastDot).toLowerCase();
    return audioExtensions.contains(ext);
  }
}
