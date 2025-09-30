class JellyfinAuth {
  final String accessToken;
  final String userId;
  final String serverId;

  JellyfinAuth({
    required this.accessToken,
    required this.userId,
    required this.serverId,
  });

  /// Create from Jellyfin API response
  factory JellyfinAuth.fromJson(Map<String, dynamic> json) {
    return JellyfinAuth(
      accessToken: json['AccessToken'] as String,
      userId: json['User']['Id'] as String,
      serverId: json['ServerId'] as String,
    );
  }

  /// Create from stored JSON (SharedPreferences)
  factory JellyfinAuth.fromStorageJson(Map<String, dynamic> json) {
    return JellyfinAuth(
      accessToken: json['accessToken'] as String,
      userId: json['userId'] as String,
      serverId: json['serverId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'userId': userId,
      'serverId': serverId,
    };
  }
}
