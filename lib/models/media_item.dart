/// Model untuk item media (video/audio) yang tersimpan di database.
///
/// Menyimpan metadata file media termasuk path, ukuran, durasi,
/// thumbnail, dan tipe media (video/audio).
library;

import 'package:path/path.dart' as p;

class MediaItem {
  final int? id;
  final String path;
  final String name;
  final String? folderPath;
  final int sizeBytes;
  final int? durationMs;
  final String type; // 'video' atau 'audio'
  final String? thumbnailPath;
  final String? artist;
  final String? album;
  final String? coverArtPath;
  final DateTime lastModified;
  final DateTime? addedAt;
  final bool isFavorite;

  const MediaItem({
    this.id,
    required this.path,
    required this.name,
    this.folderPath,
    required this.sizeBytes,
    this.durationMs,
    required this.type,
    this.thumbnailPath,
    this.artist,
    this.album,
    this.coverArtPath,
    required this.lastModified,
    this.addedAt,
    this.isFavorite = false,
  });

  // -- Ekstensi file yang didukung --

  /// Ekstensi video yang didukung aplikasi.
  static const List<String> supportedVideoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'flv', 'wmv', 'webm', '3gp',
  ];

  /// Ekstensi audio yang didukung aplikasi.
  static const List<String> supportedAudioExtensions = [
    'mp3', 'flac', 'aac', 'ogg', 'wav', 'wma', 'm4a', 'opus',
  ];

  /// Semua ekstensi media yang didukung (video + audio).
  static List<String> get supportedExtensions => [
    ...supportedVideoExtensions,
    ...supportedAudioExtensions,
  ];

  // -- Factory constructors --

  /// Membuat [MediaItem] dari Map (biasanya hasil query database).
  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'] as int?,
      path: map['path'] as String,
      name: map['name'] as String,
      folderPath: map['folder_path'] as String?,
      sizeBytes: map['size_bytes'] as int,
      durationMs: map['duration_ms'] as int?,
      type: map['type'] as String,
      thumbnailPath: map['thumbnail_path'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      coverArtPath: map['cover_art_path'] as String?,
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        map['last_modified'] as int,
      ),
      addedAt: map['added_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int)
          : null,
      isFavorite: map['is_favorite'] == 1,
    );
  }

  /// Konversi [MediaItem] ke Map untuk disimpan ke database.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'path': path,
      'name': name,
      'folder_path': folderPath,
      'size_bytes': sizeBytes,
      'duration_ms': durationMs,
      'type': type,
      'thumbnail_path': thumbnailPath,
      'artist': artist,
      'album': album,
      'cover_art_path': coverArtPath,
      'last_modified': lastModified.millisecondsSinceEpoch,
      'added_at': addedAt?.millisecondsSinceEpoch,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  /// Membuat salinan [MediaItem] dengan field yang diubah.
  MediaItem copyWith({
    int? id,
    String? path,
    String? name,
    String? folderPath,
    int? sizeBytes,
    int? durationMs,
    String? type,
    String? thumbnailPath,
    String? artist,
    String? album,
    String? coverArtPath,
    DateTime? lastModified,
    DateTime? addedAt,
  }) {
    return MediaItem(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      folderPath: folderPath ?? this.folderPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      durationMs: durationMs ?? this.durationMs,
      type: type ?? this.type,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverArtPath: coverArtPath ?? this.coverArtPath,
      lastModified: lastModified ?? this.lastModified,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  // -- Getters --

  /// Mendapatkan ekstensi file (tanpa titik, lowercase).
  String get extension => p.extension(path).replaceFirst('.', '').toLowerCase();

  /// Mendapatkan nama file tanpa ekstensi.
  String get nameWithoutExtension => p.basenameWithoutExtension(path);

  /// Apakah item ini adalah video.
  bool get isVideo => type == 'video';

  /// Apakah item ini adalah audio.
  bool get isAudio => type == 'audio';

  /// Mendapatkan ukuran file dalam format yang mudah dibaca.
  /// Contoh: "1.5 GB", "350.2 MB", "12.0 KB"
  String get formattedSize {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = sizeBytes.toDouble();
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    // Tampilkan tanpa desimal untuk Bytes, 1 desimal untuk lainnya
    if (unitIndex == 0) {
      return '${size.toInt()} ${units[unitIndex]}';
    }
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  /// Mendapatkan durasi dalam format yang mudah dibaca.
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

  /// Mendeteksi tipe media berdasarkan ekstensi file.
  /// Mengembalikan 'video', 'audio', atau 'unknown'.
  static String detectType(String filePath) {
    final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    if (supportedVideoExtensions.contains(ext)) return 'video';
    if (supportedAudioExtensions.contains(ext)) return 'audio';
    return 'unknown';
  }

  /// Mengecek apakah file path memiliki ekstensi yang didukung.
  static bool isSupported(String filePath) {
    final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    return supportedExtensions.contains(ext);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItem &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'MediaItem(name: $name, type: $type, path: $path)';
}
