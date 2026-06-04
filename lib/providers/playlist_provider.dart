import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:media_player/models/media_item.dart';
import 'package:media_player/models/saved_playlist.dart';
import 'package:media_player/services/database_helper.dart';

/// Mode pengulangan pemutaran.
enum RepeatMode {
  /// Tidak mengulang – berhenti di akhir playlist.
  off,

  /// Ulang satu lagu/media yang sedang diputar.
  one,

  /// Ulang seluruh playlist dari awal setelah selesai.
  all,
}

/// Provider untuk mengelola playlist media.
///
/// Mendukung shuffle, tiga mode repeat, reorder, dan navigasi
/// maju/mundur antar item.
class PlaylistProvider extends ChangeNotifier {
  // ──────────────────────────── State fields ───────────────────────────
  final List<MediaItem> _playlist = [];
  int _currentIndex = -1;
  RepeatMode _repeatMode = RepeatMode.off;
  bool _isShuffled = false;
  List<int> _shuffleOrder = [];
  final Random _random = Random();

  // ──────────────────────────── Getters ─────────────────────────────────
  List<MediaItem> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  RepeatMode get repeatMode => _repeatMode;
  bool get isShuffled => _isShuffled;
  List<int> get shuffleOrder => List.unmodifiable(_shuffleOrder);
  int get length => _playlist.length;
  bool get isEmpty => _playlist.isEmpty;
  bool get isNotEmpty => _playlist.isNotEmpty;

