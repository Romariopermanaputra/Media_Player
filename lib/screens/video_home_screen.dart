import 'package:flutter/material.dart';

import 'package:media_player/models/media_item.dart';
import 'package:media_player/services/database_helper.dart';
import 'package:media_player/screens/player_screen.dart';
import 'package:media_player/widgets/media_tile.dart';
import 'package:media_player/screens/file_browser_screen.dart';
import 'package:media_player/screens/playlists_tab.dart';

class VideoHomeScreen extends StatefulWidget {
  const VideoHomeScreen({super.key});

  @override
  State<VideoHomeScreen> createState() => _VideoHomeScreenState();
}

class _VideoHomeScreenState extends State<VideoHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MediaItem> _videoFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    final allMedia = await DatabaseHelper.instance.getAllMedia();
    if (mounted) {
      setState(() {
        _videoFiles = allMedia.where((m) => m.isVideo).toList();
        _videoFiles.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundDark = Color(0xFF0D0D20); // Sedikit kebiruan
    const Color tealAccent = Color(0xFFFFB300); // Kuning emas untuk aksen Video Player

    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF7B2FBE), Color(0xFF0ABAB5)], // _kPurpleAccent, _kTealAccent
          ).createShader(bounds),
          child: const Text(
            'Media Player',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white70), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white70), onPressed: () {}),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          indicatorColor: tealAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Videos'),
            Tab(text: 'Folders'),
            Tab(text: 'Playlists'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: tealAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVideosTab(),
                const FileBrowserScreen(), // Reuse file browser for folders
                PlaylistsTab(onRefresh: _loadVideos), // Reuse playlist tab
              ],
            ),
    );
  }

  Widget _buildVideosTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text('All Videos (${_videoFiles.length})',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.sort, color: Colors.white54, size: 20),
              const SizedBox(width: 16),
              const Icon(Icons.grid_view, color: Colors.white54, size: 20),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 100), // Ruang untuk mini player
            itemCount: _videoFiles.length,
            itemBuilder: (context, index) {
              final item = _videoFiles[index];
              return MediaTile(
                item: item,
                index: index,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PlayerScreen(
                            filePath: item.path, isVideo: true)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
