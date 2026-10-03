class AnimeRelationItem {
  final int malId;
  final String title;
  final String relationType; // Prequel, Sequel, Side Story, Spin-off, etc.
  final String? format; // TV, Movie, OVA, Special
  final String? image;
  final String? status;
  final int? episodes;
  final String? year;

  AnimeRelationItem({
    required this.malId,
    required this.title,
    required this.relationType,
    this.format,
    this.image,
    this.status,
    this.episodes,
    this.year,
  });

  factory AnimeRelationItem.fromMalJson(Map<String, dynamic> json) {
    final node = json['node'] ?? {};
    final rawType = json['relation_type_formatted'] ?? json['relation_type'] ?? 'Related';
    final pic = node['main_picture'] ?? {};
    return AnimeRelationItem(
      malId: node['id'] ?? 0,
      title: node['title'] ?? '',
      relationType: rawType.toString(),
      image: pic['large'] ?? pic['medium'],
      format: node['media_type']?.toString().toUpperCase(),
      status: node['status']?.toString(),
      episodes: node['num_episodes'] as int?,
      year: node['start_date'] != null ? node['start_date'].toString().split('-').first : null,
    );
  }

  factory AnimeRelationItem.fromAniListEdge(Map<String, dynamic> edge) {
    final node = edge['node'] ?? {};
    final rawType = edge['relationType']?.toString() ?? 'RELATED';
    // Format PREQUEL -> Prequel, SIDE_STORY -> Side Story
    final relationType = rawType
        .split('_')
        .map((w) => w.isNotEmpty ? (w[0].toUpperCase() + w.substring(1).toLowerCase()) : '')
        .join(' ');

    final titles = node['title'] ?? {};
    final title = titles['english'] ?? titles['userPreferred'] ?? titles['romaji'] ?? '';
    final cover = node['coverImage'] ?? {};
    final startYear = node['startDate']?['year']?.toString();

    return AnimeRelationItem(
      malId: node['idMal'] as int? ?? 0,
      title: title,
      relationType: relationType,
      format: node['format']?.toString(),
      image: cover['large'] ?? cover['medium'],
      status: node['status']?.toString(),
      episodes: node['episodes'] as int?,
      year: startYear,
    );
  }

  Map<String, dynamic> toJson() => {
    'mal_id': malId,
    'title': title,
    'relation_type': relationType,
    'format': format,
    'image': image,
    'status': status,
    'episodes': episodes,
    'year': year,
  };

  factory AnimeRelationItem.fromJson(Map<String, dynamic> json) => AnimeRelationItem(
    malId: json['mal_id'] ?? 0,
    title: json['title'] ?? '',
    relationType: json['relation_type'] ?? 'Related',
    format: json['format'],
    image: json['image'],
    status: json['status'],
    episodes: json['episodes'],
    year: json['year'],
  );
}
