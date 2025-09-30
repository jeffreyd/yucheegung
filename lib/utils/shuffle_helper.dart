import 'dart:math';
import '../models/jellyfin_song.dart';

class ShuffleHelper {
  /// Properly shuffle a list of songs using Fisher-Yates algorithm
  /// This ensures a true random shuffle without patterns
  static List<JellyfinSong> shuffleSongs(List<JellyfinSong> songs) {
    final List<JellyfinSong> shuffled = List.from(songs);
    final random = Random();

    // Fisher-Yates shuffle algorithm
    for (int i = shuffled.length - 1; i > 0; i--) {
      final int j = random.nextInt(i + 1);
      final temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }

    return shuffled;
  }
}
