class JellyfinServer {
  final String baseUrl;
  final String username;
  final String password;
  final String? serverName;

  JellyfinServer({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.serverName,
  });

  /// Parse URL input and construct proper base URL
  /// Handles cases like:
  /// - example.com -> http://example.com:8096
  /// - https://example.com -> https://example.com:8096
  /// - example.com:9000 -> http://example.com:9000
  /// - http://example.com:9000 -> http://example.com:9000
  /// - http://my.jellyfinserver.com:8096 -> http://my.jellyfinserver.com:8096
  static String parseBaseUrl(String input) {
    String url = input.trim();

    // Check if schema is present
    bool hasSchema = url.startsWith('http://') || url.startsWith('https://');
    String schema = 'http';

    if (hasSchema) {
      if (url.startsWith('https://')) {
        schema = 'https';
      }
      url = url.replaceFirst(RegExp(r'^https?://'), '');
    }

    // Remove trailing slashes
    url = url.replaceAll(RegExp(r'/+$'), '');

    // Check if port is present in URL
    bool hasPort = url.contains(':');

    // Construct final URL
    if (hasPort) {
      return '$schema://$url';
    } else {
      return '$schema://$url:8096';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'username': username,
      'password': password,
      'serverName': serverName,
    };
  }

  factory JellyfinServer.fromJson(Map<String, dynamic> json) {
    return JellyfinServer(
      baseUrl: json['baseUrl'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      serverName: json['serverName'] as String?,
    );
  }
}
