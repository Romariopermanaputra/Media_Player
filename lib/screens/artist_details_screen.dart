import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:media_player/models/media_item.dart';
import 'package:media_player/services/database_helper.dart';
import 'package:media_player/widgets/media_tile.dart';
import 'package:media_player/screens/player_screen.dart';
import 'package:media_player/widgets/mini_player.dart';

class ArtistDetailsScreen extends StatefulWidget {
  final String artistName;

  const ArtistDetailsScreen({super.key, required this.artistName});

  @override
  State<ArtistDetailsScreen> createState() => _ArtistDetailsScreenState();
}

class _ArtistDetailsScreenState extends State<ArtistDetailsScreen> {
  List<MediaItem> _artistMedia = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtistMedia();
  }

  Future<void> _loadArtistMedia() async {
    final media = await DatabaseHelper.instance.getMediaByArtist(widget.artistName);
    if (mounted) {
      setState(() {
        _artistMedia = media;
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
            widget.artistName.isEmpty || widget.artistName == 'Unknown'
                ? 'Unknown Artist'
                : widget.artistName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: tealAccent))
            : _artistMedia.isEmpty
                ? const Center(
                    child: Text('No media found for this artist.',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 100),
                    itemCount: _artistMedia.length,
                    itemBuilder: (context, index) {
                      final item = _artistMedia[index];
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
                                playlist: item.isVideo ? null : List.from(_artistMedia),
                              ),
                            ),
                          ).then((_) => _loadArtistMedia());
                        },
                      );
                    },
                  ),
        bottomNavigationBar: MiniPlayer(onPop: _loadArtistMedia, useSafeArea: true),
      ),
    );
  }
}
