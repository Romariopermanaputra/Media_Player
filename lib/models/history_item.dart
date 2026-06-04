/// Model untuk riwayat pemutaran media.
///
/// Menyimpan informasi posisi terakhir pemutaran sehingga
/// pengguna dapat melanjutkan dari posisi sebelumnya.
library;

class HistoryItem {
  final int? id;
  final String mediaPath;
  final String mediaName;
  final String? thumbnailPath;
  final int lastPositionMs;
  final int? durationMs;
  final DateTime playedAt;

  const HistoryItem({
    this.id,
    required this.mediaPath,
    required this.mediaName,
    this.thumbnailPath,
    required this.lastPositionMs,
    this.durationMs,
    required this.playedAt,
  });

  /// Membuat [HistoryItem] dari Map (biasanya hasil query database).
  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'] as int?,
      mediaPath: map['media_path'] as String,
      mediaName: map['media_name'] as String,
      thumbnailPath: map['thumbnail_path'] as String?,
      lastPositionMs: map['last_position_ms'] as int,
      durationMs: map['duration_ms'] as int?,
      playedAt: DateTime.fromMillisecondsSinceEpoch(
        map['played_at'] as int,
      ),
    );
  }

  /// Konversi [HistoryItem] ke Map untuk disimpan ke database.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'media_path': mediaPath,
      'media_name': mediaName,
      'thumbnail_path': thumbnailPath,
      'last_position_ms': lastPositionMs,
      'duration_ms': durationMs,
      'played_at': playedAt.millisecondsSinceEpoch,
    };
  }

  /// Membuat salinan [HistoryItem] dengan field yang diubah.
  HistoryItem copyWith({
    int? id,
    String? mediaPath,
    String? mediaName,
    String? thumbnailPath,
    int? lastPositionMs,
    int? durationMs,
    DateTime? playedAt,
  }) {
    return HistoryItem(
      id: id ?? this.id,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaName: mediaName ?? this.mediaName,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      durationMs: durationMs ?? this.durationMs,
      playedAt: playedAt ?? this.playedAt,
    );
  }

  // -- Getters --

  /// Persentase progress pemutaran (0.0 - 1.0).
  /// Mengembalikan 0.0 jika durasi tidak diketahui atau nol.
  double get progressPercentage {
    if (durationMs == null || durationMs == 0) return 0.0;
    return (lastPositionMs / durationMs!).clamp(0.0, 1.0);
  }

  /// Persentase progress sebagai integer (0 - 100).
  int get progressPercent => (progressPercentage * 100).round();

  /// Apakah media sudah selesai diputar (progress >= 95%).
  bool get isCompleted => progressPercentage >= 0.95;

  /// Mendapatkan posisi terakhir dalam format yang mudah dibaca.
  /// Format: "HH:MM:SS" atau "MM:SS" jika kurang dari 1 jam.
  String get formattedPosition {
    final duration = Duration(milliseconds: lastPositionMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Mendapatkan durasi total dalam format yang mudah dibaca.
  /// Format: "HH:MM:SS" atau "MM:SS" jika kurang dari 1 jam.
  String get formattedDuration {
    if (durationMs == null) return '--:--';

    final duration = Duration(milliseconds: durationMs!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Teks ringkasan progress, contoh: "05:30 / 10:00 (55%)"
  String get progressSummary {
    return '$formattedPosition / $formattedDuration ($progressPercent%)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryItem &&
          runtimeType == other.runtimeType &&
          mediaPath == other.mediaPath;

  @override
  int get hashCode => mediaPath.hashCode;

  @override
  String toString() =>
      'HistoryItem(name: $mediaName, progress: $progressPercent%)';
}
