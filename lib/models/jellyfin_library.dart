class JellyfinLibrary {
  final String id;
  final String name;
  final String collectionType;

  JellyfinLibrary({
    required this.id,
    required this.name,
    required this.collectionType,
  });

  factory JellyfinLibrary.fromJson(Map<String, dynamic> json) {
    return JellyfinLibrary(
      id: json['Id'] as String,
      name: json['Name'] as String,
      collectionType: json['CollectionType'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'collectionType': collectionType,
    };
  }

  bool get isMusic => collectionType.toLowerCase() == 'music';
}
