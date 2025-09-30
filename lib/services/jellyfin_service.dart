import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/jellyfin_album.dart';
import '../models/jellyfin_artist.dart';
import '../models/jellyfin_auth.dart';
import '../models/jellyfin_library.dart';
import '../models/jellyfin_playlist.dart';
import '../models/jellyfin_server.dart';
import '../models/jellyfin_song.dart';
import 'cache_service.dart';

class JellyfinService {
  static const String clientName = 'YuCheeGung';
  static const String clientVersion = '1.0.0';
  static const String deviceId = 'yucheegung-flutter';

  JellyfinAuth? _auth;
  JellyfinServer? _server;
  final _cache = CacheService();

  String get _authHeader {
    final parts = [
      'MediaBrowser Client="$clientName"',
      'Device="Flutter"',
      'DeviceId="$deviceId"',
      'Version="$clientVersion"',
    ];

    if (_auth != null) {
      parts.add('Token="${_auth!.accessToken}"');
    }

    return parts.join(', ');
  }

  /// Authenticate with Jellyfin server
  Future<JellyfinAuth> authenticate(JellyfinServer server) async {
    _server = server;

    final url = Uri.parse('${server.baseUrl}/Users/AuthenticateByName');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Emby-Authorization': _authHeader,
      },
      body: jsonEncode({
        'Username': server.username,
        'Pw': server.password,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _auth = JellyfinAuth.fromJson(json);
      return _auth!;
    } else {
      throw Exception(
          'Authentication failed: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get all libraries from Jellyfin server
  Future<List<JellyfinLibrary>> getLibraries() async {
    if (_auth == null || _server == null) {
      throw Exception('Not authenticated');
    }

    final url = Uri.parse(
        '${_server!.baseUrl}/Users/${_auth!.userId}/Views');

    final response = await http.get(
      url,
      headers: {
        'X-Emby-Authorization': _authHeader,
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['Items'] as List<dynamic>;

      return items
          .map((item) => JellyfinLibrary.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
          'Failed to fetch libraries: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get only music/audio libraries
  Future<List<JellyfinLibrary>> getMusicLibraries() async {
    final libraries = await getLibraries();
    return libraries.where((lib) => lib.isMusic).toList();
  }

  /// Get artists from a specific library
  /// Fetches both MusicArtist and AlbumArtist types and combines them
  Future<List<JellyfinArtist>> getArtists(String libraryId, {bool forceRefresh = false}) async {
    if (_auth == null || _server == null) {
      throw Exception('Not authenticated');
    }

    // Check cache first
    if (!forceRefresh) {
      final cached = _cache.getCachedArtists(libraryId);
      if (cached != null) {
        print('DEBUG: Returning ${cached.length} artists from cache');
        return cached;
      }
    }

    // Try the AlbumArtists endpoint first (this is what most music libraries use)
    try {
      final artistsUrl = Uri.parse(
        '${_server!.baseUrl}/Artists/AlbumArtists',
      ).replace(queryParameters: {
        'parentId': libraryId,
        'userId': _auth!.userId,
        'sortBy': 'SortName',
        'sortOrder': 'Ascending',
        'recursive': 'true',
        'fields': 'PrimaryImageAspectRatio,SortName,BasicSyncInfo',
        'limit': '10000',
        'startIndex': '0',
      });

      final artistsResponse = await http.get(
        artistsUrl,
        headers: {
          'X-Emby-Authorization': _authHeader,
        },
      );

      if (artistsResponse.statusCode == 200) {
        final json = jsonDecode(artistsResponse.body) as Map<String, dynamic>;
        final items = json['Items'] as List<dynamic>;
        final totalCount = json['TotalRecordCount'] as int?;

        print('DEBUG: Fetched ${items.length} album artists out of $totalCount total from server');

        final artists = items
            .map((item) => JellyfinArtist.fromJson(item as Map<String, dynamic>))
            .toList();

        // Cache the results
        _cache.cacheArtists(libraryId, artists);

        return artists;
      }
    } catch (e) {
      print('DEBUG: AlbumArtists endpoint failed: $e');
    }

    // Fallback to regular Items endpoint
    final url = Uri.parse(
      '${_server!.baseUrl}/Users/${_auth!.userId}/Items',
    ).replace(queryParameters: {
      'parentId': libraryId,
      'includeItemTypes': 'MusicArtist',
      'sortBy': 'SortName',
      'sortOrder': 'Ascending',
      'recursive': 'true',
      'fields': 'PrimaryImageAspectRatio,SortName,BasicSyncInfo',
      'limit': '10000',
      'startIndex': '0',
    });

    final response = await http.get(
      url,
      headers: {
        'X-Emby-Authorization': _authHeader,
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['Items'] as List<dynamic>;
      final totalCount = json['TotalRecordCount'] as int?;

      print('DEBUG: Fetched ${items.length} music artists out of $totalCount total from server');

      final artists = items
          .map((item) => JellyfinArtist.fromJson(item as Map<String, dynamic>))
          .toList();

      // Cache the results
      _cache.cacheArtists(libraryId, artists);

      return artists;
    } else {
      throw Exception(
          'Failed to fetch artists: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get albums by a specific artist
  Future<List<JellyfinAlbum>> getAlbumsByArtist(String artistId, {bool forceRefresh = false}) async {
    if (_auth == null || _server == null) {
      throw Exception('Not authenticated');
    }

    // Check cache first
    if (!forceRefresh) {
      final cached = _cache.getCachedAlbums(artistId);
      if (cached != null) {
        print('DEBUG: Returning ${cached.length} albums from cache');
        return cached;
      }
    }

    final url = Uri.parse(
      '${_server!.baseUrl}/Users/${_auth!.userId}/Items',
    ).replace(queryParameters: {
      'artistIds': artistId,
      'includeItemTypes': 'MusicAlbum',
      'sortBy': 'ProductionYear,SortName',
      'sortOrder': 'Descending',
      'recursive': 'true',
      'fields': 'PrimaryImageAspectRatio,SortName,ProductionYear',
      'limit': '10000',
      'startIndex': '0',
    });

    final response = await http.get(
      url,
      headers: {
        'X-Emby-Authorization': _authHeader,
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['Items'] as List<dynamic>;

      final albums = items
          .map((item) => JellyfinAlbum.fromJson(item as Map<String, dynamic>))
          .toList();

      // Cache the results
      _cache.cacheAlbums(artistId, albums);
      print('DEBUG: Fetched ${albums.length} albums from server');

      return albums;
    } else {
      throw Exception(
          'Failed to fetch albums: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get songs from a specific album
  Future<List<JellyfinSong>> getSongsByAlbum(String albumId, {bool forceRefresh = false}) async {
    if (_auth == null || _server == null) {
      throw Exception('Not authenticated');
    }

    // Check cache first
    if (!forceRefresh) {
      final cached = _cache.getCachedSongs(albumId);
      if (cached != null) {
        print('DEBUG: Returning ${cached.length} songs from cache');
        return cached;
      }
    }

    final url = Uri.parse(
      '${_server!.baseUrl}/Users/${_auth!.userId}/Items',
    ).replace(queryParameters: {
      'parentId': albumId,
      'includeItemTypes': 'Audio',
      'sortBy': 'ParentIndexNumber,IndexNumber,SortName',
      'sortOrder': 'Ascending',
      'fields': 'AudioInfo,ParentId',
      'limit': '10000',
      'startIndex': '0',
    });

    final response = await http.get(
      url,
      headers: {
        'X-Emby-Authorization': _authHeader,
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['Items'] as List<dynamic>;

      final songs = items
          .map((item) => JellyfinSong.fromJson(item as Map<String, dynamic>))
          .toList();

      // Cache the results
      _cache.cacheSongs(albumId, songs);
      print('DEBUG: Fetched ${songs.length} songs from server');

      return songs;
    } else {
      throw Exception(
          'Failed to fetch songs: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get playlists for the user
  Future<List<JellyfinPlaylist>> getPlaylists({bool forceRefresh = false}) async {
    if (_auth == null || _server == null) {
      throw Exception('Not authenticated');
    }

    final url = Uri.parse(
      '${_server!.baseUrl}/Users/${_auth!.userId}/Items',
    ).replace(queryParameters: {
      'includeItemTypes': 'Playlist',
      'sortBy': 'SortName',
      'sortOrder': 'Ascending',
      'recursive': 'true',
      'fields': 'PrimaryImageAspectRatio,ChildCount',
      'limit': '10000',
      'startIndex': '0',
    });

    final response = await http.get(
      url,
      headers: {
        'X-Emby-Authorization': _authHeader,
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['Items'] as List<dynamic>;

      final playlists = items
          .map((item) => JellyfinPlaylist.fromJson(item as Map<String, dynamic>))
          .toList();

      print('DEBUG: Fetched ${playlists.length} playlists from server');

      return playlists;
    } else {
      throw Exception(
          'Failed to fetch playlists: ${response.statusCode} - ${response.body}');
    }
  }

  /// Set authentication for existing session
  void setAuth(JellyfinAuth auth, JellyfinServer server) {
    _auth = auth;
    _server = server;
  }

  /// Clear authentication
  void clearAuth() {
    _auth = null;
    _server = null;
  }
}
