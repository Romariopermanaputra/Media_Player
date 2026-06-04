import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:media_player/models/media_item.dart';
import 'package:media_player/models/saved_playlist.dart';
import 'package:media_player/services/database_helper.dart';
import 'package:media_player/widgets/media_tile.dart';
import 'package:media_player/screens/player_screen.dart';
import 'package:media_player/widgets/mini_player.dart';

class PlaylistDetailsScreen extends StatefulWidget {
  final SavedPlaylist playlist;

  const PlaylistDetailsScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  List<MediaItem> _playlistMedia = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylistMedia();
  }

  Future<void> _loadPlaylistMedia() async {
    if (widget.playlist.id == null) return;
    final media = await DatabaseHelper.instance.getPlaylistItems(widget.playlist.id!);
    if (mounted) {
      setState(() {
        _playlistMedia = media;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundDark = Color(0xFF0D0D0D);
    const Color tealAccent = Color(0xFF0ABAB5);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: backgroundDark,
        appBar: AppBar(
          backgroundColor: backgroundDark.withValues(alpha: 0.9),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.playlist.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: tealAccent))
            : _playlistMedia.isEmpty
                ? const Center(
                    child: Text('No media found in this playlist.',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 100),
                    itemCount: _playlistMedia.length,
                    itemBuilder: (context, index) {
                      final item = _playlistMedia[index];
                      return MediaTile(
                        item: item,
                        index: index,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(
                                filePath: item.path,
                                isVideo: item.isVideo,
                                playlist: item.isVideo ? null : List.from(_playlistMedia),
                              ),
                            ),
                          ).then((_) => _loadPlaylistMedia());
                        },
                      );
                    },
                  ),
        bottomNavigationBar: MiniPlayer(onPop: _loadPlaylistMedia),
      ),
    );
  }
}