  /// Item yang sedang aktif saat ini, atau `null` jika tidak ada.
  MediaItem? get currentItem {
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) return null;
    return _playlist[_effectiveIndex(_currentIndex)];
  }

  /// Apakah ada item selanjutnya yang bisa diputar.
  bool get hasNext {
    if (_playlist.isEmpty) return false;
    if (_repeatMode == RepeatMode.all || _repeatMode == RepeatMode.one) {
      return true;
    }
    return _currentIndex < _playlist.length - 1;
  }

  /// Apakah ada item sebelumnya yang bisa diputar.
  bool get hasPrevious {
    if (_playlist.isEmpty) return false;
    if (_repeatMode == RepeatMode.all || _repeatMode == RepeatMode.one) {
      return true;
    }
    return _currentIndex > 0;
  }

  // ──────────────────────────── Playlist mutation ──────────────────────

  /// Tambah satu [item] ke akhir playlist.
  void addToPlaylist(MediaItem item) {
    _playlist.add(item);
    _regenerateShuffleOrderIfNeeded();
    notifyListeners();
  }

  /// Tambah banyak [items] sekaligus ke akhir playlist.
  void addMultiple(List<MediaItem> items) {
    if (items.isEmpty) return;
    _playlist.addAll(items);
    _regenerateShuffleOrderIfNeeded();
    notifyListeners();
  }

  /// Hapus item pada posisi [index] dari playlist.
  void removeFromPlaylist(int index) {
    if (index < 0 || index >= _playlist.length) return;

    _playlist.removeAt(index);

    // Sesuaikan currentIndex setelah penghapusan
    if (_playlist.isEmpty) {
      _currentIndex = -1;
    } else if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      // Jika item yang aktif dihapus, tetap di posisi yang sama
      // atau mundur jika sudah di akhir
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.length - 1;
      }
    }

    _regenerateShuffleOrderIfNeeded();
    notifyListeners();
  }

  /// Pindahkan item dari [oldIndex] ke [newIndex] dalam playlist.
  void reorderPlaylist(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _playlist.length) return;
    if (newIndex < 0 || newIndex > _playlist.length) return;

    // Adjustment standar untuk ReorderableListView
    var adjustedNew = newIndex;
    if (oldIndex < adjustedNew) {
      adjustedNew -= 1;
    }
    if (adjustedNew < 0 || adjustedNew >= _playlist.length) return;

    final item = _playlist.removeAt(oldIndex);
    _playlist.insert(adjustedNew, item);

    // Update currentIndex agar tetap menunjuk ke item yang sama
    if (_currentIndex == oldIndex) {
      _currentIndex = adjustedNew;
    } else if (oldIndex < _currentIndex && adjustedNew >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && adjustedNew <= _currentIndex) {
      _currentIndex++;
    }

    _regenerateShuffleOrderIfNeeded();
    notifyListeners();
  }

  /// Hapus semua item dari playlist dan reset state.
  void clearPlaylist() {
    _playlist.clear();
    _currentIndex = -1;
    _shuffleOrder.clear();
    notifyListeners();
  }

  // ──────────────────────────── Navigation ─────────────────────────────

  /// Putar item pada posisi logis [index] dari _playlist.
  MediaItem playAt(int index) {
    if (index < 0 || index >= _playlist.length) {
      throw RangeError.range(index, 0, _playlist.length - 1, 'index');
    }
    if (_isShuffled && _shuffleOrder.isNotEmpty) {
      _currentIndex = _shuffleOrder.indexOf(index);
      if (_currentIndex == -1) _currentIndex = index; // fallback
    } else {
      _currentIndex = index;
    }
    notifyListeners();
    return _playlist[_effectiveIndex(_currentIndex)];
  }

  void setCurrentIndex(int index) {
    if (index < 0 || index >= _playlist.length) return;
    if (_isShuffled && _shuffleOrder.isNotEmpty) {
      _currentIndex = _shuffleOrder.indexOf(index);
      if (_currentIndex == -1) _currentIndex = index; // fallback
    } else {
      _currentIndex = index;
    }
    notifyListeners();
  }

  /// Pindah ke item selanjutnya berdasarkan repeat mode dan shuffle.
  ///
  /// Mengembalikan `null` jika sudah di akhir dan repeat mode = off.
  MediaItem? next() {
    if (_playlist.isEmpty) return null;

    switch (_repeatMode) {
      case RepeatMode.one:
        // Tetap di item yang sama
        notifyListeners();
        return currentItem;

      case RepeatMode.all:
        _currentIndex = (_currentIndex + 1) % _playlist.length;
        notifyListeners();
        return _playlist[_effectiveIndex(_currentIndex)];

      case RepeatMode.off:
        if (_currentIndex >= _playlist.length - 1) return null;
        _currentIndex++;
        notifyListeners();
        return _playlist[_effectiveIndex(_currentIndex)];
    }
  }

  /// Pindah ke item sebelumnya berdasarkan repeat mode dan shuffle.
  ///
  /// Mengembalikan `null` jika sudah di awal dan repeat mode = off.
  MediaItem? previous() {
    if (_playlist.isEmpty) return null;

    switch (_repeatMode) {
      case RepeatMode.one:
        notifyListeners();
        return currentItem;

      case RepeatMode.all:
        _currentIndex =
            (_currentIndex - 1 + _playlist.length) % _playlist.length;
        notifyListeners();
        return _playlist[_effectiveIndex(_currentIndex)];

      case RepeatMode.off:
        if (_currentIndex <= 0) return null;
        _currentIndex--;
        notifyListeners();
        return _playlist[_effectiveIndex(_currentIndex)];
    }
  }

  // ──────────────────────────── Shuffle & Repeat ───────────────────────

  /// Toggle mode shuffle on/off. Saat diaktifkan, buat urutan acak baru.
  void toggleShuffle() {
    setShuffle(!_isShuffled);
  }

  void setShuffle(bool enable) {
    if (_isShuffled == enable) return;
    _isShuffled = enable;
    if (_isShuffled) {
      _generateShuffleOrder();
    } else {
      _shuffleOrder.clear();
    }
    notifyListeners();
  }

  /// Ganti mode repeat secara bergantian: off → one → all → off.
  void cycleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.one;
      case RepeatMode.one:
        _repeatMode = RepeatMode.all;
      case RepeatMode.all:
        _repeatMode = RepeatMode.off;
    }
    notifyListeners();
  }

  // ──────────────────────────── Helpers ─────────────────────────────────

  /// Dapatkan index efektif mempertimbangkan shuffle order.
  int _effectiveIndex(int logicalIndex) {
    if (!_isShuffled || _shuffleOrder.isEmpty) return logicalIndex;
    if (logicalIndex < 0 || logicalIndex >= _shuffleOrder.length) {
      return logicalIndex;
    }
    return _shuffleOrder[logicalIndex];
  }

  /// Generate urutan acak untuk shuffle.
  void _generateShuffleOrder() {
    _shuffleOrder = List.generate(_playlist.length, (i) => i);
    _shuffleOrder.shuffle(_random);

    // Pastikan item yang sedang diputar tetap di posisi currentIndex
    if (_currentIndex >= 0 && _currentIndex < _shuffleOrder.length) {
      final currentActual = _currentIndex;
      final posInShuffle = _shuffleOrder.indexOf(currentActual);
      if (posInShuffle != -1 && posInShuffle != _currentIndex) {
        // Swap agar currentIndex tetap menunjuk ke item yang sama
        _shuffleOrder[posInShuffle] = _shuffleOrder[_currentIndex];
        _shuffleOrder[_currentIndex] = currentActual;
      }
    }
  }

  /// Regenerasi shuffle order jika shuffle sedang aktif (misal setelah
  /// playlist berubah).
  void _regenerateShuffleOrderIfNeeded() {
    if (_isShuffled) {
      _generateShuffleOrder();
    }
  }

  // ──────────────────────────── Persistent Playlists ───────────────────

  /// Simpan playlist aktif ke database dengan nama tertentu.
  Future<int> saveAsPlaylist(String name) async {
    final db = DatabaseHelper.instance;
    final playlistId = await db.createPlaylist(name);
    if (_playlist.isNotEmpty) {
      await db.addToSavedPlaylist(
        playlistId,
        _playlist.map((item) => item.path).toList(),
      );
    }
    return playlistId;
  }

  /// Buat playlist baru dari daftar path yang ditentukan, tanpa mengganti playlist aktif.
  Future<int> saveAsNewPlaylistFromPaths(String name, List<String> paths) async {
    final db = DatabaseHelper.instance;
    final playlistId = await db.createPlaylist(name);
    if (paths.isNotEmpty) {
      await db.addToSavedPlaylist(playlistId, paths);
    }
    return playlistId;
  }

  /// Muat saved playlist dari database ke playlist aktif.
  Future<void> loadSavedPlaylist(int playlistId) async {
    final db = DatabaseHelper.instance;
    final items = await db.getPlaylistItems(playlistId);
    _playlist.clear();
    _playlist.addAll(items);
    _currentIndex = items.isNotEmpty ? 0 : -1;
    _isShuffled = false;
    _shuffleOrder.clear();
    notifyListeners();
  }

  /// Ambil daftar semua playlist tersimpan.
  Future<List<SavedPlaylist>> getSavedPlaylists() async {
    return DatabaseHelper.instance.getSavedPlaylists();
  }

  /// Hapus saved playlist.
  Future<void> deleteSavedPlaylist(int id) async {
    await DatabaseHelper.instance.deleteSavedPlaylist(id);
  }

  /// Rename saved playlist.
  Future<void> renameSavedPlaylist(int id, String newName) async {
    await DatabaseHelper.instance.renameSavedPlaylist(id, newName);
  }

  /// Tambah item ke saved playlist.
  Future<void> addToSavedPlaylist(int playlistId, List<String> paths) async {
    await DatabaseHelper.instance.addToSavedPlaylist(playlistId, paths);
  }
}
