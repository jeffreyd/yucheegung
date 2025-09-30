class JellyfinSong {
  final String id;
  final String name;
  final String? albumId;
  final String? albumName;
  final String? artistId;
  final String? artistName;
  final int? trackNumber;
  final int? discNumber;
  final int? runTimeTicks;
  final String? imageTag;

  JellyfinSong({
    required this.id,
    required this.name,
    this.albumId,
    this.albumName,
    this.artistId,
    this.artistName,
    this.trackNumber,
    this.discNumber,
    this.runTimeTicks,
    this.imageTag,
  });

  factory JellyfinSong.fromJson(Map<String, dynamic> json) {
    return JellyfinSong(
      id: json['Id'] as String,
      name: json['Name'] as String,
      albumId: json['AlbumId'] as String?,
      albumName: json['Album'] as String?,
      artistId: (json['ArtistItems'] as List<dynamic>?)?.isNotEmpty == true
          ? json['ArtistItems'][0]['Id'] as String?
          : null,
      artistName: (json['ArtistItems'] as List<dynamic>?)?.isNotEmpty == true
          ? json['ArtistItems'][0]['Name'] as String?
          : json['Artists']?[0] as String?,
      trackNumber: json['IndexNumber'] as int?,
      discNumber: json['ParentIndexNumber'] as int?,
      runTimeTicks: json['RunTimeTicks'] as int?,
      imageTag: json['ImageTags']?['Primary'] as String?,
    );
  }

  /// Get duration in a readable format (e.g., "3:45")
  String? get duration {
    if (runTimeTicks == null) return null;
    final seconds = runTimeTicks! ~/ 10000000; // Ticks to seconds
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Get the URL for the song's image (usually the album art)
  String? getImageUrl(String baseUrl) {
    if (imageTag == null) return null;
    // For songs, we typically use the album ID for the image
    final imageId = albumId ?? id;
    return '$baseUrl/Items/$imageId/Images/Primary?tag=$imageTag&maxWidth=300&maxHeight=300';
  }

  /// Get the URL to stream/download this song
  String getStreamUrl(String baseUrl) {
    return '$baseUrl/Audio/$id/universal?container=opus,mp3&transcodingContainer=mp4&transcodingProtocol=hls&audioCodec=aac';
  }
}
