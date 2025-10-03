import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        if (!player.hasQueue) {
          // Don't show player if no queue
          return const SizedBox.shrink();
        }

        final song = player.currentSong;
        if (song == null) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error banner
              if (player.hasError)
                Container(
                  width: double.infinity,
                  color: Colors.red[700],
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          player.lastError ?? 'Unknown error',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 16),
                        onPressed: () => player.clearError(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 16,
                      ),
                    ],
                  ),
                ),
              // Progress bar
              StreamBuilder<Duration>(
                stream: player.audioService.player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = player.duration ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;

                  return LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 2,
                    backgroundColor: Colors.grey[300],
                  );
                },
              ),
              // Player controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Song info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (song.artistName != null)
                            Text(
                              song.artistName!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Time display
                    StreamBuilder<Duration>(
                      stream: player.audioService.player.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        return Text(
                          '${_formatDuration(position)} / ${_formatDuration(player.duration)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Previous button
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: player.hasPrevious ? () => player.skipPrevious() : null,
                      iconSize: 28,
                    ),
                    // Play/Pause button
                    StreamBuilder<bool>(
                      stream: player.audioService.player.playingStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: () => player.togglePlayPause(),
                          iconSize: 36,
                        );
                      },
                    ),
                    // Next button
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: player.hasNext ? () => player.skipNext() : null,
                      iconSize: 28,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
