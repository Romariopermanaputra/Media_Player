import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_player/providers/player_provider.dart';
import 'package:media_player/providers/playlist_provider.dart';
import 'package:media_player/screens/player_screen.dart';
import 'package:path/path.dart' as p;

class MiniPlayer extends StatelessWidget {
  final VoidCallback? onPop;
  final bool useSafeArea;

  const MiniPlayer({super.key, this.onPop, this.useSafeArea = false});

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, PlaylistProvider>(
      builder: (context, playerProv, playlistProv, child) {
        final filePath = playerProv.currentMediaPath;
        if (filePath == null) return const SizedBox.shrink();

        final currentItem = playlistProv.currentItem;
        final name = currentItem?.name ?? p.basename(filePath);
        final artist = currentItem?.artist ?? 'Unknown Artist';
        final coverPath = currentItem?.coverArtPath;
        final isPlaying = playerProv.isPlaying;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerScreen(
                  filePath: filePath,
                  isVideo: currentItem?.type == 'video',
                ),
              ),
            ).then((_) => onPop?.call());
          },
            child: SafeArea(
              bottom: useSafeArea,
              top: false,
              child: Container(
                height: 64,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                // Cover Art Thumbnail
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: Colors.white.withValues(alpha: 0.05),
                      child: coverPath != null && File(coverPath).existsSync()
                          ? Image.file(File(coverPath), fit: BoxFit.cover)
                          : const Icon(Icons.music_note_rounded, color: Colors.white54),
                    ),
                  ),
                ),

                  // Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Play/Pause
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => playerProv.togglePlayPause(),
                  ),

                  // Next
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                    onPressed: playlistProv.hasNext
                        ? () {
                            final nextItem = playlistProv.next();
                            if (nextItem != null) {
                              playerProv.openMedia(nextItem.path, isVideo: nextItem.isVideo);
                            }
                          }
                        : null,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
