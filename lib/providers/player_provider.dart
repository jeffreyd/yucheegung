import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/jellyfin_song.dart';
import '../services/audio_player_service.dart';

class PlayerProvider extends ChangeNotifier {
  final _audioService = AudioPlayerService();

  PlayerProvider() {
    // Listen to player state changes
    _audioService.player.playerStateStream.listen((_) {
      notifyListeners();
    });

    // Listen to position changes
    _audioService.player.positionStream.listen((_) {
      notifyListeners();
    });

    // Listen to duration changes
    _audioService.player.durationStream.listen((_) {
      notifyListeners();
    });

    // Set up auto-advance when song completes
    _audioService.setupAutoAdvance();
  }

  // Getters
  AudioPlayerService get audioService => _audioService;
  JellyfinSong? get currentSong => _audioService.currentSong;
  List<JellyfinSong> get queue => _audioService.queue;
  int get currentIndex => _audioService.currentIndex;
  bool get isPlaying => _audioService.player.playing;
  bool get hasNext => _audioService.hasNext;
  bool get hasPrevious => _audioService.hasPrevious;
  Duration get position => _audioService.player.position;
  Duration? get duration => _audioService.player.duration;
  PlayerState get playerState => _audioService.player.playerState;

  // Convenience getters
  bool get hasQueue => queue.isNotEmpty;
  bool get isBuffering => playerState.processingState == ProcessingState.buffering ||
      playerState.processingState == ProcessingState.loading;

  // Actions
  Future<void> togglePlayPause() async {
    await _audioService.togglePlayPause();
    notifyListeners();
  }

  Future<void> skipNext() async {
    await _audioService.skipNext();
    notifyListeners();
  }

  Future<void> skipPrevious() async {
    await _audioService.skipPrevious();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioService.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
