import '../models/jellyfin_album.dart';
import '../models/jellyfin_artist.dart';
import '../models/jellyfin_song.dart';

class CacheEntry<T> {
  final T data;
  final DateTime timestamp;

  CacheEntry(this.data, this.timestamp);

  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }
}

class CacheService {
  // Singleton pattern
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Cache duration
  static const Duration _defaultCacheDuration = Duration(minutes: 30);

  // In-memory caches
  final Map<String, CacheEntry<List<JellyfinArtist>>> _artistsCache = {};
  final Map<String, CacheEntry<List<JellyfinAlbum>>> _albumsCache = {};
  final Map<String, CacheEntry<List<JellyfinSong>>> _songsCache = {};

  /// Cache artists for a library
  void cacheArtists(String libraryId, List<JellyfinArtist> artists) {
    _artistsCache[libraryId] = CacheEntry(artists, DateTime.now());
  }

  /// Get cached artists for a library
  List<JellyfinArtist>? getCachedArtists(String libraryId, {Duration? maxAge}) {
    final entry = _artistsCache[libraryId];
    if (entry == null) return null;

    if (entry.isExpired(maxAge ?? _defaultCacheDuration)) {
      _artistsCache.remove(libraryId);
      return null;
    }

    return entry.data;
  }

  /// Cache albums for an artist
  void cacheAlbums(String artistId, List<JellyfinAlbum> albums) {
    _albumsCache[artistId] = CacheEntry(albums, DateTime.now());
  }

  /// Get cached albums for an artist
  List<JellyfinAlbum>? getCachedAlbums(String artistId, {Duration? maxAge}) {
    final entry = _albumsCache[artistId];
    if (entry == null) return null;

    if (entry.isExpired(maxAge ?? _defaultCacheDuration)) {
      _albumsCache.remove(artistId);
      return null;
    }

    return entry.data;
  }

  /// Cache songs for an album
  void cacheSongs(String albumId, List<JellyfinSong> songs) {
    _songsCache[albumId] = CacheEntry(songs, DateTime.now());
  }

  /// Get cached songs for an album
  List<JellyfinSong>? getCachedSongs(String albumId, {Duration? maxAge}) {
    final entry = _songsCache[albumId];
    if (entry == null) return null;

    if (entry.isExpired(maxAge ?? _defaultCacheDuration)) {
      _songsCache.remove(albumId);
      return null;
    }

    return entry.data;
  }

  /// Clear all caches
  void clearAll() {
    _artistsCache.clear();
    _albumsCache.clear();
    _songsCache.clear();
  }

  /// Clear artists cache
  void clearArtistsCache() {
    _artistsCache.clear();
  }

  /// Clear albums cache
  void clearAlbumsCache() {
    _albumsCache.clear();
  }

  /// Clear songs cache
  void clearSongsCache() {
    _songsCache.clear();
  }

  /// Clear expired entries from all caches
  void clearExpired({Duration? maxAge}) {
    final duration = maxAge ?? _defaultCacheDuration;

    _artistsCache.removeWhere((key, entry) => entry.isExpired(duration));
    _albumsCache.removeWhere((key, entry) => entry.isExpired(duration));
    _songsCache.removeWhere((key, entry) => entry.isExpired(duration));
  }
}
