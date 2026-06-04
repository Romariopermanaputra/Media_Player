import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'dart:io';

import 'package:media_player/models/media_item.dart';
import 'package:media_player/providers/playlist_provider.dart';
import 'package:media_player/providers/history_provider.dart';
import 'package:media_player/widgets/gesture_overlay.dart';
import 'package:media_player/widgets/equalizer_panel.dart';
import 'package:media_player/widgets/playlist_panel.dart';
import 'package:media_player/providers/player_provider.dart';
import 'package:media_player/services/database_helper.dart';

/// Warna tema premium
const _kPurpleAccent = Color(0xFF7B2FBE);
const _kTealAccent = Color(0xFF0ABAB5);

/// PlayerScreen — layar pemutar media penuh.
class PlayerScreen extends StatefulWidget {
  final String filePath;
  final bool isVideo;
  final List<MediaItem>? playlist;
  final Duration? startPosition;

  const PlayerScreen({
    super.key,
    required this.filePath,
    this.isVideo = false,
    this.playlist,
    this.startPosition,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  // ── Player media_kit
  Player get _player => Provider.of<PlayerProvider>(context, listen: false).player;
  VideoController get _videoController => Provider.of<PlayerProvider>(context, listen: false).videoController!;

  // ── State UI
  bool _controlsVisible = true;
  bool _isOrientationLocked = false;
  bool _showEqualizer = false;
  bool _showPlaylist = false;
  Timer? _hideControlsTimer;

  // ── Animasi
  late final AnimationController _controlsFadeController;
  late final Animation<double> _controlsFadeAnim;
  late final AnimationController _titleSlideController;
  late final Animation<Offset> _titleSlideAnim;
  late final AnimationController _equalizerPulseController;

  // ── Stream subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // ── Info playback
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  
  // ── Cover art
  Uint8List? _albumArt;
  String? _lastArtPath;

  @override
  void initState() {
    super.initState();

    _controlsFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _controlsFadeAnim = CurvedAnimation(
      parent: _controlsFadeController,
      curve: Curves.easeInOut,
    );

    _titleSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _titleSlideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _titleSlideController,
      curve: Curves.easeOutCubic,
    ));

    _equalizerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlayer();
      _setupOrientation();
    });
  }

  @override
  void dispose() {
    _saveCurrentPosition();
    _hideControlsTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _controlsFadeController.dispose();
    _titleSlideController.dispose();
    _equalizerPulseController.dispose();

    WakelockPlus.disable();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Do NOT dispose _player because it is managed by PlayerProvider
    // _player.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    await WakelockPlus.enable();
    if (!mounted) return;

    // Setup playlist jika ada
    if (widget.playlist != null && widget.playlist!.isNotEmpty) {
      final playlistProv =
          Provider.of<PlaylistProvider>(context, listen: false);
      playlistProv.clearPlaylist();
      playlistProv.addMultiple(widget.playlist!);
      
      final idx = widget.playlist!.indexWhere((m) => m.path == widget.filePath);
      if (idx != -1) {
        playlistProv.setCurrentIndex(idx);
      }
    }

    // Buka dan putar media via PlayerProvider
    final playerProv = Provider.of<PlayerProvider>(context, listen: false);
    if (!playerProv.isInitialized) {
      playerProv.init();
    }
    
    // Hanya buka media baru jika path berbeda dari yang sedang diputar
    if (playerProv.currentMediaPath != widget.filePath) {
      await playerProv.openMedia(widget.filePath, isVideo: widget.isVideo);
    }
    
    _loadCoverArt(playerProv.currentMediaPath ?? widget.filePath);

    // Seek ke posisi terakhir jika ada
    if (widget.startPosition != null &&
        widget.startPosition! > Duration.zero) {
      await _player.seek(widget.startPosition!);
    }

    // Note: metadata sudah diupdate oleh PlayerProvider.openMedia dari DB

    // Subscribe ke stream state player
    _subscriptions.addAll([
      _player.stream.position.listen((pos) {
        if (mounted) setState(() => _position = pos);
      }),
      _player.stream.duration.listen((dur) {
        if (mounted) setState(() => _duration = dur);
      }),
      _player.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      }),
      _player.stream.playlist.listen((playlist) {
        // Reload cover art if track changes
        if (!mounted) return;
        final playerProv = Provider.of<PlayerProvider>(context, listen: false);
        if (playerProv.currentMediaPath != null) {
          _loadCoverArt(playerProv.currentMediaPath!);
        }
      }),
      _player.stream.buffering.listen((buffering) {
        if (mounted) setState(() => _isBuffering = buffering);
      }),
      _player.stream.completed.listen((completed) {
        if (completed) _onPlaybackCompleted();
      }),
    ]);

    _showControls();
    _titleSlideController.forward();
  }

  void _setupOrientation() {
    if (widget.isVideo) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _loadCoverArt(String path) async {
    if (_lastArtPath == path) return;
    _lastArtPath = path;
    if (widget.isVideo) return; // Skip for video
    
    try {
      final metadata = await MetadataRetriever.fromFile(File(path));
      if (mounted) {
        setState(() {
          _albumArt = metadata.albumArt;
        });
      }
    } catch (e) {
      debugPrint('Failed to extract metadata: $e');
    }
  }

  void _toggleOrientationLock() {
    setState(() {
      _isOrientationLocked = !_isOrientationLocked;
      if (_isOrientationLocked) {
        final currentOrientation = MediaQuery.of(context).orientation;
        if (currentOrientation == Orientation.landscape) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
        }
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  // ── Controls visibility
  void _showControls() {
    _hideControlsTimer?.cancel();
    _controlsFadeController.forward();
    setState(() => _controlsVisible = true);

    if (_isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          _controlsFadeController.reverse();
          setState(() => _controlsVisible = false);
        }
      });
    }
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideControlsTimer?.cancel();
      _controlsFadeController.reverse();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  // ── Playback controls
  void _togglePlayPause() {
    Provider.of<PlayerProvider>(context, listen: false).player.playOrPause();
    _showControls();
  }

  void _seekTo(Duration position) {
    Provider.of<PlayerProvider>(context, listen: false).player.seek(position);
    _showControls();
  }

  void _seekRelative(Duration offset) {
    final newPos = _position + offset;
    final clamped = Duration(
      milliseconds: newPos.inMilliseconds.clamp(0, _duration.inMilliseconds),
    );
    Provider.of<PlayerProvider>(context, listen: false).player.seek(clamped);
    _showControls();
  }

  void _setVolume(double volume) {
    Provider.of<PlayerProvider>(context, listen: false).player.setVolume(volume.clamp(0, 100));
  }

  void _onPlaybackCompleted() {
    final playlistProv =
        Provider.of<PlaylistProvider>(context, listen: false);
    final nextItem = playlistProv.next();
    if (nextItem != null) {
      _saveCurrentPosition();
      Provider.of<PlayerProvider>(context, listen: false)
          .openMedia(nextItem.path, isVideo: nextItem.isVideo);
    } else {
      _showControls();
    }
  }

  void _saveCurrentPosition() {
    try {
      final playerProv = Provider.of<PlayerProvider>(context, listen: false);
      final historyProv = Provider.of<HistoryProvider>(context, listen: false);
      
      final path = playerProv.currentMediaPath ?? widget.filePath;
      final fileName = path.split(RegExp(r'[/\\]')).last;
      
      historyProv.addToHistory(
        path,
        fileName,
        durationMs: _duration.inMilliseconds,
      );
      historyProv.updatePosition(
        path,
        _position.inMilliseconds,
      );
    } catch (e) {
      debugPrint('Gagal menyimpan posisi: $e');
    }
  }

  /// Format Duration → "MM:SS" atau "H:MM:SS"
  String _formatDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '${h.toString().padLeft(2, '0')}:$mm:$ss';
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveCurrentPosition();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Video / Audio art
            widget.isVideo ? _buildVideoLayer() : _buildAudioLayer(),

            // Layer 2: Gesture overlay
            GestureOverlay(
              onTap: _toggleControls,
              onDoubleTapLeft: () =>
                  _seekRelative(const Duration(seconds: -10)),
              onDoubleTapRight: () =>
                  _seekRelative(const Duration(seconds: 10)),
              onVerticalDragLeft: (delta) => _setVolume(
                (_player.state.volume - delta * 0.5).clamp(0, 100),
              ),
              onVerticalDragRight: (delta) {},
              onHorizontalDrag: (delta) {
                final seekAmount = Duration(seconds: (delta * 0.1).round());
                _seekRelative(seekAmount);
              },
            ),

            // Layer 3: Controls overlay
            FadeTransition(
              opacity: _controlsFadeAnim,
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: _buildControlsOverlay(),
              ),
            ),

            // Layer 4: Buffering indicator
            if (_isBuffering) _buildBufferingIndicator(),

            // Layer 5: Panel Equalizer
            if (_showEqualizer) _buildEqualizerPanel(),

            // Layer 6: Panel Playlist
            if (_showPlaylist) _buildPlaylistPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoLayer() {
    return Video(
      controller: _videoController,
      fill: Colors.black,
      controls: _noVideoControls,
    );
  }

  Widget _buildAudioLayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background fallback + animasi pulse equalizer
        AnimatedBuilder(
          animation: _equalizerPulseController,
          builder: (context, child) {
            final pulse = _equalizerPulseController.value;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _kPurpleAccent.withValues(alpha: 0.15 + pulse * 0.1),
                    const Color(0xFF1A1A2E),
                    const Color(0xFF0D0D0D),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.music_note_rounded,
                  size: 150 + pulse * 20,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            );
          },
        ),
        
        // Menampilkan cover art dari MetadataRetriever atau gradient default
        Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 32, right: 32, top: 80, bottom: 250),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  color: Colors.black26, 
                  child: _albumArt != null
                      ? Image.memory(
                          _albumArt!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_kPurpleAccent.withValues(alpha: 0.5), _kTealAccent.withValues(alpha: 0.5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.music_note_rounded, size: 80, color: Colors.white54),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0.95),
          ],
          stops: const [0.0, 0.2, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ─ Top bar
            _buildTopBar(),
            const Spacer(),
            
            // ─ Song Info (Hanya untuk Audio)
            if (!widget.isVideo) _buildSongInfo(),
            
            // ─ Seek bar + time
            _buildBottomBar(),
            
            // ─ Controls Row
            _buildCenterControls(),
            
            // ─ Bottom status
            if (!widget.isVideo) _buildBottomStatus(),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSongInfo() {
    final playerProv = Provider.of<PlayerProvider>(context);
    final currentPath = playerProv.currentMediaPath ?? widget.filePath;
    final fileName = currentPath.split(RegExp(r'[/\\]')).last;
    final nameWithoutExt = playerProv.currentMediaName ??
        (fileName.contains('.')
            ? fileName.substring(0, fileName.lastIndexOf('.'))
            : fileName);
        
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FutureBuilder<bool>(
            future: () async {
              final activePath = Provider.of<PlayerProvider>(context, listen: false).currentMediaPath ?? widget.filePath;
              final media = await DatabaseHelper.instance.getMediaByPath(activePath);
              return media?.isFavorite ?? false;
            }(),
            builder: (context, snapshot) {
              final isFav = snapshot.data ?? false;
              return IconButton(
                icon: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  color: isFav ? Colors.red : Colors.white.withValues(alpha: 0.6),
                ),
                onPressed: () async {
                  final activePath = Provider.of<PlayerProvider>(context, listen: false).currentMediaPath ?? widget.filePath;
                  final messenger = ScaffoldMessenger.of(context);
                  await DatabaseHelper.instance.toggleFavorite(activePath, !isFav);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(!isFav ? 'Added to favorites' : 'Removed from favorites')),
                  );
                  setState(() {});
                },
              );
            },
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  nameWithoutExt,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // Show artist if available from DB
                FutureBuilder<String>(
                  future: () async {
                    final activePath = Provider.of<PlayerProvider>(context, listen: false).currentMediaPath ?? widget.filePath;
                    final media = await DatabaseHelper.instance.getMediaByPath(activePath);
                    return media?.artist ?? 'Unknown Artist';
                  }(),
                  builder: (context, snap) {
                    return Text(
                      snap.data ?? 'Loading...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6), 
                        fontSize: 14,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
            onPressed: () => setState(() => _showPlaylist = !_showPlaylist),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final playerProv = Provider.of<PlayerProvider>(context);
    final currentPath = playerProv.currentMediaPath ?? widget.filePath;
    final folderName = currentPath.split(RegExp(r'[/\\]')).reversed.elementAt(1);
    
    return SlideTransition(
      position: _titleSlideAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'PLAYING FROM',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), 
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    folderName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded,
                  color: Colors.white70, size: 24),
              onPressed: () {},
            ),
            if (widget.isVideo)
              IconButton(
                icon: Icon(
                  _isOrientationLocked
                      ? Icons.screen_lock_rotation_rounded
                      : Icons.screen_rotation_rounded,
                  color:
                      _isOrientationLocked ? _kTealAccent : Colors.white70,
                  size: 22,
                ),
                onPressed: _toggleOrientationLock,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    final playlist = Provider.of<PlaylistProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Equalizer atau repeat mode
          IconButton(
            icon: const Icon(Icons.equalizer_rounded, color: Colors.white),
            iconSize: 24,
            onPressed: () => setState(() => _showEqualizer = !_showEqualizer),
          ),
          
          // Prev
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
            iconSize: 36,
            onPressed: playlist.hasPrevious ? () {
              final prevItem = playlist.previous();
              if (prevItem != null) {
                _saveCurrentPosition();
                Provider.of<PlayerProvider>(context, listen: false)
                    .openMedia(prevItem.path, isVideo: prevItem.isVideo);
              }
            } : null,
          ),
          
          // Play/Pause (Outline circle style)
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                color: Colors.black.withValues(alpha: 0.3),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(_isPlaying),
                  color: Colors.white, size: 36,
                ),
              ),
            ),
          ),
          
          // Next
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
            iconSize: 36,
            onPressed: playlist.hasNext ? () {
              final nextItem = playlist.next();
              if (nextItem != null) {
                _saveCurrentPosition();
                Provider.of<PlayerProvider>(context, listen: false)
                    .openMedia(nextItem.path, isVideo: nextItem.isVideo);
              }
            } : null,
          ),
          
          // Shuffle
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded, 
              color: playlist.isShuffled ? const Color(0xFFE8B931) : Colors.white
            ),
            iconSize: 24,
            onPressed: () => playlist.toggleShuffle(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final posMs = _position.inMilliseconds.toDouble();
    final durMs = _duration.inMilliseconds.toDouble();
    // Yellow/gold color for seekbar
    const trackColor = Color(0xFFE8B931);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8, elevation: 4,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: trackColor,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
              thumbColor: Colors.white,
              overlayColor: trackColor.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: durMs > 0 ? posMs.clamp(0, durMs) : 0,
              max: durMs > 0 ? durMs : 1,
              onChanged: (value) {
                _seekTo(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDur(_position),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12, fontWeight: FontWeight.w500,
                    )),
                Text(_formatDur(_duration),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12, fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottomStatus() {
    final playlist = Provider.of<PlaylistProvider>(context);
    final currentIdx = playlist.currentIndex + 1;
    final total = playlist.length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.volume_up_rounded, color: Colors.white.withValues(alpha: 0.5), size: 20),
          Text(
            '$currentIdx/$total',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          // Placeholder right side for balance
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 40, height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(_kTealAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildEqualizerPanel() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 200) {
            setState(() => _showEqualizer = false);
          }
        },
        child: AnimatedSlide(
          offset: _showEqualizer ? Offset.zero : const Offset(0, 1),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: EqualizerPanel(
            onClose: () => setState(() => _showEqualizer = false),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistPanel() {
    return Positioned(
      top: 0, bottom: 0, right: 0,
      child: AnimatedSlide(
        offset: _showPlaylist ? Offset.zero : const Offset(1, 0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.75,
          child: PlaylistPanel(
            currentFilePath: widget.filePath, // Panel also checks PlayerProvider now
            onItemTap: (index) {
              final playlistProv = Provider.of<PlaylistProvider>(context, listen: false);
              final item = playlistProv.playAt(index);
              Provider.of<PlayerProvider>(context, listen: false).openMedia(item.path, isVideo: item.isVideo);
              setState(() => _showPlaylist = false);
            },
            onClose: () => setState(() => _showPlaylist = false),
          ),
        ),
      ),
    );
  }
}

/// Kontrol kosong — karena kita pakai overlay sendiri
Widget _noVideoControls(VideoState state) => const SizedBox.shrink();
