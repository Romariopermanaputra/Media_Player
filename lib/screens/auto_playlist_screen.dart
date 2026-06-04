import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:media_player/models/media_item.dart';
import 'package:media_player/services/database_helper.dart';
import 'package:media_player/providers/history_provider.dart';
import 'package:media_player/widgets/media_tile.dart';
import 'package:media_player/screens/player_screen.dart';
import 'package:media_player/widgets/mini_player.dart';

class AutoPlaylistScreen extends StatefulWidget {
  final String title;
  final String type; // 'recent' or 'last_added'

  const AutoPlaylistScreen({super.key, required this.title, required this.type});

  @override
  State<AutoPlaylistScreen> createState() => _AutoPlaylistScreenState();
}

class _AutoPlaylistScreenState extends State<AutoPlaylistScreen> {
  List<MediaItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    List<MediaItem> result = [];
    if (widget.type == 'recent') {
      final historyProv = Provider.of<HistoryProvider>(context, listen: false);
      await historyProv.loadHistory();
      final allMedia = await DatabaseHelper.instance.getAllMedia();
      for (var h in historyProv.historyList) {
        try {
          final m = allMedia.firstWhere((element) => element.path == h.mediaPath);
          result.add(m);
        } catch (e) {
          // not found in media
        }
      }
    } else if (widget.type == 'last_added') {
      final allMedia = await DatabaseHelper.instance.getAllMedia();
      result = List.from(allMedia);
      result.sort((a, b) => b.lastModified.compareTo(a.lastModified)); // newest first
    } else if (widget.type == 'favorites') {
      final allMedia = await DatabaseHelper.instance.getAllMedia();
      result = allMedia.where((m) => m.isFavorite).toList();
    }

    if (mounted) {
      setState(() {
        _items = result;
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
            widget.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: tealAccent))
            : _items.isEmpty
                ? const Center(
                    child: Text('No media found.',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 100),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
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
                                    playlist: _items,
                                )),
                          ).then((_) => _loadData());
                        },
                      );
                    },
                  ),
        bottomNavigationBar: MiniPlayer(onPop: _loadData, useSafeArea: true),
      ),
    );
  }
}
