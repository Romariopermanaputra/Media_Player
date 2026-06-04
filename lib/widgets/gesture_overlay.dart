// Widget overlay gesture transparan untuk kontrol media via gestur
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Layer gestur transparan untuk mengontrol pemutaran media.
class GestureOverlay extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTapLeft;
  final VoidCallback? onDoubleTapRight;
  final ValueChanged<double>? onVerticalDragLeft;
  final ValueChanged<double>? onVerticalDragRight;
  final ValueChanged<double>? onHorizontalDrag;

  const GestureOverlay({
    super.key,
    this.onTap,
    this.onDoubleTapLeft,
    this.onDoubleTapRight,
    this.onVerticalDragLeft,
    this.onVerticalDragRight,
    this.onHorizontalDrag,
  });

  @override
  State<GestureOverlay> createState() => _GestureOverlayState();
}

class _GestureOverlayState extends State<GestureOverlay>
    with TickerProviderStateMixin {
  _DragType _dragType = _DragType.none;
  Offset _dragStart = Offset.zero;
  bool _isDragging = false;

  // Visual indicator state
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  bool _showSeekIndicator = false;
  double _indicatorValue = 0.5;
  int _seekSeconds = 0;

  bool _showSkipForward = false;
  bool _showSkipBackward = false;

  Timer? _indicatorTimer;

  late final AnimationController _skipForwardController;
  late final AnimationController _skipBackwardController;
  late final Animation<double> _skipForwardAnim;
  late final Animation<double> _skipBackwardAnim;

  static const _dragThreshold = 15.0;
  static const _purple = Color(0xFF7B2FBE);
  static const _teal = Color(0xFF00BFA5);

  @override
  void initState() {
    super.initState();

    _skipForwardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _skipForwardAnim = CurvedAnimation(
      parent: _skipForwardController,
      curve: Curves.easeOut,
    );
    _skipForwardController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showSkipForward = false);
      }
    });

    _skipBackwardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _skipBackwardAnim = CurvedAnimation(
      parent: _skipBackwardController,
      curve: Curves.easeOut,
    );
    _skipBackwardController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showSkipBackward = false);
      }
    });
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _skipForwardController.dispose();
    _skipBackwardController.dispose();
    super.dispose();
  }

  _DragType _determineDragType(Offset startPos, Offset delta) {
    final screenWidth = MediaQuery.of(context).size.width;
    final absDx = delta.dx.abs();
    final absDy = delta.dy.abs();

    if (absDx > absDy && absDx > _dragThreshold) {
      return _DragType.seek;
    } else if (absDy > absDx && absDy > _dragThreshold) {
      if (startPos.dx < screenWidth / 2) {
        return _DragType.volume;
      } else {
        return _DragType.brightness;
      }
    }
    return _DragType.none;
  }

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.localPosition;
    _isDragging = false;
    _dragType = _DragType.none;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final delta = details.localPosition - _dragStart;

    if (_dragType == _DragType.none) {
      _dragType = _determineDragType(_dragStart, delta);
      if (_dragType == _DragType.none) return;
      _isDragging = true;
    }

    if (!_isDragging) return;

    final screenHeight = MediaQuery.of(context).size.height;

    switch (_dragType) {
      case _DragType.volume:
        final volumeDelta = -delta.dy / (screenHeight * 0.5);
        _indicatorValue = (0.5 + volumeDelta).clamp(0.0, 1.0);
        widget.onVerticalDragLeft?.call(details.delta.dy);
        setState(() => _showVolumeIndicator = true);

      case _DragType.brightness:
        final brightDelta = -delta.dy / (screenHeight * 0.5);
        _indicatorValue = (0.5 + brightDelta).clamp(0.0, 1.0);
        widget.onVerticalDragRight?.call(details.delta.dy);
        setState(() => _showBrightnessIndicator = true);

      case _DragType.seek:
        _seekSeconds = (delta.dx / 3).round();
        widget.onHorizontalDrag?.call(delta.dx);
        setState(() => _showSeekIndicator = true);

      case _DragType.none:
        break;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showVolumeIndicator = false;
          _showBrightnessIndicator = false;
          _showSeekIndicator = false;
        });
      }
    });

    _isDragging = false;
    _dragType = _DragType.none;
  }

  void _onDoubleTapLeft() {
    widget.onDoubleTapLeft?.call();
    setState(() => _showSkipBackward = true);
    _skipBackwardController.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  void _onDoubleTapRight() {
    widget.onDoubleTapRight?.call();
    setState(() => _showSkipForward = true);
    _skipForwardController.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: SizedBox.expand(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: _onDoubleTapLeft,
                    onTap: widget.onTap,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: _onDoubleTapRight,
                    onTap: widget.onTap,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Volume indicator
        if (_showVolumeIndicator)
          Positioned(
            left: 24,
            top: size.height * 0.2,
            bottom: size.height * 0.2,
            child: _buildVerticalIndicator(
              value: _indicatorValue,
              icon: Icons.volume_up_rounded,
              color: _teal,
            ),
          ),

        // Brightness indicator
        if (_showBrightnessIndicator)
          Positioned(
            right: 24,
            top: size.height * 0.2,
            bottom: size.height * 0.2,
            child: _buildVerticalIndicator(
              value: _indicatorValue,
              icon: Icons.brightness_6_rounded,
              color: _purple,
            ),
          ),

        // Seek indicator
        if (_showSeekIndicator)
          Center(child: _buildSeekIndicator()),

        // Skip backward
        if (_showSkipBackward)
          Positioned(
            left: size.width * 0.15,
            top: 0, bottom: 0,
            child: Center(
              child: FadeTransition(
                opacity: ReverseAnimation(_skipBackwardAnim),
                child: ScaleTransition(
                  scale: _skipBackwardAnim,
                  child: _buildSkipIndicator(
                    icon: Icons.replay_10_rounded, label: '-10s',
                  ),
                ),
              ),
            ),
          ),

        // Skip forward
        if (_showSkipForward)
          Positioned(
            right: size.width * 0.15,
            top: 0, bottom: 0,
            child: Center(
              child: FadeTransition(
                opacity: ReverseAnimation(_skipForwardAnim),
                child: ScaleTransition(
                  scale: _skipForwardAnim,
                  child: _buildSkipIndicator(
                    icon: Icons.forward_10_rounded, label: '+10s',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVerticalIndicator({
    required double value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 36,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            '${(value * 100).round()}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) => Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width: 4,
                    height: constraints.maxHeight * value,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.6), color],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekIndicator() {
    final isForward = _seekSeconds >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
            color: _teal, size: 28,
          ),
          const SizedBox(width: 10),
          Text(
            '${isForward ? '+' : ''}${_seekSeconds}s',
            style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipIndicator({
    required IconData icon, required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

enum _DragType { none, volume, brightness, seek }
