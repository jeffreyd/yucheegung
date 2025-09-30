import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/jellyfin_album.dart';
import '../models/jellyfin_server.dart';
import '../models/jellyfin_song.dart';
import '../services/jellyfin_service.dart';
import '../services/settings_service.dart';
import '../services/download_service.dart';
import '../services/offline_service.dart';
import '../utils/shuffle_helper.dart';
import '../widgets/mini_player.dart';
import '../providers/player_provider.dart';

class AlbumDetailPage extends StatefulWidget {
  final JellyfinAlbum album;
  final JellyfinServer server;
  final bool isOfflineMode;
  final String? libraryName;

  const AlbumDetailPage({
    super.key,
    required this.album,
    required this.server,
    this.isOfflineMode = false,
    this.libraryName,
  });

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  final _jellyfinService = JellyfinService();
  final _settingsService = SettingsService();
  final _downloadService = DownloadService();
  final _offlineService = OfflineService();
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
    final isDownloaded = await _downloadService.isItemDownloaded(widget.album.id);
    setState(() {
      _isDownloaded = isDownloaded;
    });
  }

  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<JellyfinSong> songs;

      if (widget.isOfflineMode) {
        // Load from offline storage
        songs = await _offlineService.getDownloadedSongs(widget.album.id);
      } else {
        // Load auth and set it on the service
        final auth = await _settingsService.getAuth();
        if (auth != null) {
          _jellyfinService.setAuth(auth, widget.server);
        }

        songs = await _jellyfinService.getSongsByAlbum(widget.album.id);
      }

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
    setState(() {
      _isLoading = true;
    });

    try {
      final auth = await _settingsService.getAuth();
      if (auth != null) {
        _jellyfinService.setAuth(auth, widget.server);
      }

      final songs = await _jellyfinService.getSongsByAlbum(widget.album.id, forceRefresh: true);
      setState(() {
        _songs = songs;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refreshed song list')),
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

  void _handleShuffle() {
    if (_songs == null || _songs!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No songs to shuffle')),
      );
      return;
    }

    final shuffled = ShuffleHelper.shuffleSongs(_songs!);

    // Get player provider and start playback
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final auth = _settingsService.getAuth();

    // Set server info for playback
    auth.then((a) {
      player.audioService.setServerInfo(
        widget.server,
        a,
        isOfflineMode: widget.isOfflineMode,
      );

      // Start playback with shuffled queue
      player.audioService.playQueue(shuffled);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shuffling ${shuffled.length} songs from ${widget.album.name}')),
      );
    });
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

      int currentSong = 0;
      int totalSongs = _songs!.length;

      await _downloadService.downloadAlbum(
        albumId: widget.album.id,
        albumName: widget.album.name,
        artistName: widget.album.artistName ?? 'Unknown Artist',
        songs: _songs!,
        server: widget.server,
        auth: auth,
        onProgress: (current, total) {
          currentSong = current;
          totalSongs = total;
        },
        libraryName: widget.libraryName,
      );

      setState(() {
        _isDownloading = false;
        _isDownloaded = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${_songs!.length} songs from ${widget.album.name}'),
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

  /// Group songs by disc number
  Map<int, List<JellyfinSong>> _groupSongsByDisc() {
    if (_songs == null) return {};

    final Map<int, List<JellyfinSong>> discs = {};

    for (final song in _songs!) {
      final discNumber = song.discNumber ?? 1;
      discs.putIfAbsent(discNumber, () => []);
      discs[discNumber]!.add(song);
    }

    return discs;
  }

  /// Check if album has multiple discs
  bool _hasMultipleDiscs() {
    return _groupSongsByDisc().length > 1;
  }

  Widget _buildSongList() {
    final discGroups = _groupSongsByDisc();
    final sortedDiscNumbers = discGroups.keys.toList()..sort();
    final hasMultipleDiscs = sortedDiscNumbers.length > 1;

    // Build a flat list of widgets with disc headers
    final List<Widget> items = [];

    for (final discNumber in sortedDiscNumbers) {
      final songs = discGroups[discNumber]!;

      // Add disc header if there are multiple discs
      if (hasMultipleDiscs) {
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Disc $discNumber',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        );
      }

      // Add songs for this disc
      for (final song in songs) {
        items.add(
          ListTile(
            leading: CircleAvatar(
              child: Text(
                song.trackNumber?.toString() ?? '?',
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
            onTap: () async {
              // Play the song
              final player = Provider.of<PlayerProvider>(context, listen: false);
              final auth = await _settingsService.getAuth();

              player.audioService.setServerInfo(
                widget.server,
                auth,
                isOfflineMode: widget.isOfflineMode,
              );

              // Find the index of this song in the full song list
              final songIndex = _songs!.indexOf(song);
              if (songIndex != -1) {
                await player.audioService.playQueue(_songs!, startIndex: songIndex);
              }
            },
          ),
        );
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => items[index],
        childCount: items.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.album.getImageUrl(widget.server.baseUrl);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.album.name,
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
                            Icons.album,
                            size: 64,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.album,
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
                  if (widget.album.artistName != null)
                    Text(
                      widget.album.artistName!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  if (widget.album.year != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.album.year.toString(),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
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
                  : _buildSongList(),
        ],
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
                        tooltip: 'Download album',
                        onPressed: _isLoading || _isDownloading ? null : _handleDownload,
                      ),
              // Shuffle and refresh on the right
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shuffle),
                    tooltip: 'Shuffle album',
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
