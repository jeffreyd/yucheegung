# YuCheeGung - Jellyfin Audio Client

A Flutter application for playing and downloading audio from Jellyfin servers.

## Project Overview

**Organization**: `org.jeffreyd`
**Flutter Version**: 3.35.4
**Version**: 1.0.1+4

## Features Implemented

### 1. First Run Experience
- Server configuration with URL and credentials
- Smart URL parsing (defaults to http:// and port 8096)
- Jellyfin authentication
- Music library selection (multi-select)

### 2. Library Navigation
- Artist listing with "-- Playlists --" at the top
- Artist → Album → Song navigation hierarchy
- Playlist listing and detail pages
- Multi-disc album support with disc headers
- List view for albums (user preference)

### 3. Caching System
- In-memory cache with 30-minute expiration
- Singleton pattern for app-wide access
- Cache for artists, albums, and songs
- Force refresh option to bypass cache

### 4. User Interface
- Material Design 3
- Bottom toolbars with refresh and shuffle buttons
- Drawer navigation for library switching and logout
- SliverAppBar with expandable album art

### 5. Audio Playback
- Full playback controls (play, pause, skip, seek)
- Queue management with auto-advance
- Background playback with screen off
- Media notifications and controls
- Android Auto integration via audio_service
- Robust error handling with retry logic
- Error state tracking and user notification

### 6. Shuffle Functionality
- Fisher-Yates shuffle algorithm for proper randomization
- Available at album and playlist levels

## Architecture

### Models
- `JellyfinServer` - Server configuration with smart URL parsing
- `JellyfinAuth` - Authentication tokens (separate JSON serialization for API vs storage)
- `JellyfinLibrary` - Music library metadata
- `JellyfinArtist` - Artist information
- `JellyfinAlbum` - Album metadata with year and artist
- `JellyfinSong` - Song with track number, disc number, duration
- `JellyfinPlaylist` - Playlist metadata

### Services
- `SettingsService` - Persistent settings with SharedPreferences
- `JellyfinService` - Jellyfin API integration
- `CacheService` - In-memory caching with expiration
- `AudioPlayerService` - Audio playback with just_audio (singleton)

### Providers
- `PlayerProvider` - UI state management for playback controls and error state

### Widgets
- `MiniPlayer` - Bottom playback bar with controls, progress, and error banner

### Pages
- `FirstRunPage` - Initial server setup
- `LibrarySelectionPage` - Music library selection
- `HomePage` - Artist listing with drawer navigation
- `ArtistDetailPage` - Albums by artist (list view)
- `AlbumDetailPage` - Songs by album with multi-disc support
- `PlaylistListPage` - All playlists
- `PlaylistDetailPage` - Playlist songs

### Utils
- `ShuffleHelper` - Fisher-Yates shuffle implementation

## Key Technical Decisions

### URL Parsing
Accepts various formats:
- `my.server.com` → `http://my.server.com:8096`
- `https://my.server.com` → `https://my.server.com:8096`
- `http://my.server.com:8920` → `http://my.server.com:8920`

### Jellyfin API Endpoints
- `/Users/AuthenticateByName` - Authentication
- `/Users/{id}/Views` - Library listing
- `/Artists/AlbumArtists` - Artist listing (limit: 10000)
- `/Users/{id}/Items` - Albums, songs, playlists

### Authentication
- Uses X-Emby-Authorization header
- Separate JSON formats for API response vs storage
- `fromJson` for API responses
- `fromStorageJson` for SharedPreferences

### Caching Strategy
- 30-minute default expiration
- Per-library artist cache
- Per-artist album cache
- Per-album/playlist song cache
- Force refresh bypasses cache

### Multi-Disc Albums
- Groups songs by `discNumber` field
- Shows "Disc N" headers only for multi-disc albums
- Single-disc albums show clean song list
- Maintains track number display in all cases

### Audio Service Integration
- `AudioPlayerHandler` bridges just_audio with audio_service
- Syncs player state to audio service via playbackEventStream
- Maintains media session for background playback
- Configuration: `androidStopForegroundOnPause: false` keeps playback alive with screen off
- Media controls work from notifications and lock screen

### Error Handling & Retry Logic
- Exponential backoff retry for network failures (1s, 2s, 4s delays)
- Up to 3 retry attempts per track before giving up
- Auto-advance wrapped in try-catch to prevent silent failures
- Failed tracks automatically skipped to continue playback
- Single auto-advance listener setup (prevents duplicate listeners)
- Error state exposed to UI via `PlayerProvider`
- Error banner in mini player with dismiss functionality
- Errors include context (song name, error details)

## Known Issues & Future Work

### Recently Fixed
- [x] Playback stops unexpectedly during auto-advance (2025-10-02)
  - **Issue**: Playback would randomly stop between tracks, especially overnight, with no error shown to user
  - **Cause**: Multiple issues:
    - No error handling in auto-advance listener - network/server errors silently killed playback
    - No retry logic for transient network failures
    - Multiple auto-advance listeners stacking up from repeated `PlayerProvider` initialization
    - Errors rethrown without recovery path during auto-advance
  - **Fix**: Comprehensive error handling system (audio_player_service.dart, player_provider.dart, mini_player.dart)
    - Added exponential backoff retry (3 attempts per track)
    - Wrapped auto-advance in try-catch with fallback to skip failed tracks
    - Single-setup guard for auto-advance listener
    - Error state tracking and UI notification
    - Error banner in mini player with dismiss option

- [x] Audio playback stops after first track (2025-10-01)
  - **Issue**: Player would play first track then stop, not advancing to next
  - **Cause**: `setupAutoAdvance()` listener wasn't awaiting async calls to `skipNext()` and `_playSongAtIndex()`
  - **Fix**: Made listener callback async and added await keywords (audio_player_service.dart:205-215)

- [x] Background playback stops with screen off (2025-10-01)
  - **Issue**: UI updated but audio stopped playing when screen turned off
  - **Cause**: AudioPlayerHandler wasn't controlling the actual player, no active media session
  - **Fix**: Connected AudioPlayerHandler to AudioPlayerService singleton, synced player state to audio_service via playbackEventStream (main.dart:39-109)

### Not Yet Implemented
- [ ] Download functionality for offline playback

### Dependencies Ready for Future Features
- `just_audio` - Audio playback (✓ IN USE)
- `audio_service` - Background audio and Android Auto (✓ IN USE)
- `provider` - State management (✓ IN USE)
- `flutter_downloader` - File downloads
- `path_provider` - Local file storage
- `dio` - Advanced HTTP client

## Critical Fixes Applied

### Type Casting Error
**Issue**: `type 'Null' is not a subtype of type 'String'`
**Cause**: JellyfinAuth using wrong JSON format when loading from storage
**Fix**: Created separate `fromStorageJson` factory method

### Missing Artists
**Issue**: Only 9 artists showing when more exist
**Cause**: Using `/Users/{id}/Items?includeItemTypes=MusicArtist`
**Fix**: Changed to `/Artists/AlbumArtists` endpoint with limit: 10000

### Authentication Error in Detail Pages
**Issue**: "Not authenticated" when navigating to albums
**Cause**: New JellyfinService instances without auth
**Fix**: Load auth from SettingsService in initState and call setAuth()

## Debugging

Print statements are used throughout for debugging:
- `DEBUG:` prefix for all debug output
- Server responses include item counts
- Cache hits/misses are logged
- Error messages include full context

## Code Style

- Material Design 3 components
- Consistent bottom toolbar pattern
- Error handling with try-catch and user-facing snackbars
- Loading states with CircularProgressIndicator
- Empty states with icons and helpful messages
