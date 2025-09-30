import 'package:flutter/material.dart';
import '../models/jellyfin_playlist.dart';
import '../models/jellyfin_server.dart';
import '../models/jellyfin_song.dart';
import '../services/jellyfin_service.dart';
import '../services/settings_service.dart';
import '../services/download_service.dart';
import '../utils/shuffle_helper.dart';

class PlaylistDetailPage extends StatefulWidget {
  final JellyfinPlaylist playlist;
  final JellyfinServer server;

  const PlaylistDetailPage({
    super.key,
    required this.playlist,
    required this.server,
  });

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final _jellyfinService = JellyfinService();
  final _settingsService = SettingsService();
  final _downloadService = DownloadService();
  List<JellyfinSong>? _songs;
  bool _isLoading = true;
  bool _isDownloaded = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _checkDownloadStatus();
  }

  Future<void> _checkDownloadStatus() async {
    final isDownloaded = await _downloadService.isItemDownloaded(widget.playlist.id);
    setState(() {
      _isDownloaded = isDownloaded;
    });
  }

  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final auth = await _settingsService.getAuth();
      if (auth != null) {
        _jellyfinService.setAuth(auth, widget.server);
      }

      final songs = await _jellyfinService.getSongsByAlbum(widget.playlist.id);
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading songs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadSongs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refreshed playlist')),
      );
    }
  }

  void _handleShuffle() {
    if (_songs == null || _songs!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No songs to shuffle')),
      );
      return;
    }

    final shuffled = ShuffleHelper.shuffleSongs(_songs!);

    // TODO: Start playback with shuffled queue
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shuffling ${shuffled.length} songs from ${widget.playlist.name}')),
    );
  }

  Future<void> _handleDownload() async {
    if (_songs == null || _songs!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No songs to download')),
      );
      return;
    }

    // Check if download location is set
    final downloadLocation = await _settingsService.getDownloadLocation();
    if (downloadLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set a download location in settings'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final auth = await _settingsService.getAuth();
      if (auth == null) throw Exception('Not authenticated');

      await _downloadService.downloadAlbum(
        albumId: widget.playlist.id,
        albumName: widget.playlist.name,
        artistName: 'Playlists', // Playlists don't have artist, use folder name
        songs: _songs!,
        server: widget.server,
        auth: auth,
        onProgress: (current, total) {},
      );

      setState(() {
        _isDownloading = false;
        _isDownloaded = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${_songs!.length} songs from ${widget.playlist.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.playlist.getImageUrl(widget.server.baseUrl);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.playlist.name,
                style: const TextStyle(
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
              ),
              background: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.playlist_play,
                            size: 64,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.playlist_play,
                        size: 64,
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.playlist.songCount != null)
                    Text(
                      '${widget.playlist.songCount} songs',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 16),
                  const Divider(),
                ],
              ),
            ),
          ),
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _songs == null || _songs!.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_note,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No songs found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = _songs![index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                (index + 1).toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            title: Text(song.name),
                            subtitle: song.artistName != null
                                ? Text(song.artistName!)
                                : null,
                            trailing: song.duration != null
                                ? Text(
                                    song.duration!,
                                    style: TextStyle(color: Colors.grey[600]),
                                  )
                                : null,
                            onTap: () {
                              // TODO: Play the song
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Playing ${song.name}')),
                              );
                            },
                          );
                        },
                        childCount: _songs!.length,
                      ),
                    ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Download button on the left
              _isDownloaded
                  ? IconButton(
                      icon: Badge(
                        backgroundColor: Colors.green,
                        label: const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                        child: const Icon(Icons.download),
                      ),
                      tooltip: 'Already downloaded',
                      onPressed: null, // Disabled when downloaded
                    )
                  : IconButton(
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      tooltip: 'Download playlist',
                      onPressed: _isLoading || _isDownloading ? null : _handleDownload,
                    ),
              // Shuffle and refresh on the right
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shuffle),
                    tooltip: 'Shuffle playlist',
                    onPressed: _isLoading ? null : _handleShuffle,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: _isLoading ? null : _handleRefresh,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
