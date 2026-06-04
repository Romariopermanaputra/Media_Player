import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:media_player/models/history_item.dart';
import 'package:media_player/providers/history_provider.dart';
import 'package:media_player/screens/player_screen.dart';
import 'package:media_player/utils/storage_helper.dart';

/// Warna tema premium
const _kSurfaceDark = Color(0xFF1A1A2E);
const _kCardDark = Color(0xFF16213E);
const _kPurpleAccent = Color(0xFF7B2FBE);
const _kTealAccent = Color(0xFF0ABAB5);

/// HistoryScreen — menampilkan daftar file yang baru diputar.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryProvider>(
      builder: (context, provider, _) {
        final items = provider.historyList;

        return Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top + kToolbarHeight,
            ),
            if (items.isNotEmpty) _buildHeader(context, items.length),
            Expanded(
              child: items.isEmpty
                  ? _buildEmptyState()
                  : _buildHistoryList(context, items),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.history_rounded,
              color: Colors.white.withValues(alpha: 0.3), size: 18),
          const SizedBox(width: 8),
          Text(
            '$count riwayat',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _showClearAllDialog(context),
            icon: Icon(Icons.delete_sweep_rounded,
                color: Colors.red.withValues(alpha: 0.6), size: 18),
            label: Text(
              'Hapus Semua',
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Semua Riwayat?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Semua riwayat pemutaran akan dihapus. Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<HistoryProvider>(context, listen: false)
                  .clearAllHistory();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_kPurpleAccent, _kTealAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Icon(
                Icons.history_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ada Riwayat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'File yang Anda putar akan tampil di sini\nuntuk akses cepat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, List<HistoryItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 100),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 500 + (index * 50).clamp(0, 300)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(30 * (1 - value), 0),
                child: child,
              ),
            );
          },
          child: _HistoryCard(item: item, index: index),
        );
      },
    );
  }
}

/// Widget card untuk satu item riwayat
class _HistoryCard extends StatelessWidget {
  final HistoryItem item;
  final int index;

  const _HistoryCard({required this.item, required this.index});

  bool _isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', '3gp']
        .contains(ext);
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu lalu';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} bulan lalu';
    return '${(diff.inDays / 365).floor()} tahun lalu';
  }

  void _playFile(BuildContext context, {Duration? resumePosition}) {
    final isVideo = _isVideoFile(item.mediaPath);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => PlayerScreen(
          filePath: item.mediaPath,
          isVideo: isVideo,
          startPosition: resumePosition,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity:
                CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showResumeDialog(BuildContext context) {
    final positionStr = StorageHelper.formatDuration(item.lastPositionMs);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Lanjutkan Pemutaran?',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.mediaName,
              style: const TextStyle(
                color: Colors.white70, fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kPurpleAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _kPurpleAccent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_outline_rounded,
                      color: _kTealAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Lanjut dari $positionStr',
                    style: const TextStyle(color: _kTealAccent, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _playFile(context);
            },
            child: const Text(
              'Dari Awal',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _playFile(
                context,
                resumePosition:
                    Duration(milliseconds: item.lastPositionMs),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: _kPurpleAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = item.progressPercentage;
    final isVideo = _isVideoFile(item.mediaPath);
    final relativeTime = _formatRelativeTime(item.playedAt);
    final positionStr = item.formattedPosition;
    final durationStr = item.formattedDuration;

    return Dismissible(
      key: ValueKey('${item.mediaPath}_${item.playedAt}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        if (item.id != null) {
          Provider.of<HistoryProvider>(context, listen: false)
              .removeFromHistory(item.id!);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Riwayat dihapus',
                style: TextStyle(color: Colors.white)),
            backgroundColor: _kCardDark,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      background: _buildDismissBackground(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: _GradientBorderCard(
          borderGradient: LinearGradient(
            colors: [
              _kPurpleAccent.withValues(alpha: 0.25),
              _kTealAccent.withValues(alpha: 0.1),
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderWidth: 1.2,
          borderRadius: 16,
          child: Material(
            color: _kCardDark.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (item.lastPositionMs > 5000) {
                  _showResumeDialog(context);
                } else {
                  _playFile(context);
                }
              },
              splashColor: _kPurpleAccent.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Thumbnail placeholder
                    _buildThumbnail(isVideo),
                    const SizedBox(width: 14),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.mediaName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 12,
                                  color: Colors.white.withValues(alpha: 0.3)),
                              const SizedBox(width: 4),
                              Text(relativeTime,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                  )),
                              const SizedBox(width: 12),
                              Text('$positionStr / $durationStr',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 12,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 3,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.08),
                              valueColor: const AlwaysStoppedAnimation(
                                _kTealAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    Icon(
                      Icons.play_circle_filled_rounded,
                      color: _kPurpleAccent.withValues(alpha: 0.6),
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(bool isVideo) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: isVideo
              ? [
                  _kPurpleAccent.withValues(alpha: 0.2),
                  _kPurpleAccent.withValues(alpha: 0.05),
                ]
              : [
                  _kTealAccent.withValues(alpha: 0.2),
                  _kTealAccent.withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Icon(
        isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
        color: isVideo
            ? _kPurpleAccent.withValues(alpha: 0.7)
            : _kTealAccent.withValues(alpha: 0.7),
        size: 26,
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_rounded, color: Colors.redAccent, size: 24),
          SizedBox(height: 4),
          Text('Hapus',
              style: TextStyle(color: Colors.redAccent, fontSize: 11)),
        ],
      ),
    );
  }
}

// =============================================================================
// Gradient border card widget
// =============================================================================
class _GradientBorderCard extends StatelessWidget {
  final Widget child;
  final Gradient borderGradient;
  final double borderWidth;
  final double borderRadius;

  const _GradientBorderCard({
    required this.child,
    required this.borderGradient,
    this.borderWidth = 1.0,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: borderGradient,
      ),
      child: Container(
        margin: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius - borderWidth),
          color: _kCardDark,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - borderWidth),
          child: child,
        ),
      ),
    );
  }
}
