// Panel playlist sliding - menampilkan daftar item playlist saat ini
import 'dart:ui';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import 'package:media_player/models/media_item.dart';
import 'package:media_player/providers/playlist_provider.dart';
import 'package:media_player/providers/player_provider.dart';
import 'package:media_player/utils/storage_helper.dart';

/// Widget panel playlist yang ditampilkan sebagai sidebar atau sheet.
class PlaylistPanel extends StatefulWidget {
  final String? currentFilePath;
  final ValueChanged<int>? onItemTap;
  final VoidCallback? onClose;

  const PlaylistPanel({
    super.key,
    this.currentFilePath,
    this.onItemTap,
    this.onClose,
  });

  @override
  State<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends State<PlaylistPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;


  static const _purple = Color(0xFF7B2FBE);
  static const _teal = Color(0xFF00BFA5);
  static const _bgCard = Color(0xFF1A1A2E);
  static const _surfaceLight = Color(0xFF2A2A40);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  IconData _getRepeatIcon(RepeatMode mode) {
    return switch (mode) {
      RepeatMode.off => Icons.repeat_rounded,
      RepeatMode.one => Icons.repeat_one_rounded,
      RepeatMode.all => Icons.repeat_rounded,
    };
  }

  String _getRepeatLabel(RepeatMode mode) {
    return switch (mode) {
      RepeatMode.off => 'Off',
      RepeatMode.one => 'Satu',
      RepeatMode.all => 'Semua',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: _bgCard.withValues(alpha: 0.92),
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(-5, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildHeader(),
                const SizedBox(height: 4),
                _buildControlBar(),
                const Divider(color: Color(0x15FFFFFF), height: 1),
                Expanded(child: _buildPlaylistContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<PlaylistProvider>(
      builder: (_, playlist, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Close button
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white54, size: 22),
              onPressed: widget.onClose,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_purple, _teal],
              ).createShader(bounds),
              child: const Icon(
                Icons.queue_music_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Playlist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${playlist.length}',
                style: TextStyle(
                  color: _teal.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            if (playlist.isNotEmpty)
              _buildActionButton(
                icon: Icons.delete_sweep_rounded,
                label: 'Hapus',
                onTap: () => _showClearConfirmation(context, playlist),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Consumer<PlaylistProvider>(
      builder: (_, playlist, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            _buildToggleChip(
              icon: Icons.shuffle_rounded,
              label: 'Acak',
              isActive: playlist.isShuffled,
              onTap: () => playlist.toggleShuffle(),
            ),
            const SizedBox(width: 10),
            _buildToggleChip(
              icon: _getRepeatIcon(playlist.repeatMode),
              label: _getRepeatLabel(playlist.repeatMode),
              isActive: playlist.repeatMode != RepeatMode.off,
              onTap: () => playlist.cycleRepeatMode(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistContent() {
    return Consumer<PlaylistProvider>(
      builder: (_, playlist, _) {
        if (playlist.isEmpty) return _buildEmptyState();

        final items = playlist.playlist;

        return ReorderableListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
          itemCount: items.length,
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (_, child) => Material(
                color: Colors.transparent,
                elevation: 8,
                shadowColor: _purple.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                child: child,
              ),
              child: child,
            );
          },
          onReorder: (oldIndex, newIndex) {
            playlist.reorderPlaylist(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final item = items[index];
            final currentMediaPath = Provider.of<PlayerProvider>(context).currentMediaPath;
            final isPlaying = item.path == (currentMediaPath ?? widget.currentFilePath);

            return _buildPlaylistItem(
              key: ValueKey('${item.path}_$index'),
              item: item,
              index: index,
              isPlaying: isPlaying,
              onTap: () => widget.onItemTap?.call(index),
              onDismissed: () => playlist.removeFromPlaylist(index),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaylistItem({
    required Key key,
    required MediaItem item,
    required int index,
    required bool isPlaying,
    required VoidCallback onTap,
    required VoidCallback onDismissed,
  }) {
    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              Colors.red.withValues(alpha: 0.0),
              Colors.red.withValues(alpha: 0.3),
            ],
          ),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded,
            color: Colors.white70, size: 24),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isPlaying
                ? _purple.withValues(alpha: 0.15)
                : _surfaceLight.withValues(alpha: 0.4),
            border: Border.all(
              color: isPlaying
                  ? _teal.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.04),
              width: isPlaying ? 1.5 : 1,
            ),
            boxShadow: isPlaying
                ? [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Number or playing indicator
              SizedBox(
                width: 28,
                child: isPlaying
                    ? const _AnimatedBars()
                    : Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              const SizedBox(width: 10),

              // Thumbnail
              _buildSmallThumbnail(item),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPlaying
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight:
                            isPlaying ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (item.durationMs != null)
                          Text(
                            StorageHelper.formatDuration(item.durationMs!),
                            style: TextStyle(
                              color: isPlaying
                                  ? _teal.withValues(alpha: 0.8)
                                  : Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        if (item.durationMs != null)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('•',
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.2),
                                  fontSize: 8,
                                )),
                          ),
                        Text(
                          StorageHelper.formatFileSize(item.sizeBytes),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white30, size: 20),
                onPressed: () {
                  final prov = Provider.of<PlaylistProvider>(context, listen: false);
                  prov.removeFromPlaylist(index);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),

              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.drag_handle_rounded,
                      color: Colors.white.withValues(alpha: 0.2),
                      size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallThumbnail(MediaItem item) {
    final isVideo = item.isVideo;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: isVideo
              ? [
                  _purple.withValues(alpha: 0.3),
                  _teal.withValues(alpha: 0.3),
                ]
              : [
                  const Color(0xFF6C63FF).withValues(alpha: 0.3),
                  const Color(0xFF3F51B5).withValues(alpha: 0.3),
                ],
        ),
      ),
      child: Center(
        child: Icon(
          isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
          size: 20,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_purple, _teal],
            ).createShader(bounds),
            child: Icon(Icons.queue_music_rounded,
                size: 56, color: Colors.white.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 16),
          Text('Playlist kosong',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 6),
          Text('Tambahkan media untuk mulai memutar',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
              )),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.red.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16, color: Colors.red.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                    color: Colors.red.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isActive
              ? const LinearGradient(colors: [_purple, _teal])
              : null,
          color: isActive
              ? null
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmation(
      BuildContext context, PlaylistProvider playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Playlist',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(
          'Hapus semua ${playlist.length} item dari playlist?',
          style:
              TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              playlist.clearPlaylist();
              Navigator.pop(ctx);
            },
            child: const Text('Hapus',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Animated Bars
// =============================================================================
class _AnimatedBars extends StatefulWidget {
  const _AnimatedBars();

  @override
  State<_AnimatedBars> createState() => _AnimatedBarsState();
}

class _AnimatedBarsState extends State<_AnimatedBars>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  static const _teal = Color(0xFF00BFA5);

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + (i * 150)),
      )..repeat(reverse: true);
    });

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (_, _) => Container(
            width: 3,
            height: 14 * _animations[i].value,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _teal,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        );
      }),
    );
  }
}
