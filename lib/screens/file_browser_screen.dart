import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:media_player/models/media_item.dart';
import 'package:media_player/providers/file_browser_provider.dart';
import 'package:media_player/providers/playlist_provider.dart';
import 'package:media_player/screens/player_screen.dart';

/// Warna tema premium
const _kCardDark = Color(0xFF16213E);
const _kPurpleAccent = Color(0xFF7B2FBE);
const _kTealAccent = Color(0xFF0ABAB5);

/// Ekstensi media yang didukung
const _kVideoExtensions = {
  'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', '3gp',
};
const _kAudioExtensions = {
  'mp3', 'aac', 'flac', 'ogg', 'wav', 'wma', 'm4a', 'opus',
};
const _kMediaExtensions = {..._kVideoExtensions, ..._kAudioExtensions};

/// Enum opsi pengurutan file browser
enum SortOption { name, date, size, type }

/// FileBrowserScreen — jelajah direktori perangkat secara bebas.
class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _listAnimController;
  SortOption _sortOption = SortOption.name;
  bool _sortAscending = true;
  final Set<String> _selectedPaths = {};
  bool _isMultiSelectMode = false;

  @override
  void initState() {
    super.initState();
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    // Navigasi ke root storage saat pertama kali
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<FileBrowserProvider>(context, listen: false);
      if (provider.currentPath.isEmpty) {
        provider.loadDirectory(_getInitialPath());
      }
    });
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    super.dispose();
  }

  String _getInitialPath() {
    if (Platform.isAndroid) {
      const primary = '/storage/emulated/0';
      if (Directory(primary).existsSync()) return primary;
    }
    return '/';
  }

  // ── Sorting
  List<FileSystemEntity> _sortEntities(List<FileSystemEntity> entities) {
    final dirs = entities.whereType<Directory>().toList();
    final files = entities.where((e) => e is! Directory).toList();

    int Function(FileSystemEntity, FileSystemEntity) comparator;

    switch (_sortOption) {
      case SortOption.name:
        comparator = (a, b) {
          final nameA = a.path.split('/').last.toLowerCase();
          final nameB = b.path.split('/').last.toLowerCase();
          return nameA.compareTo(nameB);
        };
      case SortOption.date:
        comparator = (a, b) {
          try {
            final statA = a.statSync();
            final statB = b.statSync();
            return statA.modified.compareTo(statB.modified);
          } catch (_) {
            return 0;
          }
        };
      case SortOption.size:
        comparator = (a, b) {
          try {
            final statA = a.statSync();
            final statB = b.statSync();
            return statA.size.compareTo(statB.size);
          } catch (_) {
            return 0;
          }
        };
      case SortOption.type:
        comparator = (a, b) {
          final extA = a.path.split('.').last.toLowerCase();
          final extB = b.path.split('.').last.toLowerCase();
          return extA.compareTo(extB);
        };
    }

    dirs.sort(comparator);
    files.sort(comparator);

    if (!_sortAscending) {
      return [...dirs.reversed, ...files.reversed];
    }

    return [...dirs, ...files];
  }

  // ── Multi-select
  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
        if (_selectedPaths.isEmpty) _isMultiSelectMode = false;
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _selectedPaths.clear();
      _isMultiSelectMode = false;
    });
  }

  void _playAllSelected() {
    if (_selectedPaths.isEmpty) return;
    final paths = _selectedPaths.toList();
    final firstPath = paths.first;
    final isVideo = _isVideoFile(firstPath);

    final playlistProv =
        Provider.of<PlaylistProvider>(context, listen: false);
    playlistProv.clearPlaylist();
    for (final p in paths) {
      playlistProv.addToPlaylist(MediaItem(
        path: p,
        name: p.split('/').last,
        sizeBytes: 0,
        type: MediaItem.detectType(p),
        lastModified: DateTime.now(),
      ));
    }

    _exitMultiSelect();

    Navigator.push(
      context,
      _buildPageRoute(
        PlayerScreen(filePath: firstPath, isVideo: isVideo),
      ),
    );
  }

  void _addSelectedToPlaylist() {
    if (_selectedPaths.isEmpty) return;
    final playlistProv =
        Provider.of<PlaylistProvider>(context, listen: false);
    final count = _selectedPaths.length;

    for (final p in _selectedPaths) {
      playlistProv.addToPlaylist(MediaItem(
        path: p,
        name: p.split('/').last,
        sizeBytes: 0,
        type: MediaItem.detectType(p),
        lastModified: DateTime.now(),
      ));
    }

    _exitMultiSelect();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$count file ditambahkan ke playlist',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: _kCardDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  bool _isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _kVideoExtensions.contains(ext);
  }

  bool _isMediaFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _kMediaExtensions.contains(ext);
  }

  Route<T> _buildPageRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, animation, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  // ── Build
  @override
  Widget build(BuildContext context) {
    return Consumer<FileBrowserProvider>(
      builder: (context, provider, _) {
        final canGoBack = provider.currentPath.isNotEmpty &&
            provider.currentPath != '/' &&
            provider.currentPath != _getInitialPath();

        return PopScope(
          canPop: !canGoBack && !_isMultiSelectMode,
          onPopInvokedWithResult: (didPop, _) {
            if (_isMultiSelectMode) {
              _exitMultiSelect();
              return;
            }
            if (!didPop && canGoBack) {
              provider.navigateUp();
            }
          },
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).padding.top > 0 ? MediaQuery.of(context).padding.top + 8 : 8,
              ),
              _buildBreadcrumbBar(provider),
              if (_isMultiSelectMode) _buildMultiSelectToolbar(),
              Expanded(child: _buildDirectoryContent(provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreadcrumbBar(FileBrowserProvider provider) {
    final segments = provider.currentPath.split('/')
      ..removeWhere((s) => s.isEmpty);

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: segments.length + 1,
              separatorBuilder: (_, _) => Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildBreadcrumbChip(
                    icon: Icons.storage_rounded,
                    label: 'Root',
                    onTap: () => provider.loadDirectory('/'),
                    isLast: segments.isEmpty,
                  );
                }

                final isLast = index == segments.length;
                final path = '/${segments.sublist(0, index).join('/')}';
                return _buildBreadcrumbChip(
                  label: segments[index - 1],
                  onTap: isLast ? null : () => provider.loadDirectory(path),
                  isLast: isLast,
                );
              },
            ),
          ),
          _buildSortButton(),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbChip({
    IconData? icon,
    required String label,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isLast
                ? _kPurpleAccent.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: _kTealAccent),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isLast ? _kTealAccent : Colors.white54,
                  fontSize: 13,
                  fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<SortOption>(
      icon: const Icon(Icons.sort_rounded, color: Colors.white38, size: 20),
      color: _kCardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (option) {
        setState(() {
          if (_sortOption == option) {
            _sortAscending = !_sortAscending;
          } else {
            _sortOption = option;
            _sortAscending = true;
          }
        });
      },
      itemBuilder: (_) => [
        _buildSortMenuItem(SortOption.name, 'Nama', Icons.sort_by_alpha),
        _buildSortMenuItem(SortOption.date, 'Tanggal', Icons.calendar_today),
        _buildSortMenuItem(SortOption.size, 'Ukuran', Icons.data_usage),
        _buildSortMenuItem(SortOption.type, 'Tipe', Icons.extension),
      ],
    );
  }

  PopupMenuEntry<SortOption> _buildSortMenuItem(
    SortOption option,
    String label,
    IconData icon,
  ) {
    final isSelected = _sortOption == option;
    return PopupMenuItem(
      value: option,
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: isSelected ? _kTealAccent : Colors.white54),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                color: isSelected ? _kTealAccent : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              )),
          const Spacer(),
          if (isSelected)
            Icon(
              _sortAscending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 16, color: _kTealAccent,
            ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectToolbar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kPurpleAccent.withValues(alpha: 0.2),
            _kTealAccent.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPurpleAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedPaths.length} dipilih',
            style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
            ),
          ),
          const Spacer(),
          _buildToolbarAction(
            icon: Icons.playlist_add_rounded,
            label: 'Playlist',
            onTap: _addSelectedToPlaylist,
          ),
          const SizedBox(width: 8),
          _buildToolbarAction(
            icon: Icons.play_arrow_rounded,
            label: 'Putar',
            isPrimary: true,
            onTap: _playAllSelected,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.white54, size: 20),
            onPressed: _exitMultiSelect,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: isPrimary
          ? _kPurpleAccent.withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18,
                  color: isPrimary ? _kTealAccent : Colors.white60),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : Colors.white60,
                    fontSize: 12, fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectoryContent(FileBrowserProvider provider) {
    if (provider.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor:
              AlwaysStoppedAnimation(_kPurpleAccent.withValues(alpha: 0.7)),
        ),
      );
    }

    if (provider.error != null) {
      return _buildErrorState(provider.error!);
    }

    final entities = _sortEntities(provider.entries);

    if (entities.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_rounded,
                size: 56, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text('Folder kosong',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 15,
                )),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 100),
      physics: const BouncingScrollPhysics(),
      itemCount: entities.length,
      itemBuilder: (context, index) {
        final entity = entities[index];

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + (index * 30).clamp(0, 300)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: entity is Directory
              ? _buildDirectoryTile(entity, provider)
              : _buildFileTile(entity),
        );
      },
    );
  }

  Widget _buildDirectoryTile(Directory dir, FileBrowserProvider provider) {
    final name = dir.path.split('/').last;
    if (name.startsWith('.')) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: _kCardDark.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                _listAnimController.reset();
                _listAnimController.forward();
                provider.loadDirectory(dir.path);
              },
              splashColor: _kPurpleAccent.withValues(alpha: 0.1),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _kPurpleAccent.withValues(alpha: 0.2),
                            _kTealAccent.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.folder_rounded,
                          color: _kTealAccent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('Folder',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 12,
                              )),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.2), size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileTile(FileSystemEntity entity) {
    final name = entity.path.split('/').last;
    if (name.startsWith('.')) return const SizedBox.shrink();

    final isMedia = _isMediaFile(entity.path);
    if (!isMedia) return const SizedBox.shrink();

    final isSelected = _selectedPaths.contains(entity.path);
    final isVideo = _isVideoFile(entity.path);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: isSelected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _kTealAccent.withValues(alpha: 0.5), width: 1.5,
              ),
            )
          : null,
      child: Material(
        color: _kCardDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (_isMultiSelectMode) {
              _toggleSelection(entity.path);
            } else {
              Navigator.push(
                context,
                _buildPageRoute(
                  PlayerScreen(
                    filePath: entity.path,
                    isVideo: isVideo,
                  ),
                ),
              );
            }
          },
          onLongPress: () {
            setState(() {
              _isMultiSelectMode = true;
              _selectedPaths.add(entity.path);
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
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
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
                    color: isVideo ? _kPurpleAccent : _kTealAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (isSelected)
                  Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_kPurpleAccent, _kTealAccent],
                      ),
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.red.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Gagal memuat folder',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 16,
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}
