import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Handler untuk kontrol pemutaran media di background.
class MediaAudioHandler extends BaseAudioHandler {
  Player? _player;
  final List<StreamSubscription> _subscriptions = [];
  
  MediaAudioHandler() {
    _initAudioSession();
  }
  
  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    
    // Listen for audio interruptions (e.g., phone calls)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // Optional: lower volume
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // Optional: restore volume
            break;
          case AudioInterruptionType.pause:
            play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });
  }

  void setPlayer(Player? player) {
    // Clear old subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    _player = player;

    if (player != null) {
      // Listen to player state and broadcast to audio_service
      _subscriptions.addAll([
        player.stream.playing.listen((playing) {
          _updatePlaybackState();
        }),
        player.stream.position.listen((position) {
          _updatePlaybackState();
        }),
        player.stream.duration.listen((duration) {
          final meta = mediaItem.value;
          if (meta != null && meta.duration != duration) {
            mediaItem.add(meta.copyWith(duration: duration));
          }
          _updatePlaybackState();
        }),
        player.stream.buffer.listen((buffer) {
          _updatePlaybackState();
        }),
      ]);
    } else {
      // Reset state
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
    }
  }

  void updateMediaMetadata(MediaItem item) {
    mediaItem.add(item);
  }

  void _updatePlaybackState() {
    if (_player == null) return;
    
    final player = _player!;
    final playing = player.state.playing;
    final position = player.state.position;
    final bufferedPosition = player.state.buffer;
    final speed = player.state.rate;
    final completed = player.state.completed;

    AudioProcessingState processingState;
    if (completed) {
      processingState = AudioProcessingState.completed;
    } else if (player.state.buffering) {
      processingState = AudioProcessingState.buffering;
    } else {
      processingState = AudioProcessingState.ready;
    }

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: processingState,
      playing: playing,
      updatePosition: position,
      bufferedPosition: bufferedPosition,
      speed: speed,
    ));
  }

  @override
  Future<void> play() async => await _player?.play();

  @override
  Future<void> pause() async => await _player?.pause();

  @override
  Future<void> seek(Duration position) async => await _player?.seek(position);

  @override
  Future<void> stop() async {
    await _player?.stop();
    await super.stop();
  }
}

class AudioHandler {
  AudioHandler._();
  static final AudioHandler instance = AudioHandler._();

  MediaAudioHandler? _handler;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    
    debugPrint('[AudioHandler] Inisialisasi audio handler...');
    _handler = await AudioService.init(
      builder: () => MediaAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.media.media_player.channel.audio',
        androidNotificationChannelName: 'Media Player',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    
    _isInitialized = true;
    debugPrint('[AudioHandler] Audio handler siap.');
  }

  void setPlayer(Player? player) {
    _handler?.setPlayer(player);
  }

  void updateMediaMetadata({
    required String id,
    required String title,
    String? artist,
    String? album,
    String? artworkPath,
    Duration? duration,
  }) {
    if (_handler == null) return;
    
    _handler!.updateMediaMetadata(MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      artUri: artworkPath != null ? Uri.file(artworkPath) : null,
      duration: duration,
    ));
  }

  Future<void> stop() async {
    await _handler?.stop();
  }
}
