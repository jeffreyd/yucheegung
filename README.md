# YuCheeGung

> Most of this README was written by Claude Code. It may contain errors or inaccuracies.

## About (written by a human)
Guess who's back in the motherfuckin' house with a JellyFin app for your motherfucking phone?
Yep, I'm back again with another _entirely_ AI-generated app. There's a number of JellyFin
music players out there, not least of which is [FinAmp](https://github.com/jmshrv/finamp),
which is great, but none of them really worked like I want them to so I had Claude write
one for me. _Very_ simple navigation, with Artist -> Album -> Song and the ability to shuffle
entire artists or albums which will loop forever. I mostly use this on the rare occasion I
want to listen to music in the car or, my primary usage, listening to the audio from TV shows
ripped to MP3 while I sleep. As such, it's not very feature-full.

## Key Features

- **Jellyfin Integration**: Connect to your Jellyfin server to stream your music library
- **Offline Mode**: Download albums, playlists, and entire artist catalogs for offline playback
- **Smart Transcoding**: Automatic audio transcoding support for optimal streaming quality
- **Multi-Disc Album Support**: Proper handling of multi-disc albums with correct track ordering
- **Library Selection**: Choose which music libraries to display from your Jellyfin server
- **Playlist Support**: Browse and play your Jellyfin playlists
- **Material Design 3**: Modern UI following Material Design 3 guidelines
- **Persistent Mini Player**: Always-visible mini player for quick playback controls
- **Auto-Advance**: Automatically plays the next song in the queue
- **Server Unreachable Detection**: Automatically switches to offline mode when server is unavailable

## Technical Details

- **Framework**: Flutter 3.35.4
- **Language**: Dart
- **Audio Playback**: just_audio package with support for streaming and local files
- **Local Storage**: SQLite database for tracking downloads, SharedPreferences for settings
- **State Management**: Provider pattern with ChangeNotifier
- **HTTP Client**: http package for Jellyfin API communication
- **File Management**: file_picker and permission_handler for Android storage access
- **Platform**: Android (with HTTP cleartext traffic support for local servers)

## Project Structure

```
lib/
├── main.dart                           # App entry point with Provider setup
├── models/                             # Data models
│   ├── jellyfin_album.dart
│   ├── jellyfin_artist.dart
│   ├── jellyfin_auth.dart
│   ├── jellyfin_library.dart
│   ├── jellyfin_playlist.dart
│   ├── jellyfin_server.dart
│   └── jellyfin_song.dart
├── pages/                              # UI screens
│   ├── album_detail_page.dart
│   ├── artist_detail_page.dart
│   ├── download_settings_page.dart
│   ├── first_run_page.dart
│   ├── home_page.dart
│   ├── library_selection_page.dart
│   ├── playlist_detail_page.dart
│   ├── playlist_list_page.dart
│   └── server_config_page.dart
├── providers/                          # State management
│   └── player_provider.dart
├── services/                           # Business logic
│   ├── audio_player_service.dart      # Audio playback management
│   ├── download_database.dart         # SQLite database for downloads
│   ├── download_service.dart          # File download management
│   ├── jellyfin_service.dart          # Jellyfin API client
│   ├── offline_service.dart           # Offline content access
│   └── settings_service.dart          # App settings persistence
├── utils/                              # Utilities
│   └── shuffle_helper.dart            # Fisher-Yates shuffle algorithm
└── widgets/                            # Reusable UI components
    └── mini_player.dart               # Persistent mini player widget
```

## Development

### Prerequisites

- Flutter SDK 3.35.4 or higher
- Android SDK with API level 33+ support
- A Jellyfin server (local or remote)

### Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd yucheegung
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Android Permissions

The app requires the following Android permissions:
- `INTERNET` - For streaming from Jellyfin server
- `READ_EXTERNAL_STORAGE` - For reading downloaded files
- `WRITE_EXTERNAL_STORAGE` - For saving downloads
- `READ_MEDIA_AUDIO` - For Android 13+ media access
- `MANAGE_EXTERNAL_STORAGE` - For managing download directories

### HTTP Cleartext Traffic

The app supports HTTP (cleartext) traffic to allow connections to local Jellyfin servers. This is configured in `android/app/src/main/AndroidManifest.xml` with:
```xml
<application android:usesCleartextTraffic="true">
```

## Usage

### First Run

1. Launch the app and enter your Jellyfin server URL (e.g., `http://192.168.1.100:8096`)
2. Log in with your Jellyfin credentials
3. Select which music libraries you want to display
4. Choose a download location for offline content

### Browsing Music

- The home page shows all artists from your selected libraries
- Tap an artist to view their albums
- Tap an album to view its tracks
- Access playlists from the "-- Playlists --" entry at the top of the artist list

### Playing Music

- Tap any song to start playback immediately
- Use the shuffle button on album/playlist pages to shuffle and play
- The mini player appears at the bottom when music is playing
- Mini player shows: song info, progress bar, play/pause, and skip controls

### Downloading for Offline Use

1. Navigate to an album, playlist, or artist
2. Tap the download icon in the app bar
3. Wait for the download to complete (progress shown in dialog)
4. Downloaded content shows a green checkmark icon
5. When server is unreachable, app automatically uses downloaded content

### Offline Mode

- When the Jellyfin server is unreachable, the app enters offline mode
- The app bar shows "YuCheeGung (Offline)"
- An offline indicator appears in the bottom bar
- Only downloaded artists, albums, and playlists are visible
- All playback uses local files instead of streaming

### Library Selection

- Open the drawer menu (hamburger icon)
- Your selected libraries are listed under "LIBRARIES"
- Tap a library to switch to it
- The app remembers your selection across restarts

## Features in Detail

### Audio Playback

The app uses the `just_audio` package with:
- **Streaming**: Uses Jellyfin's universal endpoint with automatic transcoding to AAC
- **Offline**: Plays from local files stored in the download directory
- **Queue Management**: Maintains a playback queue with next/previous navigation
- **Auto-Advance**: Automatically plays the next song when the current one finishes

### Download System

- Downloads are organized: `DownloadLocation/ArtistName/AlbumName/DiscNumber-TrackNumber - SongName.ext`
- SQLite database tracks downloaded items and their file paths
- Supports downloading individual albums, entire playlists, or all albums by an artist
- Filenames are sanitized to remove invalid characters
- Multi-disc albums preserve disc numbers in filenames

### Jellyfin API Integration

The app communicates with Jellyfin using:
- **Authentication**: X-Emby-Authorization header with access token
- **Libraries**: Fetches music libraries and filters by user selection
- **Artists**: Retrieves artists with album counts
- **Albums**: Fetches albums with year, track count, and multi-disc info
- **Songs**: Gets track listings with disc/track numbers and runtime
- **Playlists**: Retrieves user playlists and their contents
- **Streaming**: Uses the universal endpoint for adaptive streaming with transcoding

### Caching

- Artist lists are cached for 1 hour to reduce server requests
- Cache can be manually refreshed using the refresh button
- Offline mode bypasses cache and uses local database

## Attribution

Built with:
- [Flutter](https://flutter.dev/) - UI framework
- [just_audio](https://pub.dev/packages/just_audio) - Audio playback
- [sqflite](https://pub.dev/packages/sqflite) - Local database
- [provider](https://pub.dev/packages/provider) - State management
- [shared_preferences](https://pub.dev/packages/shared_preferences) - Settings storage
- [http](https://pub.dev/packages/http) - HTTP client
- [file_picker](https://pub.dev/packages/file_picker) - Directory selection
- [permission_handler](https://pub.dev/packages/permission_handler) - Android permissions

Designed for use with [Jellyfin](https://jellyfin.org/) media server.
