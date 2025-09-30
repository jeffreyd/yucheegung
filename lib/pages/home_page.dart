import 'package:flutter/material.dart';
import '../models/jellyfin_artist.dart';
import '../models/jellyfin_library.dart';
import '../models/jellyfin_server.dart';
import '../models/jellyfin_auth.dart';
import '../services/jellyfin_service.dart';
import '../services/settings_service.dart';
import 'artist_detail_page.dart';
import 'download_settings_page.dart';
import 'first_run_page.dart';
import 'playlist_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _settingsService = SettingsService();
  final _jellyfinService = JellyfinService();

  List<JellyfinLibrary>? _availableLibraries;
  List<String> _selectedLibraryIds = [];
  String? _currentLibraryId;
  JellyfinLibrary? _currentLibrary;
  JellyfinServer? _server;
  bool _isLoading = true;

  List<JellyfinArtist>? _artists;
  bool _isLoadingArtists = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final server = await _settingsService.getServer();
      final auth = await _settingsService.getAuth();
      final selectedIds = await _settingsService.getSelectedLibraries();

      print('DEBUG: server=$server, auth=$auth, selectedIds=$selectedIds');

      if (server != null && auth != null) {
        _server = server;
        _selectedLibraryIds = selectedIds;

        _jellyfinService.setAuth(auth, server);
        final libraries = await _jellyfinService.getMusicLibraries();

        print('DEBUG: All libraries: ${libraries.length}');
        for (var lib in libraries) {
          print('DEBUG: Library: ${lib.name} (${lib.id})');
        }
        print('DEBUG: Selected IDs: $selectedIds');

        // Filter to only show selected libraries
        final selected = libraries
            .where((lib) => selectedIds.contains(lib.id))
            .toList();

        print('DEBUG: Filtered libraries: ${selected.length}');

        setState(() {
          _availableLibraries = selected;
          if (selected.isNotEmpty) {
            _currentLibraryId = selected.first.id;
            _currentLibrary = selected.first;
          }
          _isLoading = false;
        });

        // Load artists for the first library
        if (selected.isNotEmpty) {
          await _loadArtists(selected.first.id);
        }
      }
    } catch (e) {
      print('DEBUG: Error in _loadData: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadArtists(String libraryId) async {
    setState(() {
      _isLoadingArtists = true;
    });

    try {
      final artists = await _jellyfinService.getArtists(libraryId);
      setState(() {
        _artists = artists;
        _isLoadingArtists = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingArtists = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading artists: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout? You will need to enter your server credentials again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _settingsService.clearAll();
      _jellyfinService.clearAuth();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const FirstRunPage()),
          (route) => false,
        );
      }
    }
  }

  void _selectLibrary(String libraryId) {
    final library = _availableLibraries?.firstWhere((lib) => lib.id == libraryId);
    setState(() {
      _currentLibraryId = libraryId;
      _currentLibrary = library;
    });
    Navigator.of(context).pop(); // Close drawer
    _loadArtists(libraryId); // Load artists for the selected library
  }

  Future<void> _handleRefresh() async {
    if (_currentLibraryId != null) {
      setState(() {
        _isLoadingArtists = true;
      });

      try {
        final artists = await _jellyfinService.getArtists(_currentLibraryId!, forceRefresh: true);
        setState(() {
          _artists = artists;
          _isLoadingArtists = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refreshed artist list')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoadingArtists = false;
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentLibrary?.name ?? 'YuCheeGung'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'YuCheeGung',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_server != null)
                    Text(
                      _server!.baseUrl,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withOpacity(0.7),
                          ),
                    ),
                ],
              ),
            ),
            if (_availableLibraries != null && _availableLibraries!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'LIBRARIES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
              ..._availableLibraries!.map((library) {
                final isSelected = library.id == _currentLibraryId;
                return ListTile(
                  leading: Icon(
                    Icons.library_music,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(library.name),
                  selected: isSelected,
                  onTap: () => _selectLibrary(library.id),
                );
              }),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download Settings'),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DownloadSettingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentLibrary == null
              ? const Center(
                  child: Text('No library selected'),
                )
              : _buildArtistList(),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _isLoadingArtists ? null : _handleRefresh,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtistList() {
    if (_isLoadingArtists) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_artists == null || _artists!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No artists found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'This library appears to be empty',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _artists!.length + 1, // +1 for the playlists item
      itemBuilder: (context, index) {
        // First item is the playlists link
        if (index == 0) {
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.playlist_play),
            ),
            title: const Text(
              '-- Playlists --',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PlaylistListPage(
                    server: _server!,
                  ),
                ),
              );
            },
          );
        }

        // Regular artist items (offset by 1)
        final artist = _artists![index - 1];
        final imageUrl = artist.getImageUrl(_server!.baseUrl);

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
            child: imageUrl == null
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(artist.name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ArtistDetailPage(
                  artist: artist,
                  server: _server!,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
