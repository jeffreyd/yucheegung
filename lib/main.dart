import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'pages/first_run_page.dart';
import 'pages/home_page.dart';
import 'services/settings_service.dart';
import 'providers/player_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize audio service for Android Auto support
  try {
    await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.yucheegung.audio',
        androidNotificationChannelName: 'YuCheeGung Audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    print('DEBUG: Failed to initialize AudioService: $e');
    // Continue anyway - app will work without Android Auto
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => PlayerProvider(),
      child: const MyApp(),
    ),
  );
}

/// Audio handler for Android Auto integration
class AudioPlayerHandler extends BaseAudioHandler {
  AudioPlayerHandler() {
    // Set initial playback state
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.pause,
        MediaControl.skipToNext,
      ],
      processingState: AudioProcessingState.idle,
    ));
  }

  @override
  Future<void> play() async {
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.ready,
    ));
  }

  @override
  Future<void> pause() async {
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.ready,
    ));
  }

  @override
  Future<void> skipToNext() async {
    // Handled by AudioPlayerService
  }

  @override
  Future<void> skipToPrevious() async {
    // Handled by AudioPlayerService
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YuCheeGung',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const InitialRoute(),
      routes: {
        '/home': (context) => const HomePage(),
        '/setup': (context) => const FirstRunPage(),
      },
    );
  }
}

class InitialRoute extends StatelessWidget {
  const InitialRoute({super.key});

  Future<_AppState> _checkAppState() async {
    final settingsService = SettingsService();
    final isFirstRun = await settingsService.isFirstRun();

    if (isFirstRun) {
      return _AppState.firstRun;
    }

    final hasLibraries = await settingsService.hasSelectedLibraries();
    if (!hasLibraries) {
      return _AppState.needsLibrarySelection;
    }

    return _AppState.ready;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppState>(
      future: _checkAppState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final state = snapshot.data ?? _AppState.firstRun;

        switch (state) {
          case _AppState.firstRun:
            return const FirstRunPage();
          case _AppState.needsLibrarySelection:
            // This shouldn't normally happen, but if it does, restart setup
            return const FirstRunPage();
          case _AppState.ready:
            return const HomePage();
        }
      },
    );
  }
}

enum _AppState {
  firstRun,
  needsLibrarySelection,
  ready,
}
