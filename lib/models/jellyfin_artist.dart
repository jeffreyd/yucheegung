class JellyfinArtist {
  final String id;
  final String name;
  final String? imageTag;

  JellyfinArtist({
    required this.id,
    required this.name,
    this.imageTag,
  });

  factory JellyfinArtist.fromJson(Map<String, dynamic> json) {
    return JellyfinArtist(
      id: json['Id'] as String,
      name: json['Name'] as String,
      imageTag: json['ImageTags']?['Primary'] as String?,
    );
  }

  /// Get the URL for the artist's primary image
  String? getImageUrl(String baseUrl) {
    if (imageTag == null) return null;
    return '$baseUrl/Items/$id/Images/Primary?tag=$imageTag&maxWidth=300&maxHeight=300';
  }
}
