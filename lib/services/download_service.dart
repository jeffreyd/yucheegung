import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import '../models/jellyfin_song.dart';
import '../models/jellyfin_album.dart';
import '../models/jellyfin_server.dart';
import '../models/jellyfin_auth.dart';
import 'settings_service.dart';
import 'download_database.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final _dio = Dio();
  final _settingsService = SettingsService();
  final _downloadDb = DownloadDatabase();
  final Map<String, bool> _downloadedItems = {}; // itemId -> isDownloaded (cache)

  /// Check if an item (album/playlist) is fully downloaded
  Future<bool> isItemDownloaded(String itemId) async {
    // Check in-memory cache first
    if (_downloadedItems.containsKey(itemId)) {
      return _downloadedItems[itemId]!;
    }

    // Check database
    final isDownloaded = await _downloadDb.isItemDownloaded(itemId);
    _downloadedItems[itemId] = isDownloaded;
    return isDownloaded;
  }

  /// Download all songs from an album
  Future<void> downloadAlbum({
    required String albumId,
    required String albumName,
    required String artistName,
    required List<JellyfinSong> songs,
    required JellyfinServer server,
    required JellyfinAuth auth,
    required Function(int current, int total) onProgress,
  }) async {
    final downloadLocation = await _settingsService.getDownloadLocation();
    if (downloadLocation == null) {
      throw Exception('No download location set. Please configure download settings first.');
    }

    // Create album directory: DownloadLocation/ArtistName/AlbumName
    final sanitizedArtist = _sanitizeFilename(artistName);
    final sanitizedAlbum = _sanitizeFilename(albumName);
    final albumDir = path.join(downloadLocation, sanitizedArtist, sanitizedAlbum);

    final dir = Directory(albumDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Download each song
    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];
      final filePath = await _downloadSong(
        song: song,
        directory: albumDir,
        server: server,
        auth: auth,
      );

      // Record song in database
      if (filePath != null) {
        final file = File(filePath);
        final fileSize = await file.exists() ? await file.length() : null;

        await _downloadDb.addDownloadedSong(
          songId: song.id,
          itemId: albumId,
          songName: song.name,
          filePath: filePath,
          fileSize: fileSize,
        );
      }

      onProgress(i + 1, songs.length);
    }

    // Mark album as downloaded in database
    await _downloadDb.markItemAsDownloaded(
      itemId: albumId,
      itemType: 'album',
      itemName: albumName,
      artistName: artistName,
      downloadPath: albumDir,
      songCount: songs.length,
    );

    // Update cache
    _downloadedItems[albumId] = true;
  }

  /// Download a single song
  /// Returns the file path if successful, null otherwise
  Future<String?> _downloadSong({
    required JellyfinSong song,
    required String directory,
    required JellyfinServer server,
    required JellyfinAuth auth,
  }) async {
    // Build filename with disc and track numbers
    String filename = '';

    if (song.discNumber != null && song.discNumber! > 1) {
      filename += '${song.discNumber}-';
    }

    if (song.trackNumber != null) {
      filename += '${song.trackNumber.toString().padLeft(2, '0')} - ';
    }

    filename += _sanitizeFilename(song.name);

    // Get file extension from song (defaulting to .mp3 if not available)
    // Jellyfin typically provides this in the MediaType or Container field
    final extension = '.mp3'; // We'll improve this later with actual format detection
    filename += extension;

    final filePath = path.join(directory, filename);
    final file = File(filePath);

    // Skip if already exists
    if (await file.exists()) {
      print('DEBUG: Song already exists: $filename');
      return filePath;
    }

    // Build download URL
    final downloadUrl = '${server.baseUrl}/Items/${song.id}/Download';

    try {
      print('DEBUG: Downloading $filename');

      await _dio.download(
        downloadUrl,
        filePath,
        options: Options(
          headers: {
            'X-Emby-Authorization': _buildAuthHeader(auth),
          },
        ),
      );

      print('DEBUG: Downloaded $filename');
      return filePath;
    } catch (e) {
      print('DEBUG: Error downloading $filename: $e');
      // Delete partial file if it exists
      if (await file.exists()) {
        await file.delete();
      }
      return null;
    }
  }

  /// Build Jellyfin auth header
  String _buildAuthHeader(JellyfinAuth auth) {
    final parts = [
      'MediaBrowser Client="YuCheeGung"',
      'Device="Flutter"',
      'DeviceId="yucheegung-flutter"',
      'Version="1.0.0"',
      'Token="${auth.accessToken}"',
    ];
    return parts.join(', ');
  }

  /// Sanitize filename to remove invalid characters
  String _sanitizeFilename(String filename) {
    // Remove or replace invalid filename characters
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Clear download cache (for testing/debugging)
  void clearCache() {
    _downloadedItems.clear();
  }
}
