import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/jellyfin_album.dart';
import '../models/jellyfin_artist.dart';
import '../models/jellyfin_server.dart';
import '../models/jellyfin_song.dart';
import '../services/jellyfin_service.dart';
import '../services/settings_service.dart';
import '../services/download_service.dart';
import '../services/offline_service.dart';
import '../utils/shuffle_helper.dart';
import '../widgets/mini_player.dart';
import '../providers/player_provider.dart';
import 'album_detail_page.dart';

class ArtistDetailPage extends StatefulWidget {
  final JellyfinArtist artist;
  final JellyfinServer server;
  final bool isOfflineMode;

  const ArtistDetailPage({
    super.key,
    required this.artist,
    required this.server,
    this.isOfflineMode = false,
  });

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  final _jellyfinService = JellyfinService();
  final _settingsService = SettingsService();
  final _downloadService = DownloadService();
  final _offlineService = OfflineService();
  List<JellyfinAlbum>? _albums;
  bool _isLoading = true;
  bool _isDownloaded = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
    _checkDownloadStatus();
  }

  Future<void> _checkDownloadStatus() async {
    // Check if all albums are downloaded
    if (_albums == null) return;

    bool allDownloaded = true;
    for (final album in _albums!) {
      if (!await _downloadService.isItemDownloaded(album.id)) {
        allDownloaded = false;
        break;
      }
    }

    setState(() {
      _isDownloaded = allDownloaded;
    });
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<JellyfinAlbum> albums;

      if (widget.isOfflineMode) {
        // Load from offline storage
        albums = await _offlineService.getDownloadedAlbumsByArtist(widget.artist.name);
      } else {
        // Load auth and set it on the service
        final auth = await _settingsService.getAuth();
        if (auth != null) {
          _jellyfinService.setAuth(auth, widget.server);
        }

        albums = await _jellyfinService.getAlbumsByArtist(widget.artist.id);
      }

      setState(() {
        _albums = albums;
        _isLoading = false;
      });

      // Check download status after loading albums
      await _checkDownloadStatus();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading albums: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final auth = await _settingsService.getAuth();
      if (auth != null) {
        _jellyfinService.setAuth(auth, widget.server);
      }

      final albums = await _jellyfinService.getAlbumsByArtist(widget.artist.id, forceRefresh: true);
      setState(() {
        _albums = albums;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refreshed album list')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleShuffle() async {
    if (_albums == null || _albums!.isEmpty) return;

    // Fetch all songs from all albums
    final List<JellyfinSong> allSongs = [];

    for (final album in _albums!) {
      try {
        final songs = await _jellyfinService.getSongsByAlbum(album.id);
        allSongs.addAll(songs);
      } catch (e) {
        print('Error fetching songs for album ${album.name}: $e');
      }
    }

    if (allSongs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No songs found to shuffle')),
        );
      }
      return;
    }

    // Shuffle the songs
    final shuffled = ShuffleHelper.shuffleSongs(allSongs);

    // Start playback with shuffled queue
    if (mounted) {
      final player = Provider.of<PlayerProvider>(context, listen: false);
      final auth = await _settingsService.getAuth();

      player.audioService.setServerInfo(
        widget.server,
        auth,
        isOfflineMode: widget.isOfflineMode,
      );

      await player.audioService.playQueue(shuffled);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shuffling ${shuffled.length} songs from ${widget.artist.name}')),
      );
    }
  }

  Future<void> _handleDownload() async {
    if (_albums == null || _albums!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No albums to download')),
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

      int totalAlbums = _albums!.length;
      int completedAlbums = 0;

      // Download each album
      for (final album in _albums!) {
        // Fetch songs for this album
        final songs = await _jellyfinService.getSongsByAlbum(album.id);

        if (songs.isNotEmpty) {
          await _downloadService.downloadAlbum(
            albumId: album.id,
            albumName: album.name,
            artistName: widget.artist.name,
            songs: songs,
            server: widget.server,
            auth: auth,
            onProgress: (current, total) {},
          );
        }

        completedAlbums++;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded $completedAlbums of $totalAlbums albums'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }

      setState(() {
        _isDownloading = false;
        _isDownloaded = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded all albums by ${widget.artist.name}'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artist.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _albums == null || _albums!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.album,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No albums found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _albums!.length,
                  itemBuilder: (context, index) {
                    final album = _albums![index];
                    final imageUrl = album.getImageUrl(widget.server.baseUrl);

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
                                  child: const Icon(Icons.album),
                                );
                              },
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey[300],
                              child: const Icon(Icons.album),
                            ),
                      title: Text(album.name),
                      subtitle: album.year != null
                          ? Text(album.year.toString())
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AlbumDetailPage(
                              album: album,
                              server: widget.server,
                              isOfflineMode: widget.isOfflineMode,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Offline indicator or download button on the left
              if (widget.isOfflineMode)
                IconButton(
                  icon: const Icon(Icons.cloud_off),
                  tooltip: 'Offline mode',
                  onPressed: null, // Disabled, just an indicator
                )
              else
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
                        tooltip: 'All albums downloaded',
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
                        tooltip: 'Download all albums',
                        onPressed: _isLoading || _isDownloading ? null : _handleDownload,
                      ),
              // Shuffle and refresh on the right
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shuffle),
                    tooltip: 'Shuffle all songs',
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
        ],
      ),
    );
  }
}
