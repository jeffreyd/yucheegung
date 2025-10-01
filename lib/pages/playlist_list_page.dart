import 'package:flutter/material.dart';
import '../models/jellyfin_playlist.dart';
import '../models/jellyfin_server.dart';
import '../services/jellyfin_service.dart';
import '../services/offline_service.dart';
import '../services/settings_service.dart';
import 'playlist_detail_page.dart';

class PlaylistListPage extends StatefulWidget {
  final JellyfinServer server;
  final String? libraryName;
  final bool isOfflineMode;

  const PlaylistListPage({
    super.key,
    required this.server,
    this.libraryName,
    this.isOfflineMode = false,
  });

  @override
  State<PlaylistListPage> createState() => _PlaylistListPageState();
}

class _PlaylistListPageState extends State<PlaylistListPage> {
  final _jellyfinService = JellyfinService();
  final _offlineService = OfflineService();
  final _settingsService = SettingsService();
  List<JellyfinPlaylist>? _playlists;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<JellyfinPlaylist> playlists;

      if (widget.isOfflineMode) {
        // Load downloaded playlists
        playlists = await _offlineService.getDownloadedPlaylists();
      } else {
        // Load from server
        final auth = await _settingsService.getAuth();
        if (auth != null) {
          _jellyfinService.setAuth(auth, widget.server);
        }
        playlists = await _jellyfinService.getPlaylists();
      }

      setState(() {
        _playlists = playlists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading playlists: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadPlaylists();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refreshed playlist list')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlists == null || _playlists!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.playlist_play,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No playlists found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _playlists!.length,
                  itemBuilder: (context, index) {
                    final playlist = _playlists![index];
                    final imageUrl = playlist.getImageUrl(widget.server.baseUrl);

                    return ListTile(
                      leading: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.playlist_play),
                                );
                              },
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey[300],
                              child: const Icon(Icons.playlist_play),
                            ),
                      title: Text(playlist.name),
                      subtitle: playlist.songCount != null
                          ? Text('${playlist.songCount} songs')
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PlaylistDetailPage(
                              playlist: playlist,
                              server: widget.server,
                              libraryName: widget.libraryName,
                              isOfflineMode: widget.isOfflineMode,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _isLoading ? null : _handleRefresh,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
