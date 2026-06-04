// Widget kontrol pemutaran media - overlay bar untuk player
// Mendukung auto-hide, animasi appear/disappear, speed selector,
// dan seek slider dengan desain premium

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:media_player/providers/player_provider.dart';
import 'package:media_player/providers/playlist_provider.dart';
import 'package:media_player/providers/history_provider.dart';

/// Widget overlay kontrol pemutaran media.
class PlayerControls extends StatefulWidget {
  final VoidCallback? onEqualizerTap;
  final VoidCallback? onPlaylistTap;
  final VoidCallback? onBackTap;

  const PlayerControls({
    super.key,
    this.onEqualizerTap,
    this.onPlaylistTap,
    this.onBackTap,
  });

  @override
  State<PlayerControls> createState() => PlayerControlsState();
}

class PlayerControlsState extends State<PlayerControls>
    with TickerProviderStateMixin {
  bool _visible = true;
  Timer? _hideTimer;
  double? _dragValue;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideTopAnim;
  late final Animation<Offset> _slideBottomAnim;

  late final AnimationController _rippleController;
  late final Animation<double> _rippleAnim;

  static const _purple = Color(0xFF7B2FBE);
  static const _teal = Color(0xFF00BFA5);

  static const _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0];

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _slideTopAnim = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _slideBottomAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _rippleAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _hideControls();
    });
  }

  void _showControls() {
    if (!_visible) {
      setState(() => _visible = true);
      _animController.forward();
    }
    _startHideTimer();
  }

  void _hideControls() {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  void toggleVisibility() {
    if (_visible) {
      _hideTimer?.cancel();
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _onInteraction() {
    _startHideTimer();
  }

  void _showSpeedSelector(BuildContext context) {
    _hideTimer?.cancel();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SpeedSelectorSheet(
        currentSpeed: playerProvider.playbackSpeed,
        onSpeedSelected: (speed) {
          playerProvider.setPlaybackSpeed(speed);
          Navigator.pop(ctx);
          _startHideTimer();
        },
      ),
    );
  }

  /// Format Duration ke string MM:SS atau HH:MM:SS
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
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: toggleVisibility,
      child: _visible
          ? FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: SafeArea(
                  child: Column(
                    children: [
                      _buildTopBar(context),
                      const Spacer(),
                      _buildCenterControls(context),
                      const Spacer(),
                      _buildBottomBar(context),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.expand(),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SlideTransition(
      position: _slideTopAnim,
      child: Consumer<PlayerProvider>(
        builder: (_, player, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _buildIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => widget.onBackTap?.call(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  player.currentMediaName ?? 'Tidak ada media',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              _buildIconButton(
                icon: Icons.speed_rounded,
                label: '${player.playbackSpeed}x',
                onTap: () => _showSpeedSelector(context),
              ),
              _buildIconButton(
                icon: Icons.equalizer_rounded,
                onTap: () {
                  widget.onEqualizerTap?.call();
                  _onInteraction();
                },
              ),
              _buildIconButton(
                icon: Icons.queue_music_rounded,
                onTap: () {
                  widget.onPlaylistTap?.call();
                  _onInteraction();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterControls(BuildContext context) {
    return Consumer2<PlayerProvider, PlaylistProvider>(
      builder: (_, player, playlist, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous
          _buildCircleControl(
            icon: Icons.skip_previous_rounded,
            size: 42,
            onTap: () {
              final prev = playlist.previous();
              if (prev != null) {
                _saveHistory(context);
                player.openMedia(prev.path, isVideo: prev.isVideo);
              }
              _onInteraction();
            },
          ),
          const SizedBox(width: 32),

          // Play / Pause
          GestureDetector(
            onTap: () {
              player.togglePlayPause();
              _rippleController.forward(from: 0);
              _onInteraction();
            },
            child: AnimatedBuilder(
              animation: _rippleAnim,
              builder: (_, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_rippleController.isAnimating)
                      Transform.scale(
                        scale: _rippleAnim.value,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _teal.withValues(
                                  alpha: 1.0 - _rippleController.value),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [_purple, _teal],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _teal.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          key: ValueKey(player.isPlaying),
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 32),

          // Next
          _buildCircleControl(
            icon: Icons.skip_next_rounded,
            size: 42,
            onTap: () {
              final nxt = playlist.next();
              if (nxt != null) {
                _saveHistory(context);
                player.openMedia(nxt.path, isVideo: nxt.isVideo);
              }
              _onInteraction();
            },
          ),
        ],
      ),
    );
  }

  void _saveHistory(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final history = Provider.of<HistoryProvider>(context, listen: false);
    final path = player.currentMediaPath;
    if (path != null) {
      history.addToHistory(
        path,
        path.split(RegExp(r'[/\\]')).last,
        durationMs: player.duration.inMilliseconds,
      );
      history.updatePosition(path, player.position.inMilliseconds);
    }
  }

  Widget _buildBottomBar(BuildContext context) {
    return SlideTransition(
      position: _slideBottomAnim,
      child: Consumer<PlayerProvider>(
        builder: (_, player, _) {
          final position = player.position;
          final duration = player.duration;
          final posMs = position.inMilliseconds.toDouble();
          final durMs = duration.inMilliseconds.toDouble();

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                      elevation: 4,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    activeTrackColor: _teal,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                    thumbColor: _teal,
                    overlayColor: _teal.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: durMs > 0 ? (_dragValue ?? posMs).clamp(0, durMs) : 0,
                    max: durMs > 0 ? durMs : 1,
                    onChanged: durMs > 0 ? (value) {
                      setState(() => _dragValue = value);
                    } : null,
                    onChangeStart: (_) => _hideTimer?.cancel(),
                    onChangeEnd: (value) async {
                      final targetMs = value.toInt();
                      await player.seekTo(Duration(milliseconds: targetMs));
                      if (mounted) {
                        setState(() => _dragValue = null);
                        _startHideTimer();
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDur(Duration(milliseconds: (_dragValue ?? posMs).toInt())),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        _formatDur(duration),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    String? label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 24),
              if (label != null) ...[
                const SizedBox(width: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: _teal.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleControl({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(size),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.9),
            size: size * 0.55,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Speed Selector Bottom Sheet
// =============================================================================

class _SpeedSelectorSheet extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;

  static const _purple = Color(0xFF7B2FBE);
  static const _teal = Color(0xFF00BFA5);
  static const _bgCard = Color(0xFF1A1A2E);

  const _SpeedSelectorSheet({
    required this.currentSpeed,
    required this.onSpeedSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgCard.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Kecepatan Pemutaran',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: PlayerControlsState._speedOptions.map((speed) {
                final isActive = (speed - currentSpeed).abs() < 0.01;
                return GestureDetector(
                  onTap: () => onSpeedSelected(speed),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 68,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: isActive
                          ? const LinearGradient(colors: [_purple, _teal])
                          : null,
                      color: isActive
                          ? null
                          : Colors.white.withValues(alpha: 0.07),
                      border: Border.all(
                        color: isActive
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: _teal.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${speed}x',
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
