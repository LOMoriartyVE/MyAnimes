class CharacterModel {
  final int id;
  final String name;
  final String role;
  final String image;

  CharacterModel({
    required this.id,
    required this.name,
    required this.role,
    required this.image,
  });

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    return CharacterModel(
      id: json['character']?['mal_id'] ?? 0,
      name: json['character']?['name'] ?? 'Unknown',
      role: json['role'] ?? 'Unknown',
      image: json['character']?['images']?['jpg']?['image_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'character': {
        'mal_id': id,
        'name': name,
        'images': {
          'jpg': {'image_url': image}
        }
      },
      'role': role,
    };
  }
}
