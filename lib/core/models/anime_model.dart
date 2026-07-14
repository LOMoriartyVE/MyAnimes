import 'package:hive/hive.dart';

part 'anime_model.g.dart';

@HiveType(typeId: 0)
class AnimeModel extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String japaneseTitle;

  @HiveField(3)
  final String image;

  @HiveField(4)
  final double? score;

  @HiveField(5)
  final String synopsis;

  @HiveField(6)
  final List<String> genres;

  @HiveField(7)
  final String status;

  @HiveField(8)
  final String rating;

  @HiveField(9)
  final String? trailerId;

  @HiveField(10)
  final List<String> studios;

  @HiveField(11)
  final String episodes;

  @HiveField(12)
  final String year;

  @HiveField(13)
  final String type;

  @HiveField(14)
  final String source;

  @HiveField(15)
  final String duration;

  @HiveField(16)
  final int? members;

  @HiveField(17)
  final int? rank;

  @HiveField(18)
  final int? popularity;

  @HiveField(19)
  final String? airedFrom;

  @HiveField(20)
  final String? airedTo;

  @HiveField(21)
  final String? broadcastDay;

  @HiveField(22)
  final String? broadcastTime;

  @HiveField(23)
  final String? season;

  @HiveField(24)
  final String? romajiTitle;

  AnimeModel({
    required this.id,
    required this.title,
    this.japaneseTitle = '',
    this.image = '',
    this.score,
    this.synopsis = 'No synopsis available.',
    this.genres = const [],
    this.status = 'Unknown',
    this.rating = 'None',
    this.trailerId,
    this.studios = const ['Unknown Studio'],
    this.episodes = '?',
    this.year = 'Unknown',
    this.type = 'Unknown',
    this.source = 'Unknown',
    this.duration = 'Unknown',
    this.members,
    this.rank,
    this.popularity,
    this.airedFrom,
    this.airedTo,
    this.broadcastDay,
    this.broadcastTime,
    this.season,
    this.romajiTitle,
  });

  factory AnimeModel.fromJson(Map<String, dynamic> json) {
    return AnimeModel(
      id: json['mal_id'] ?? 0,
      title: (json['title_english'] != null && json['title_english'].toString().trim().isNotEmpty)
          ? json['title_english'].toString()
          : (json['title'] != null && json['title'].toString().trim().isNotEmpty)
              ? json['title'].toString()
              : 'Unknown',
      japaneseTitle: json['title_japanese'] ?? '',
      image: getHighResImageUrl(
        json['images']?['webp']?['large_image_url'] ??
        json['images']?['jpg']?['large_image_url'] ??
        json['images']?['jpg']?['image_url'] ??
        ''
      ),
      score: (json['score'] as num?)?.toDouble(),
      synopsis: json['synopsis'] ?? 'No synopsis available.',
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => g['name'] as String)
              .toList() ??
          [],
      status: json['status'] ?? 'Unknown',
      rating: json['rating'] ?? 'None',
      trailerId: json['trailer']?['youtube_id'],
      studios: (json['studios'] as List<dynamic>?)
              ?.map((s) => s['name'] as String)
              .toList() ??
          ['Unknown Studio'],
      episodes: (json['episodes'] ?? '?').toString(),
      year: (json['year'] ?? json['aired']?['prop']?['from']?['year'] ?? 'Unknown')
          .toString(),
      type: json['type'] ?? 'Unknown',
      source: json['source'] ?? 'Unknown',
      duration: json['duration'] ?? 'Unknown',
      members: json['members'] as int?,
      rank: json['rank'] as int?,
      popularity: json['popularity'] as int?,
      airedFrom: json['aired']?['from'],
      airedTo: json['aired']?['to'],
      broadcastDay: json['broadcast']?['day'],
      broadcastTime: json['broadcast']?['time'],
      season: json['season'] as String?,
      romajiTitle: json['title'] as String?,
    );
  }

  static String getHighResImageUrl(String url) {
    if (url.isEmpty) return url;
    // Remove the resizing path, e.g. /r/100x140
    var cleanUrl = url.replaceAll(RegExp(r'/r/\d+x\d+'), '');
    // Remove any CDN query signatures that restrict sizes
    if (cleanUrl.contains('?')) {
      cleanUrl = cleanUrl.split('?').first;
    }
    return cleanUrl;
  }

  String get scoreDisplay => score != null ? score!.toStringAsFixed(1) : 'N/A';
}
