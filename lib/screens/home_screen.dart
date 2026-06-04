import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:media_player/providers/playlist_provider.dart';
import 'package:media_player/providers/history_provider.dart';
import 'package:media_player/screens/file_browser_screen.dart';
import 'package:media_player/screens/player_screen.dart';
import 'package:media_player/screens/playlists_tab.dart';
import 'package:media_player/screens/artists_tab.dart';
import 'package:media_player/widgets/media_tile.dart';
import 'package:media_player/widgets/mini_player.dart';
import 'package:media_player/screens/artist_details_screen.dart';
import 'package:media_player/screens/video_home_screen.dart';
import 'package:media_player/models/media_item.dart';
import 'package:media_player/utils/storage_helper.dart';
import 'package:media_player/services/media_indexer.dart';
import 'package:media_player/services/database_helper.dart';

const _kBackgroundDark = Color(0xFF0D0D0D);
const _kSurfaceDark = Color(0xFF1A1A2E);
const _kPurpleAccent = Color(0xFF7B2FBE);
const _kTealAccent = Color(0xFF0ABAB5);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum SortOption { name, dateAdded, favoritesFirst }

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _bottomNavIndex = 0; // 0: Audio, 1: Video
  bool _isSearching = false;
  bool _isLoading = true;
  SortOption _currentSort = SortOption.name;
  List<MediaItem> _allMediaFiles = [];
  final TextEditingController _searchController = TextEditingController();
  
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};
  late final AnimationController _fabAnimController;
  late final Animation<double> _fabScaleAnim;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabScaleAnim = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.elasticOut,
    );
    _fabAnimController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      final granted = await StorageHelper.requestPermissions();
      if (!granted && mounted) {
        _showPermissionDeniedDialog();
        return;
      }

      if (mounted) {
        final indexer = MediaIndexer(databaseHelper: DatabaseHelper.instance);
        try {
          await indexer.scanAll();
        } catch (e) {
          debugPrint('[HomeScreen] Error scan: $e');
        }

        final allMedia = await DatabaseHelper.instance.getAllMedia();
        if (mounted) {
          setState(() => _allMediaFiles = allMedia);
        }

        if (mounted) {
          Provider.of<HistoryProvider>(context, listen: false).loadHistory();
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurfaceDark,
        title: const Text('Izin Diperlukan', style: TextStyle(color: Colors.white)),
        content: const Text('Aplikasi membutuhkan izin penyimpanan.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isLoading = false);
            },
            child: const Text('Nanti', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: FilledButton.styleFrom(backgroundColor: _kPurpleAccent),
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    final indexer = MediaIndexer(databaseHelper: DatabaseHelper.instance);
    await indexer.scanAll();
    await _loadMediaOnly();
  }

  Future<void> _loadMediaOnly() async {
    final allMedia = await DatabaseHelper.instance.getAllMedia();
    if (mounted) {
      setState(() => _allMediaFiles = allMedia);
    }
  }

  Future<void> _pickAndPlayFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', '3gp',
          'mp3', 'aac', 'flac', 'ogg', 'wav', 'wma', 'm4a', 'opus',
        ],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty || !mounted) return;

      final files = result.files.where((f) => f.path != null).toList();
      if (files.isEmpty) return;

      final firstPath = files.first.path!;
      final isVideo = _isVideoFile(firstPath);

      if (files.length == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerScreen(filePath: firstPath, isVideo: isVideo)),
        );
      } else {
        final playlistProv = Provider.of<PlaylistProvider>(context, listen: false);
        playlistProv.clearPlaylist();
        for (final f in files) {
          if (f.path == null) continue;
          playlistProv.addToPlaylist(MediaItem(
            path: f.path!,
            name: f.name,
            sizeBytes: f.size,
            type: MediaItem.detectType(f.path!),
            lastModified: DateTime.now(),
          ));
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerScreen(filePath: firstPath, isVideo: isVideo)),
        );
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  bool _isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', '3gp'].contains(ext);
  }

  List<MediaItem> _getFilteredMedia() {
    final query = _searchController.text.toLowerCase();
    
    // Filter by type and query
    var filtered = _allMediaFiles.where((f) {
      if (_bottomNavIndex == 0 && f.isVideo) return false;
      if (_bottomNavIndex == 1 && f.isAudio) return false;
      if (query.isNotEmpty && !f.name.toLowerCase().contains(query)) return false;
      return true;
    }).toList();

    // Sort
    switch (_currentSort) {
      case SortOption.name:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOption.dateAdded:
        filtered.sort((a, b) {
          final dateA = a.addedAt ?? a.lastModified;
          final dateB = b.addedAt ?? b.lastModified;
          return dateB.compareTo(dateA); // newest first
        });
        break;
      case SortOption.favoritesFirst:
        filtered.sort((a, b) {
          if (a.isFavorite && !b.isFavorite) return -1;
          if (!a.isFavorite && b.isFavorite) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }
    
    return filtered;
  }

  void _shuffleAndPlay() {
    final filtered = _getFilteredMedia();
    if (filtered.isEmpty) return;
    
    final playlistProv = Provider.of<PlaylistProvider>(context, listen: false);
    playlistProv.clearPlaylist();
    
    final shuffled = List<MediaItem>.from(filtered)..shuffle();
    playlistProv.addMultiple(shuffled);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          filePath: shuffled.first.path, 
          isVideo: shuffled.first.isVideo,
        ),
      ),
    );
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedItems.contains(path)) {
        _selectedItems.remove(path);
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItems.add(path);
      }
    });
  }

  void _addToPlaylistSelected() async {
    if (_selectedItems.isEmpty) return;

    final itemsToAdd = _allMediaFiles.where((m) => _selectedItems.contains(m.path)).toList();
    final playlistProv = Provider.of<PlaylistProvider>(context, listen: false);
    final savedPlaylists = await playlistProv.getSavedPlaylists();

    if (!mounted) return;

    // Show dialog to pick existing playlist or create new one
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Add to Playlist',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.add_rounded, color: Color(0xFF0ABAB5)),
            title: const Text('New Playlist', style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(ctx);
              final tc = TextEditingController();
              await showDialog(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A2E),
                  title: const Text('New Playlist', style: TextStyle(color: Colors.white)),
                  content: TextField(
                    controller: tc,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Playlist name',
                      hintStyle: TextStyle(color: Colors.white38),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0ABAB5))),
                    ),
                    autofocus: true,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (tc.text.trim().isNotEmpty) {
                          await playlistProv.saveAsNewPlaylistFromPaths(
                            tc.text.trim(),
                            itemsToAdd.map((m) => m.path).toList(),
                          );
                          if (!dialogCtx.mounted) return;
                          Navigator.pop(dialogCtx);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${itemsToAdd.length} items added to "${tc.text.trim()}"')),
                          );
                        }
                      },
                      child: const Text('CREATE', style: TextStyle(color: Color(0xFF0ABAB5))),
                    ),
                  ],
                ),
              );
            },
          ),
          ...savedPlaylists.map((p) => ListTile(
            leading: const Icon(Icons.queue_music_rounded, color: Colors.white54),
            title: Text(p.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text('${p.itemCount} items', style: const TextStyle(color: Colors.white38)),
            onTap: () async {
              Navigator.pop(ctx);
              await playlistProv.addToSavedPlaylist(
                p.id!, itemsToAdd.map((m) => m.path).toList(),
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${itemsToAdd.length} items added to "${p.name}"')),
              );
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
      ),
      ),
    );

    setState(() {
      _isSelectionMode = false;
      _selectedItems.clear();
    });
  }

  void _deleteSelected() async {
    if (_selectedItems.isEmpty) return;
    
    // Delete from DB
    for (var path in _selectedItems) {
      await DatabaseHelper.instance.deleteMedia(path);
    }
    
    setState(() {
      _isSelectionMode = false;
      _selectedItems.clear();
    });
    
    _onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _kBackgroundDark,
      ),
      child: Scaffold(
        backgroundColor: _kBackgroundDark,
        extendBodyBehindAppBar: true,
        appBar: _bottomNavIndex == 0 ? (_isSelectionMode ? _buildSelectionAppBar() : _buildAppBar()) : null,
        body: _isLoading ? _buildLoadingState() : (_bottomNavIndex == 0 ? _buildBody() : const VideoHomeScreen()),
        floatingActionButton: _bottomNavIndex == 0 ? _buildFAB() : null,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MiniPlayer(onPop: _loadMediaOnly),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _kTealAccent.withValues(alpha: 0.2),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () {
          setState(() {
            _isSelectionMode = false;
            _selectedItems.clear();
          });
        },
      ),
      title: Text(
        '${_selectedItems.length} selected',
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
          onPressed: _addToPlaylistSelected,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          onPressed: _deleteSelected,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _kBackgroundDark.withValues(alpha: 0.9),
      title: _isSearching ? _buildSearchField() : _buildGradientTitle(),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search_rounded, color: Colors.white70),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchController.clear();
            });
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
          color: const Color(0xFF1A1A2E),
          onSelected: (value) {
            if (value == 'add') {
              _pickAndPlayFiles();
            } else if (value == 'sort_name') {
              setState(() => _currentSort = SortOption.name);
            } else if (value == 'sort_date') {
              setState(() => _currentSort = SortOption.dateAdded);
            } else if (value == 'sort_fav') {
              setState(() => _currentSort = SortOption.favoritesFirst);
            } else if (value == 'scan') {
              _onRefresh();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'add',
              child: Text('Add Files Manually', style: TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem<String>(
              value: 'scan',
              child: Text('Scan Media', style: TextStyle(color: Colors.white)),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              enabled: false,
              child: Text('SORT BY', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            PopupMenuItem<String>(
              value: 'sort_name',
              child: Row(
                children: [
                  Expanded(child: const Text('A-Z', style: TextStyle(color: Colors.white))),
                  if (_currentSort == SortOption.name) const Icon(Icons.check, color: _kTealAccent, size: 18),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'sort_date',
              child: Row(
                children: [
                  Expanded(child: const Text('Date Added', style: TextStyle(color: Colors.white))),
                  if (_currentSort == SortOption.dateAdded) const Icon(Icons.check, color: _kTealAccent, size: 18),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'sort_fav',
              child: Row(
                children: [
                  Expanded(child: const Text('Favorites First', style: TextStyle(color: Colors.white))),
                  if (_currentSort == SortOption.favoritesFirst) const Icon(Icons.check, color: _kTealAccent, size: 18),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: _kTealAccent,
        labelColor: _kTealAccent,
        unselectedLabelColor: Colors.white54,
        tabs: const [
          Tab(text: 'Songs'),
          Tab(text: 'Artists'),
          Tab(text: 'Playlists'),
          Tab(text: 'Folders'),
        ],
      ),
    );
  }

  Widget _buildGradientTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [_kPurpleAccent, _kTealAccent],
      ).createShader(bounds),
      child: const Text(
        'Media Player',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Cari media...',
        hintStyle: const TextStyle(color: Colors.white38),
        border: InputBorder.none,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(_kTealAccent)),
    );
  }

  Widget _buildBody() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildSongsTab(),
        ArtistsTab(
          onArtistSelected: (artist) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ArtistDetailsScreen(artistName: artist)),
            );
          },
        ),
        PlaylistsTab(onRefresh: _onRefresh),
        const FileBrowserScreen(),
      ],
    );
  }

  Widget _buildSongsTab() {
    final filtered = _getFilteredMedia();

    if (filtered.isEmpty) {
      return Center(
        child: Text('No media found', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: _kTealAccent,
      backgroundColor: _kSurfaceDark,
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 100, // For mini player and fab
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return MediaTile(
            item: item,
            index: index,
            isSelected: _selectedItems.contains(item.path),
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(item.path);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                      filePath: item.path, 
                      isVideo: item.isVideo,
                      playlist: item.isVideo ? null : List.from(filtered),
                    ),
                  ),
                ).then((_) => _loadMediaOnly());
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedItems.add(item.path);
                });
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildFAB() {
    return ScaleTransition(
      scale: _fabScaleAnim,
      child: FloatingActionButton(
        heroTag: 'fab_shuffle_all',
        onPressed: _shuffleAndPlay,
        backgroundColor: _kPurpleAccent,
        child: const Icon(Icons.shuffle_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: _kSurfaceDark,
      currentIndex: _bottomNavIndex,
      selectedItemColor: _kTealAccent,
      unselectedItemColor: Colors.white38,
      onTap: (i) => setState(() => _bottomNavIndex = i),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.music_note_rounded),
          label: 'Audio',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.videocam_rounded),
          label: 'Video',
        ),
      ],
    );
  }
}

// openAppSettings() is provided by permission_handler package
