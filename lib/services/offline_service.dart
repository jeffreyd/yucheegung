import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/jellyfin_album.dart';
import '../models/jellyfin_artist.dart';
import '../models/jellyfin_playlist.dart';
import '../models/jellyfin_song.dart';
import 'download_database.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  final _downloadDb = DownloadDatabase();

  /// Get all downloaded artists
  Future<List<JellyfinArtist>> getDownloadedArtists() async {
    final downloads = await _downloadDb.getAllDownloads();

    // Group by artist name and create artist objects
    final Map<String, JellyfinArtist> artistMap = {};

    for (final download in downloads) {
      final artistName = download['artist_name'] as String?;
      if (artistName == null || artistName.isEmpty || artistName == 'Playlists') continue;

      if (!artistMap.containsKey(artistName)) {
        // Create a synthetic artist ID based on name
        final artistId = 'offline_artist_${artistName.toLowerCase().replaceAll(' ', '_')}';
        artistMap[artistName] = JellyfinArtist(
          id: artistId,
          name: artistName,
          imageTag: null,
        );
      }
    }

    return artistMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Get all downloaded playlists
  Future<List<JellyfinPlaylist>> getDownloadedPlaylists() async {
    final downloads = await _downloadDb.getAllDownloads();

    final playlists = <JellyfinPlaylist>[];

    for (final download in downloads) {
      final artistName = download['artist_name'] as String?;
      if (artistName != 'Playlists') continue;

      final songs = await _downloadDb.getSongsForItem(download['item_id'] as String);

      playlists.add(JellyfinPlaylist(
        id: download['item_id'] as String,
        name: download['item_name'] as String,
        imageTag: null,
        songCount: songs.length,
      ));
    }

    return playlists..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Get downloaded albums by artist name
  Future<List<JellyfinAlbum>> getDownloadedAlbumsByArtist(String artistName) async {
    final downloads = await _downloadDb.getAllDownloads();

    final albums = <JellyfinAlbum>[];

    for (final download in downloads) {
      if (download['artist_name'] == artistName && download['item_type'] == 'album') {
        // Try to extract year from directory name or use null
        albums.add(JellyfinAlbum(
          id: download['item_id'] as String,
          name: download['item_name'] as String,
          artistName: artistName,
          imageTag: null,
          year: null, // We don't store year in the database currently
        ));
      }
    }

    return albums..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Get downloaded songs for an album/playlist
  Future<List<JellyfinSong>> getDownloadedSongs(String itemId) async {
    final songRecords = await _downloadDb.getSongsForItem(itemId);

    final songs = <JellyfinSong>[];

    for (final record in songRecords) {
      final filePath = record['file_path'] as String;
      final fileName = path.basename(filePath);

      // Try to parse disc and track number from filename
      // Expected format: "1-01 - Song Name.mp3" or "01 - Song Name.mp3"
      int? discNumber;
      int? trackNumber;
      String songName = record['song_name'] as String;

      final match = RegExp(r'^(?:(\d+)-)?(\d+)\s*-\s*(.+)\.\w+$').firstMatch(fileName);
      if (match != null) {
        if (match.group(1) != null) {
          discNumber = int.tryParse(match.group(1)!);
        }
        trackNumber = int.tryParse(match.group(2)!);
        songName = match.group(3)!;
      }

      songs.add(JellyfinSong(
        id: record['song_id'] as String,
        name: songName,
        artistName: null, // We don't store this separately
        albumId: itemId,
        discNumber: discNumber,
        trackNumber: trackNumber,
      ));
    }

    // Sort by disc number, then track number
    songs.sort((a, b) {
      final discCompare = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
      if (discCompare != 0) return discCompare;
      return (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
    });

    return songs;
  }

  /// Check if we have any downloaded content
  Future<bool> hasDownloadedContent() async {
    final count = await _downloadDb.getDownloadCount();
    return count > 0;
  }

  /// Get the local file path for a song
  Future<String?> getSongFilePath(String songId) async {
    final db = await _downloadDb.database;
    final result = await db.query(
      'downloaded_songs',
      columns: ['file_path'],
      where: 'song_id = ?',
      whereArgs: [songId],
    );

    if (result.isEmpty) return null;

    final filePath = result.first['file_path'] as String;
    final file = File(filePath);

    // Verify file exists
    if (await file.exists()) {
      return filePath;
    }

    return null;
  }

  /// Check if a specific item is available offline
  Future<bool> isAvailableOffline(String itemId) async {
    return await _downloadDb.isItemDownloaded(itemId);
  }
}
