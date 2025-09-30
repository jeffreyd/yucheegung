class JellyfinAlbum {
  final String id;
  final String name;
  final String? imageTag;
  final int? year;
  final String? artistId;
  final String? artistName;

  JellyfinAlbum({
    required this.id,
    required this.name,
    this.imageTag,
    this.year,
    this.artistId,
    this.artistName,
  });

  factory JellyfinAlbum.fromJson(Map<String, dynamic> json) {
    return JellyfinAlbum(
      id: json['Id'] as String,
      name: json['Name'] as String,
      imageTag: json['ImageTags']?['Primary'] as String?,
      year: json['ProductionYear'] as int?,
      artistId: (json['AlbumArtists'] as List<dynamic>?)?.isNotEmpty == true
          ? json['AlbumArtists'][0]['Id'] as String?
          : null,
      artistName: (json['AlbumArtists'] as List<dynamic>?)?.isNotEmpty == true
          ? json['AlbumArtists'][0]['Name'] as String?
          : json['AlbumArtist'] as String?,
    );
  }

  /// Get the URL for the album's primary image
  String? getImageUrl(String baseUrl) {
    if (imageTag == null) return null;
    return '$baseUrl/Items/$id/Images/Primary?tag=$imageTag&maxWidth=300&maxHeight=300';
  }
}
