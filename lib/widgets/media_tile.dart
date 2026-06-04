// Widget tile untuk menampilkan item media dalam bentuk kartu premium
// Mendukung thumbnail, informasi file, animasi masuk, dan state seleksi

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:media_player/models/media_item.dart';
import 'package:media_player/utils/storage_helper.dart';
import 'package:media_player/utils/thumbnail_helper.dart';

/// Widget kartu premium untuk menampilkan satu item media.
///
/// Menampilkan thumbnail (atau fallback icon), nama file, ukuran,
/// durasi (jika tersedia), dan badge tipe file.
/// Mendukung animasi masuk (fade + slide dari kanan) dan state seleksi.
class MediaTile extends StatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  /// Indeks tile untuk menghitung delay animasi masuk secara berurutan
  final int index;

  const MediaTile({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.index = 0,
  });

  @override
  State<MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<MediaTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // --- Konstanta Warna Tema Premium ---
  static const _bgCard = Color(0xFF1A1A2E);
  static const _purple = Color(0xFF7B2FBE);
  static const _teal = Color(0xFF00BFA5);
  static const _surfaceLight = Color(0xFF2A2A40);

  /// Path thumbnail yang di-generate secara lazy
  String? _lazyThumbnailPath;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _animController.forward();
    });

    // Lazy load thumbnail jika belum ada
    _loadThumbnailIfNeeded();
  }

  /// Generate thumbnail secara lazy saat tile muncul di viewport
  void _loadThumbnailIfNeeded() {
    if (widget.item.thumbnailPath != null) return;
    if (!widget.item.isVideo) return;

    ThumbnailHelper.generateOrGetCached(widget.item.path).then((path) {
      if (mounted && path != null) {
        setState(() => _lazyThumbnailPath = path);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Mendapatkan ikon fallback berdasarkan tipe media
  IconData _getFallbackIcon() {
    return widget.item.isVideo ? Icons.movie_rounded : Icons.music_note_rounded;
  }

  /// Mendapatkan warna gradient berdasarkan tipe media
  List<Color> _getTypeGradient() {
    return widget.item.isVideo
        ? [_purple, _teal]
        : [const Color(0xFF6C63FF), const Color(0xFF3F51B5)];
  }

  Widget _buildThumbnail() {
    final coverArtPath = widget.item.coverArtPath;
    final thumbnailPath = widget.item.thumbnailPath ?? _lazyThumbnailPath ?? coverArtPath;
    final hasImage = thumbnailPath != null && File(thumbnailPath).existsSync();

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: _getTypeGradient()
              .map((c) => c.withValues(alpha: 0.3))
              .toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.file(
              File(thumbnailPath),
              fit: BoxFit.cover,
              width: 56,
              height: 56,
              errorBuilder: (_, _, _) => _buildFallbackIcon(),
            )
          : _buildFallbackIcon(),
    );
  }

  /// Membangun ikon fallback ketika thumbnail tidak tersedia
  Widget _buildFallbackIcon() {
    return Center(
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: _getTypeGradient(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Icon(
          _getFallbackIcon(),
          size: 36,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Membangun badge tipe file di pojok kanan atas thumbnail
  Widget _buildTypeBadge() {
    if (!widget.item.isVideo) return const SizedBox.shrink(); // Hanya untuk video
    return Positioned(
      bottom: 4,
      right: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _buildCard(),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [_purple, _teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    _surfaceLight.withValues(alpha: 0.6),
                    _surfaceLight.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _purple.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? _bgCard.withValues(alpha: 0.95)
                : _bgCard.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14.5),
          ),
          child: Row(
            children: [
              // Thumbnail dengan badge tipe
              Stack(
                children: [
                  _buildThumbnail(),
                  _buildTypeBadge(),
                ],
              ),
              const SizedBox(width: 14),

              // Informasi file
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nama file
                    Text(
                      widget.item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Artist (if audio)
                    if (!widget.item.isVideo && widget.item.artist != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(
                          widget.item.artist!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    
                    // Baris metadata: ukuran file & durasi
                    Row(
                      children: [
                        if (widget.item.durationMs != null) ...[
                          _buildInfoChip(
                            icon: Icons.schedule_rounded,
                            label: StorageHelper.formatDuration(
                                widget.item.durationMs!),
                          ),
                          const SizedBox(width: 10),
                        ],
                        // Ukuran file
                        _buildInfoChip(
                          icon: Icons.storage_rounded,
                          label: StorageHelper.formatFileSize(
                              widget.item.sizeBytes),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Indikator seleksi, ikon favorit, dan menu
              if (widget.item.isFavorite && !isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 20),
                ),
              if (isSelected)
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_purple, _teal],
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  color: Colors.white.withValues(alpha: 0.5),
                  iconSize: 20,
                  onPressed: widget.onLongPress, // Gunakan menu long press untuk aksi 3-dot
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget chip informasi kecil (ikon + teks)
  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: _teal.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 11.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
