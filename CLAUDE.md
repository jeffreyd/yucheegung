# YuCheeGung - Jellyfin Audio Client

A Flutter application for playing and downloading audio from Jellyfin servers.

## Project Overview

**Organization**: `org.jeffreyd`
**Flutter Version**: 3.35.4

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

### 5. Shuffle Functionality
- Fisher-Yates shuffle algorithm for proper randomization
- Available at album and playlist levels
- Prepares queue for future playback integration

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

## Known Issues & Future Work

### Not Yet Implemented
- [ ] Actual audio playback (currently shows snackbar placeholders)
- [ ] Download functionality for offline playback
- [ ] Audio service integration
- [ ] Queue management
- [ ] Player controls

### Dependencies Ready for Future Features
- `just_audio` - Audio playback
- `audio_service` - Background audio
- `flutter_downloader` - File downloads
- `path_provider` - Local file storage
- `dio` - Advanced HTTP client
- `provider` - State management

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
