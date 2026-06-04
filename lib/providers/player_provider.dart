import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_player/services/audio_handler.dart';
import 'package:media_player/services/database_helper.dart';
import 'package:media_player/models/history_item.dart';

/// Provider untuk mengelola state pemutaran media (audio/video).
///
/// Menggunakan `media_kit` sebagai engine pemutaran. Menyediakan kontrol penuh
/// termasuk play, pause, seek, volume, kecepatan, dan fullscreen.
class PlayerProvider extends ChangeNotifier {
  VoidCallback? onCompleted;

  // ──────────────────────────── Player core ────────────────────────────
  Player? _player;
  VideoController? _videoController;

  Player get player {
    assert(_player != null, 'PlayerProvider belum di-init. Panggil init() dulu.');
    return _player!;
  }

  VideoController? get videoController => _videoController;

  // ──────────────────────────── State fields ───────────────────────────
  bool _isPlaying = false;
  bool _isVideo = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100.0;
  double _brightness = 1.0;
  double _playbackSpeed = 1.0;
  bool _isFullScreen = false;
  bool _showControls = true;
  String? _currentMediaPath;
  String? _currentMediaName;
  bool _isInitialized = false;

  // ──────────────────────────── Getters ─────────────────────────────────
  bool get isPlaying => _isPlaying;
  bool get isVideo => _isVideo;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  double get brightness => _brightness;
  double get playbackSpeed => _playbackSpeed;
  bool get isFullScreen => _isFullScreen;
  bool get showControls => _showControls;
  String? get currentMediaPath => _currentMediaPath;
  String? get currentMediaName => _currentMediaName;
  bool get isInitialized => _isInitialized;

  /// Progress pemutaran dalam bentuk persentase (0.0 – 1.0).
  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Sisa durasi yang belum diputar.
  Duration get remaining => _duration - _position;

  // ──────────────────────────── Subscriptions ──────────────────────────
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  // ──────────────────────────── Lifecycle ──────────────────────────────

  /// Inisialisasi player dan mulai mendengarkan stream perubahan state.
  ///
  /// Harus dipanggil sebelum menggunakan method lain pada provider ini.
  void init() {
    if (_isInitialized) return;

    _player = Player();
    _videoController = VideoController(_player!);

    // Pasang player ke AudioHandler (background playback)
    AudioHandler.instance.setPlayer(_player);

    _listenToStreams();
    _isInitialized = true;
    notifyListeners();
  }

  /// Subscribe ke semua stream dari [Player] agar UI selalu sinkron.
  void _listenToStreams() {
    final p = _player!;

    // Stream posisi pemutaran
    _subscriptions.add(
      p.stream.position.listen((pos) {
        _position = pos;
        notifyListeners();
      }),
    );

    // Stream total durasi media
    _subscriptions.add(
      p.stream.duration.listen((dur) {
        _duration = dur;
        notifyListeners();
      }),
    );

    // Stream status playing/paused
    _subscriptions.add(
      p.stream.playing.listen((playing) {
        _isPlaying = playing;
        notifyListeners();
      }),
    );

    // Stream ketika media selesai diputar
    _subscriptions.add(
      p.stream.completed.listen((completed) {
        if (completed) {
          _isPlaying = false;
          _position = _duration;
          notifyListeners();
          onCompleted?.call();
        }
      }),
    );

    // Stream volume
    _subscriptions.add(
      p.stream.volume.listen((vol) {
        _volume = vol;
        notifyListeners();
      }),
    );

    // Stream playback speed / rate
    _subscriptions.add(
      p.stream.rate.listen((rate) {
        _playbackSpeed = rate;
        notifyListeners();
      }),
    );
  }

  // ──────────────────────────── Playback control ──────────────────────

