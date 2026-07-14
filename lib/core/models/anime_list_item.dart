import 'package:hive/hive.dart';
import 'anime_model.dart';

part 'anime_list_item.g.dart';

@HiveType(typeId: 2)
enum AnimeCategory {
  @HiveField(0)
  planned,
  @HiveField(1)
  watching,
  @HiveField(2)
  completed,
  @HiveField(3)
  ignored,
}

@HiveType(typeId: 3)
class UserRating extends HiveObject {
  @HiveField(0)
  double overall;

  @HiveField(1)
  double story;

  @HiveField(2)
  double character;

  @HiveField(3)
  double animation;

  @HiveField(4)
  double music;

  @HiveField(5)
  String notes;

  @HiveField(6)
  double draw;

  UserRating({
    this.overall = 0,
    this.story = 0,
    this.character = 0,
    this.draw = 0,
    this.animation = 0,
    this.music = 0,
    this.notes = '',
  });

  /// Average of all sub-ratings that have been set (> 0)
  double computedOverall() {
    final subs = [story, character, draw, animation, music].where((v) => v > 0).toList();
    if (subs.isEmpty) return 0;
    return subs.reduce((a, b) => a + b) / subs.length;
  }

  bool get hasRating => overall > 0 || story > 0 || character > 0 || draw > 0 || animation > 0 || music > 0;
}

@HiveType(typeId: 1)
class AnimeListItem extends HiveObject {
  @HiveField(0)
  final int animeId;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String image;

  @HiveField(3)
  final double? score;

  @HiveField(4)
  final List<String> genres;

  @HiveField(5)
  AnimeCategory category;

  @HiveField(6)
  final DateTime addedAt;

  @HiveField(7)
  UserRating? userRating;

  @HiveField(8)
  final String episodes;

  @HiveField(9, defaultValue: 0)
  int episodeProgress;

  @HiveField(10)
  final String? type;

  @HiveField(11)
  final List<String>? studios;

  @HiveField(12)
  final String? year;

  @HiveField(13)
  final int? rank;

  @HiveField(14)
  final int? popularity;

  @HiveField(15)
  final String? season;
  @HiveField(16)
  bool? isMalSynced;

  AnimeListItem({
    required this.animeId,
    required this.title,
    required this.image,
    this.score,
    this.genres = const [],
    required this.category,
    DateTime? addedAt,
    this.userRating,
    this.episodes = '?',
    this.episodeProgress = 0,
    this.type,
    this.studios,
    this.year,
    this.rank,
    this.popularity,
    this.season,
    this.isMalSynced,
  }) : addedAt = addedAt ?? DateTime.now();

  factory AnimeListItem.fromAnime(AnimeModel anime, AnimeCategory category) {
    int initialProgress = 0;
    if (category == AnimeCategory.completed) {
      initialProgress = int.tryParse(anime.episodes) ?? 0;
    }
    
    return AnimeListItem(
      animeId: anime.id,
      title: anime.title,
      image: anime.image,
      score: anime.score,
      genres: anime.genres,
      category: category,
      episodes: anime.episodes,
      episodeProgress: initialProgress,
      type: anime.type,
      studios: anime.studios,
      year: anime.year,
      rank: anime.rank,
      popularity: anime.popularity,
      season: anime.season,
      isMalSynced: false, // will be updated when synced to MAL
    );
  }

  String get scoreDisplay => score != null ? score!.toStringAsFixed(1) : 'N/A';
}
