import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_player/models/saved_playlist.dart';
import 'package:media_player/providers/playlist_provider.dart';
import 'package:media_player/screens/auto_playlist_screen.dart';
import 'package:media_player/screens/playlist_details_screen.dart';

class PlaylistsTab extends StatefulWidget {
  final VoidCallback onRefresh;

  const PlaylistsTab({
    super.key,
    required this.onRefresh,
  });

  @override
  State<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<PlaylistsTab> {
  List<SavedPlaylist> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final prov = Provider.of<PlaylistProvider>(context, listen: false);
      final data = await prov.getSavedPlaylists();
      if (mounted) {
        setState(() {
          _playlists = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PlaylistsTab] Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _createNewPlaylist() {
    final tc = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('New Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: tc,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: const Color(0xFF0ABAB5).withValues(alpha: 0.5)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF0ABAB5)),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          TextButton(
            onPressed: () async {
              if (tc.text.trim().isNotEmpty) {
                final prov = Provider.of<PlaylistProvider>(context, listen: false);
                await prov.saveAsPlaylist(tc.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadPlaylists();
              }
            },
            child: const Text('CREATE', style: TextStyle(color: Color(0xFF0ABAB5))),
          ),
        ],
      ),
    );
  }

  void _deletePlaylist(SavedPlaylist p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Delete Playlist', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${p.name}"?', 
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
          TextButton(
            onPressed: () async {
              final prov = Provider.of<PlaylistProvider>(context, listen: false);
              await prov.deleteSavedPlaylist(p.id!);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadPlaylists();
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _playPlaylist(SavedPlaylist p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailsScreen(playlist: p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF0ABAB5)),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 100,
      ),
      children: [
        // Grid Auto-Collections
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildAutoCollectionCard('Recently Played', Icons.history_rounded, 'recent')),
                  const SizedBox(width: 16),
                  Expanded(child: _buildAutoCollectionCard('Last Added', Icons.add_circle_outline_rounded, 'last_added')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildAutoCollectionCard('Favorites', Icons.favorite_rounded, 'favorites')),
                  const SizedBox(width: 16),
                  const Spacer(), // Placeholder agar lebarnya proporsional sama dengan kartu di atasnya
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PLAYLISTS (${_playlists.length})',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                onPressed: _createNewPlaylist,
              ),
            ],
          ),
        ),
        
        // List
        if (_playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'No playlists yet.\nTap + to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          )
        else
          ..._playlists.map((p) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.queue_music_rounded, color: Color(0xFF0ABAB5)),
                ),
                title: Text(
                  p.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  '${p.itemCount} items',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                  color: const Color(0xFF1A1A2E),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                  onSelected: (val) {
                    if (val == 'delete') _deletePlaylist(p);
                  },
                ),
                onTap: () => _playPlaylist(p),
              )),
      ],
    );
  }

  Widget _buildAutoCollectionCard(String title, IconData icon, String type) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AutoPlaylistScreen(title: title, type: type)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: const Color(0xFF0ABAB5), size: 24),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