  /// Buka file media dari [path].
  ///
  /// Secara default dianggap video. Jika [isVideo] false, controller video
  /// tidak akan digunakan untuk render. Media otomatis diputar setelah dibuka.
  Future<void> openMedia(String path, {bool isVideo = true}) async {
    _ensureInitialized();

    _currentMediaPath = path;
    _currentMediaName = _extractFileName(path);
    _isVideo = isVideo;
    _position = Duration.zero;
    _duration = Duration.zero;

    final media = await DatabaseHelper.instance.getMediaByPath(path);
    
    AudioHandler.instance.updateMediaMetadata(
      id: path,
      title: media?.name ?? _currentMediaName ?? 'Unknown',
      artist: media?.artist,
      album: media?.album,
      artworkPath: media?.coverArtPath ?? media?.thumbnailPath,
    );

    // Tambahkan ke DB History
    if (media != null) {
      await DatabaseHelper.instance.insertHistory(HistoryItem(
        mediaPath: path,
        mediaName: media.name,
        lastPositionMs: 0,
        durationMs: media.durationMs,
        thumbnailPath: media.coverArtPath ?? media.thumbnailPath,
        playedAt: DateTime.now(),
      ));
    } else {
      await DatabaseHelper.instance.insertHistory(HistoryItem(
        mediaPath: path,
        mediaName: _currentMediaName ?? 'Unknown',
        lastPositionMs: 0,
        playedAt: DateTime.now(),
      ));
    }

    // Buka media dan langsung putar (autoStart)
    await _player!.open(Media(path));
    // Terapkan kembali volume & speed yang dipilih user
    await _player!.setVolume(_volume);
    await _player!.setRate(_playbackSpeed);

    notifyListeners();
  }

  /// Mulai / lanjutkan pemutaran.
  Future<void> play() async {
    _ensureInitialized();
    await _player!.play();
  }

  /// Jeda pemutaran.
  Future<void> pause() async {
    _ensureInitialized();
    await _player!.pause();
  }

  /// Toggle antara play dan pause.
  Future<void> togglePlayPause() async {
    _ensureInitialized();
    await _player!.playOrPause();
  }

  /// Lompat ke posisi [position] tertentu.
  Future<void> seekTo(Duration position) async {
    _ensureInitialized();
    final clamped = Duration(
      milliseconds: position.inMilliseconds.clamp(0, _duration.inMilliseconds),
    );
    await _player!.seek(clamped);
  }

  /// Seek relatif sebanyak [seconds] detik (positif = maju, negatif = mundur).
  Future<void> seekRelative(int seconds) async {
    _ensureInitialized();
    final target = _position + Duration(seconds: seconds);
    await seekTo(target);
  }

  // ──────────────────────────── Volume & speed ─────────────────────────

  /// Atur volume pemutaran (0 – 100).
  Future<void> setVolume(double vol) async {
    _ensureInitialized();
    _volume = vol.clamp(0.0, 100.0);
    await _player!.setVolume(_volume);
    notifyListeners();
  }

  /// Atur kecepatan pemutaran. Nilai normal = 1.0.
  Future<void> setPlaybackSpeed(double speed) async {
    _ensureInitialized();
    if (speed <= 0) return;
    _playbackSpeed = speed;
    await _player!.setRate(_playbackSpeed);
    notifyListeners();
  }

  // ──────────────────────────── Brightness ─────────────────────────────

  /// Atur brightness overlay (0.0 – 1.0). Ini hanya state lokal; implementasi
  /// brightness layar sesungguhnya bisa dilakukan di widget layer.
  void setBrightness(double value) {
    _brightness = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  // ──────────────────────────── Fullscreen & Controls ──────────────────

  /// Atur mode fullscreen.
  void setFullScreen(bool value) {
    _isFullScreen = value;
    notifyListeners();
  }

  /// Toggle visibilitas kontrol player (show/hide overlay).
  void toggleControls() {
    _showControls = !_showControls;
    notifyListeners();
  }

  // ──────────────────────────── Helpers ─────────────────────────────────

  /// Ekstrak nama file dari path lengkap.
  String _extractFileName(String path) {
    final separator = path.contains('\\') ? '\\' : '/';
    final segments = path.split(separator);
    return segments.isNotEmpty ? segments.last : path;
  }

  /// Pastikan provider sudah diinisialisasi sebelum digunakan.
  void _ensureInitialized() {
    if (!_isInitialized || _player == null) {
      throw StateError(
        'PlayerProvider belum diinisialisasi. Panggil init() terlebih dahulu.',
      );
    }
  }

  // ──────────────────────────── Dispose ────────────────────────────────

  @override
  void dispose() {
    // Batalkan semua subscription stream
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    AudioHandler.instance.setPlayer(null);
    // Dispose player (melepas native resources)
    _player?.dispose();
    _player = null;
    _videoController = null;
    _isInitialized = false;

    super.dispose();
  }
}
