import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../services/settings_service.dart';
import 'dart:io';

class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  final _settingsService = SettingsService();
  String? _downloadLocation;
  bool _isLoading = true;
  bool _hasStoragePermission = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    final location = await _settingsService.getDownloadLocation();
    final hasPermission = await _checkStoragePermission();

    setState(() {
      _downloadLocation = location;
      _hasStoragePermission = hasPermission;
      _isLoading = false;
    });
  }

  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 11+ (API 30+), we need to request MANAGE_EXTERNAL_STORAGE
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      // For older Android versions
      if (await Permission.storage.isGranted) {
        return true;
      }

      return false;
    }
    // iOS doesn't need storage permission for app-specific directories
    return true;
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Try to request MANAGE_EXTERNAL_STORAGE permission
      final status = await Permission.manageExternalStorage.request();

      if (status.isGranted) {
        setState(() {
          _hasStoragePermission = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission granted')),
          );
        }
      } else if (status.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission denied'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (status.isPermanentlyDenied) {
        // Show dialog to open app settings
        _showPermissionSettingsDialog();
      }
    }
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
          'YuCheeGung needs storage permission to download music files. '
          'Please grant "All files access" permission in the app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDownloadLocation() async {
    if (!_hasStoragePermission) {
      await _requestStoragePermission();
      return;
    }

    try {
      final result = await FilePicker.platform.getDirectoryPath();

      if (result != null) {
        await _settingsService.saveDownloadLocation(result);
        setState(() {
          _downloadLocation = result;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download location saved')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting folder: $e'),
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
        title: const Text('Download Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _hasStoragePermission
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: _hasStoragePermission
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Storage Permission',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hasStoragePermission
                              ? 'Storage access granted'
                              : 'Storage access required for downloads',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (!_hasStoragePermission) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _requestStoragePermission,
                            icon: const Icon(Icons.security),
                            label: const Text('Grant Permission'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.folder),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Download Location',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_downloadLocation != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _downloadLocation!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          Text(
                            'No download location selected',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          onPressed: _selectDownloadLocation,
                          icon: const Icon(Icons.folder_open),
                          label: Text(
                            _downloadLocation == null
                                ? 'Select Download Folder'
                                : 'Change Download Folder',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[700]),
                            const SizedBox(width: 12),
                            Text(
                              'About Storage Access',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'YuCheeGung needs "All files access" permission to download music to your chosen folder. '
                          'This permission allows the app to save downloaded songs to any location on your device.',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 13,
                          ),
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
