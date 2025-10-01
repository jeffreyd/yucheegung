import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:io';
import '../models/jellyfin_song.dart';
import '../models/jellyfin_server.dart';
import '../models/jellyfin_auth.dart';
import 'offline_service.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final _player = AudioPlayer();
  final _offlineService = OfflineService();

  List<JellyfinSong> _queue = [];
  int _currentIndex = 0;
  JellyfinServer? _server;
  JellyfinAuth? _auth;
  bool _isOfflineMode = false;

  // Getters
  AudioPlayer get player => _player;
  List<JellyfinSong> get queue => _queue;
  int get currentIndex => _currentIndex;
  JellyfinSong? get currentSong => _queue.isNotEmpty && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  /// Initialize the player with server and auth info
  void setServerInfo(JellyfinServer server, JellyfinAuth? auth, {bool isOfflineMode = false}) {
    _server = server;
    _auth = auth;
    _isOfflineMode = isOfflineMode;
  }

  /// Play a queue of songs starting at a specific index
  Future<void> playQueue(
    List<JellyfinSong> songs, {
    int startIndex = 0,
  }) async {
    if (songs.isEmpty) return;

    _queue = songs;
    _currentIndex = startIndex;

    await _playSongAtIndex(_currentIndex);
  }

  /// Play a single song (creates a queue with just that song)
  Future<void> playSong(JellyfinSong song) async {
    await playQueue([song], startIndex: 0);
  }

  /// Play the song at a specific index in the queue
  Future<void> _playSongAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;

    _currentIndex = index;
    final song = _queue[index];

    // Update media notification for Android Auto
    await _updateMediaItem(song);

    try {
      if (_isOfflineMode) {
        // Play from local file
        final filePath = await _offlineService.getSongFilePath(song.id);
        if (filePath == null) {
          throw Exception('Song file not found offline');
        }

        print('DEBUG: Playing offline file: $filePath');
        await _player.setFilePath(filePath);
      } else {
        // Stream from server
        if (_server == null) {
          throw Exception('Server not configured');
        }

        final streamUrl = _buildStreamUrl(song.id);
        print('DEBUG: Streaming song: ${song.name}');

        // Try using LockCachingAudioSource which might handle network better
        final audioSource = LockCachingAudioSource(
          Uri.parse(streamUrl),
          headers: {
            'X-Emby-Authorization': _buildAuthHeader(),
          },
        );

        print('DEBUG: Setting audio source...');
        await _player.setAudioSource(audioSource);
        print('DEBUG: Audio source set successfully');
      }

      // Start playback
      await _player.play();
    } catch (e, stackTrace) {
      print('DEBUG: Error playing song: $e');
      print('DEBUG: Stack trace: $stackTrace');

      // Try to get more details from the player state
      print('DEBUG: Player state: ${_player.playerState}');
      print('DEBUG: Processing state: ${_player.playerState.processingState}');

      rethrow;
    }
  }

  /// Build Jellyfin auth header
  String _buildAuthHeader() {
    final parts = [
      'MediaBrowser Client="YuCheeGung"',
      'Device="Flutter"',
      'DeviceId="yucheegung-flutter"',
      'Version="1.0.0"',
    ];

    if (_auth != null) {
      parts.add('Token="${_auth!.accessToken}"');
    }

    return parts.join(', ');
  }

  /// Build streaming URL for online playback
  String _buildStreamUrl(String songId) {
    if (_server == null) {
      throw Exception('Server not configured');
    }

    final baseUrl = _server!.baseUrl;
    final userId = _auth?.userId ?? '';

    // Use the universal endpoint for smart streaming with transcoding support
    return '$baseUrl/Audio/$songId/universal?'
        'UserId=$userId&'
        'DeviceId=yucheegung-flutter&'
        'MaxStreamingBitrate=140000000&'
        'Container=opus,mp3,aac,m4a,flac,webma,webm,wav,ogg&'
        'TranscodingContainer=aac&'
        'TranscodingProtocol=hls&'
        'AudioCodec=aac';
  }

  /// Skip to next song
  Future<void> skipNext() async {
    if (hasNext) {
      await _playSongAtIndex(_currentIndex + 1);
    }
  }

  /// Skip to previous song
  Future<void> skipPrevious() async {
    if (hasPrevious) {
      await _playSongAtIndex(_currentIndex - 1);
    } else {
      // If at the start, restart current song
      await _player.seek(Duration.zero);
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await _player.pause();
  }

  /// Resume playback
  Future<void> play() async {
    await _player.play();
  }

  /// Seek to a position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Stop playback and clear queue
  Future<void> stop() async {
    await _player.stop();
    _queue = [];
    _currentIndex = 0;
  }

  /// Dispose the player
  Future<void> dispose() async {
    await _player.dispose();
  }

  /// Set up listener for when a song completes
  void setupAutoAdvance() {
    _player.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        // Automatically advance to next song, or loop back to start
        if (hasNext) {
          await skipNext();
        } else if (_queue.isNotEmpty) {
          // Loop back to the beginning
          await _playSongAtIndex(0);
        }
      }
    });
  }

  /// Update media item for Android Auto and notification
  Future<void> _updateMediaItem(JellyfinSong song) async {
    // Convert runTimeTicks to Duration (Jellyfin uses ticks where 10,000,000 ticks = 1 second)
    Duration? songDuration;
    if (song.runTimeTicks != null) {
      songDuration = Duration(microseconds: (song.runTimeTicks! / 10).round());
    }

    final mediaItem = MediaItem(
      id: song.id,
      title: song.name,
      artist: song.artistName ?? 'Unknown Artist',
      album: song.albumId ?? '',
      duration: songDuration,
      artUri: _server != null && song.albumId != null
          ? Uri.parse('${_server!.baseUrl}/Items/${song.albumId}/Images/Primary')
          : null,
    );

    try {
      await AudioService.updateMediaItem(mediaItem);
      print('DEBUG: Updated media item: ${song.name}');
    } catch (e) {
      // AudioService might not be initialized, that's okay
      print('DEBUG: Could not update media item: $e');
    }
  }
}
