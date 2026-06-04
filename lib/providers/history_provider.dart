import 'package:flutter/foundation.dart';
import 'package:media_player/models/history_item.dart';
import 'package:media_player/services/database_helper.dart';

/// Provider untuk mengelola riwayat pemutaran media.
class HistoryProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<HistoryItem> _historyList = [];
  bool _isLoading = false;
  final int maxHistory;

  HistoryProvider({this.maxHistory = 50});

  List<HistoryItem> get historyList => List.unmodifiable(_historyList);
  bool get isLoading => _isLoading;
  int get length => _historyList.length;
  bool get isEmpty => _historyList.isEmpty;
  bool get isNotEmpty => _historyList.isNotEmpty;

  /// Muat riwayat dari database.
  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      _historyList = await _dbHelper.getHistory(limit: maxHistory);
    } catch (e) {
      debugPrint('HistoryProvider: Gagal memuat history – $e');
      _historyList = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Tambahkan media ke riwayat, atau perbarui jika sudah ada.
  Future<void> addToHistory(
    String path,
    String name, {
    String? thumbnailPath,
    int? durationMs,
  }) async {
    try {
      final existingIndex =
          _historyList.indexWhere((h) => h.mediaPath == path);

      if (existingIndex != -1) {
        final existing = _historyList[existingIndex];
        final updated = existing.copyWith(
          mediaName: name,
          thumbnailPath: thumbnailPath ?? existing.thumbnailPath,
          durationMs: durationMs ?? existing.durationMs,
          playedAt: DateTime.now(),
        );

        // Update in DB
        if (updated.id != null) {
          await _dbHelper.updateHistoryPosition(
            updated.id!,
            updated.lastPositionMs,
          );
        }

        _historyList.removeAt(existingIndex);
        _historyList.insert(0, updated);
      } else {
        final newItem = HistoryItem(
          mediaPath: path,
          mediaName: name,
          thumbnailPath: thumbnailPath,
          durationMs: durationMs,
          playedAt: DateTime.now(),
          lastPositionMs: 0,
        );

        final id = await _dbHelper.insertHistory(newItem);
        final saved = newItem.copyWith(id: id);
        _historyList.insert(0, saved);

        await _trimHistory();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('HistoryProvider: Gagal menambah history – $e');
    }
  }

  /// Perbarui posisi pemutaran terakhir.
  Future<void> updatePosition(String path, int positionMs) async {
    try {
      final index = _historyList.indexWhere((h) => h.mediaPath == path);
      if (index == -1) return;

      final updated = _historyList[index].copyWith(
        lastPositionMs: positionMs,
        playedAt: DateTime.now(),
      );

      if (updated.id != null) {
        await _dbHelper.updateHistoryPosition(updated.id!, positionMs);
      }
      _historyList[index] = updated;

      notifyListeners();
    } catch (e) {
      debugPrint('HistoryProvider: Gagal update posisi – $e');
    }
  }

  /// Hapus satu entri history berdasarkan [id].
  Future<void> removeFromHistory(int id) async {
    try {
      await _dbHelper.deleteHistoryItem(id);
      _historyList.removeWhere((h) => h.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('HistoryProvider: Gagal menghapus history – $e');
    }
  }

  /// Hapus seluruh riwayat pemutaran.
  Future<void> clearAllHistory() async {
    try {
      await _dbHelper.clearHistory();
      _historyList.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('HistoryProvider: Gagal menghapus semua history – $e');
    }
  }

  /// Ambil posisi pemutaran terakhir (dalam ms) untuk [path].
  int? getLastPosition(String path) {
    try {
      final item = _historyList.firstWhere((h) => h.mediaPath == path);
      return item.lastPositionMs;
    } on StateError {
      return null;
    }
  }

  /// Cek apakah ada posisi resume yang tersimpan untuk [path].
  bool hasResumePosition(String path) {
    final position = getLastPosition(path);
    if (position == null || position <= 0) return false;

    try {
      final item = _historyList.firstWhere((h) => h.mediaPath == path);
      if (item.durationMs != null && item.durationMs! > 0) {
        final remaining = item.durationMs! - position;
        return remaining > 3000;
      }
    } on StateError {
      return false;
    }

    return true;
  }

  /// Potong history jika melebihi [maxHistory].
  Future<void> _trimHistory() async {
    while (_historyList.length > maxHistory) {
      final oldest = _historyList.removeLast();
      if (oldest.id != null) {
        try {
          await _dbHelper.deleteHistoryItem(oldest.id!);
        } catch (e) {
          debugPrint('HistoryProvider: Gagal trim history – $e');
        }
      }
    }
  }
}
