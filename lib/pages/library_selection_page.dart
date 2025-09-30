import 'package:flutter/material.dart';
import '../models/jellyfin_auth.dart';
import '../models/jellyfin_library.dart';
import '../models/jellyfin_server.dart';
import '../services/jellyfin_service.dart';
import '../services/settings_service.dart';

class LibrarySelectionPage extends StatefulWidget {
  final JellyfinServer server;
  final JellyfinAuth auth;

  const LibrarySelectionPage({
    super.key,
    required this.server,
    required this.auth,
  });

  @override
  State<LibrarySelectionPage> createState() => _LibrarySelectionPageState();
}

class _LibrarySelectionPageState extends State<LibrarySelectionPage> {
  final _jellyfinService = JellyfinService();
  final _settingsService = SettingsService();

  List<JellyfinLibrary>? _libraries;
  Set<String> _selectedLibraryIds = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadLibraries();
  }

  Future<void> _loadLibraries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _jellyfinService.setAuth(widget.auth, widget.server);
      final libraries = await _jellyfinService.getMusicLibraries();

      setState(() {
        _libraries = libraries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load libraries: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleContinue() async {
    if (_selectedLibraryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one library'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _settingsService.saveAuth(widget.auth);
      await _settingsService.saveSelectedLibraries(_selectedLibraryIds.toList());

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Libraries'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose Music Libraries',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select which libraries you want to use in YuCheeGung',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildContent(),
            ),
            if (_libraries != null && _libraries!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FilledButton(
                  onPressed: _isSaving ? null : _handleContinue,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Continue (${_selectedLibraryIds.length} selected)',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700]),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _loadLibraries,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_libraries == null || _libraries!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.library_music_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No music libraries found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Create a music library in your Jellyfin server first',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _libraries!.length,
      itemBuilder: (context, index) {
        final library = _libraries![index];
        final isSelected = _selectedLibraryIds.contains(library.id);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedLibraryIds.add(library.id);
              } else {
                _selectedLibraryIds.remove(library.id);
              }
            });
          },
          title: Text(library.name),
          subtitle: Text('Type: ${library.collectionType}'),
          secondary: const Icon(Icons.library_music),
        );
      },
    );
  }
}
