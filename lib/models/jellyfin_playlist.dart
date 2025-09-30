class JellyfinPlaylist {
  final String id;
  final String name;
  final String? imageTag;
  final int? songCount;

  JellyfinPlaylist({
    required this.id,
    required this.name,
    this.imageTag,
    this.songCount,
  });

  factory JellyfinPlaylist.fromJson(Map<String, dynamic> json) {
    return JellyfinPlaylist(
      id: json['Id'] as String,
      name: json['Name'] as String,
      imageTag: json['ImageTags']?['Primary'] as String?,
      songCount: json['ChildCount'] as int?,
    );
  }

  /// Get the URL for the playlist's primary image
  String? getImageUrl(String baseUrl) {
    if (imageTag == null) return null;
    return '$baseUrl/Items/$id/Images/Primary?tag=$imageTag&maxWidth=300&maxHeight=300';
  }
}
