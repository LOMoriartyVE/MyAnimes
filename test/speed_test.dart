// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_animes/core/models/anime_model.dart';
import 'package:my_animes/core/models/anime_list_item.dart';
import 'package:my_animes/core/models/anime_relation_item.dart';
import 'package:my_animes/core/services/airing_schedule_service.dart';
import 'package:my_animes/core/services/jikan_service.dart';

void main() {
  group('Comprehensive Application Performance & Speed Benchmarks (All Types)', () {
    
    // 1. Airing Schedule & Timezone Calculations
    test('1. Timezone conversion and broadcast parsing speed', () {
      final days = ['Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays', 'Sundays'];
      final times = ['00:30', '12:00', '18:30', '23:00', '24:30'];

      final stopwatch = Stopwatch()..start();
      const iterations = 5000;
      for (int i = 0; i < iterations; i++) {
        final d = days[i % days.length];
        final t = times[i % times.length];
        final dt = AiringScheduleService.parseJstNextBroadcast(d, t);
        expect(dt, isNotNull);
      }
      stopwatch.stop();

      final totalMs = stopwatch.elapsedMilliseconds;
      final perOpUs = (stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(2);
      print('--> [SPEED TEST 1] 5,000 Broadcast Parsing & Timezone Operations: ${totalMs}ms (${perOpUs}µs per op)');
      expect(totalMs, lessThan(1000), reason: 'Parsing 5,000 schedule broadcasts must take under 1 second');
    });

    // 2. AnimeModel JSON Deserialization
    test('2. AnimeModel JSON Deserialization Throughput', () {
      final sampleJson = {
        'mal_id': 1234,
        'title': 'Test Anime Title Ultra Extended',
        'title_english': 'Test Anime Title Ultra Extended English',
        'title_japanese': 'テストアニメ',
        'images': {
          'jpg': {
            'image_url': 'https://cdn.myanimelist.net/images/anime/1/1234.jpg',
            'large_image_url': 'https://cdn.myanimelist.net/images/anime/1/1234l.jpg',
          }
        },
        'score': 8.75,
        'synopsis': 'A thrilling story about speed testing and high performance Flutter application engineering.',
        'genres': [{'name': 'Action'}, {'name': 'Sci-Fi'}, {'name': 'Adventure'}],
        'status': 'Currently Airing',
        'rating': 'PG-13',
        'studios': [{'name': 'Studio Bones'}],
        'episodes': 24,
        'broadcast': {'day': 'Saturdays', 'time': '23:30'},
        'aired': {'from': '2026-04-01T00:00:00+00:00'},
      };

      final stopwatch = Stopwatch()..start();
      const count = 3000;
      final list = <AnimeModel>[];
      for (int i = 0; i < count; i++) {
        list.add(AnimeModel.fromJson(sampleJson));
      }
      stopwatch.stop();

      final totalMs = stopwatch.elapsedMilliseconds;
      final perOpUs = (stopwatch.elapsedMicroseconds / count).toStringAsFixed(2);
      final opsPerSec = (count / (stopwatch.elapsedMicroseconds / 1000000)).toStringAsFixed(0);
      print('--> [SPEED TEST 2] 3,000 AnimeModel JSON Deserializations: ${totalMs}ms (${perOpUs}µs per op, ~$opsPerSec objects/sec)');
      expect(totalMs, lessThan(1000), reason: '3,000 JSON deserializations must complete in under 1 second');
      expect(list.length, count);
    });

    // 3. AnimeListItem Object Creation & Conversion
    test('3. AnimeListItem Instantiation & Conversion Throughput', () {
      final anime = AnimeModel(
        id: 9999,
        title: 'Benchmark Anime Fantasy',
        image: 'https://example.com/test.jpg',
        score: 8.92,
        genres: ['Action', 'Fantasy', 'Adventure', 'Mystery'],
        episodes: '26',
        studios: ['ufotable', 'Aniplex'],
        year: '2026',
        season: 'spring',
        type: 'TV',
        rank: 12,
        popularity: 45,
      );

      final stopwatch = Stopwatch()..start();
      const count = 5000;
      final list = <AnimeListItem>[];
      for (int i = 0; i < count; i++) {
        list.add(AnimeListItem.fromAnime(anime, AnimeCategory.watching));
      }
      stopwatch.stop();

      final totalMs = stopwatch.elapsedMilliseconds;
      final perOpUs = (stopwatch.elapsedMicroseconds / count).toStringAsFixed(2);
      print('--> [SPEED TEST 3] 5,000 AnimeListItem Conversions: ${totalMs}ms (${perOpUs}µs per op)');
      expect(totalMs, lessThan(500), reason: '5,000 AnimeListItem instantiations must take under 500ms');
      expect(list.length, count);
    });

    // 4. Schedule Multi-Criteria Grouping & Sorting
    test('4. Schedule Grouping & Multi-Criteria Sorting Performance', () {
      final mockData = List.generate(1000, (i) {
        return AnimeModel(
          id: i + 1,
          title: 'Anime #$i with special keyword',
          japaneseTitle: 'アニメ #$i',
          image: 'https://example.com/img$i.jpg',
          score: 5.0 + (i % 50) / 10.0,
          status: i % 3 == 0 ? 'Currently Airing' : 'Finished Airing',
          broadcastDay: ['Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays', 'Sundays'][i % 7],
          broadcastTime: '${(10 + (i % 14)).toString().padLeft(2, '0')}:${((i % 4) * 15).toString().padLeft(2, '0')}',
        );
      });

      final stopwatch = Stopwatch()..start();

      final Map<int, List<AnimeModel>> grouped = {1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: [], 0: []};
      for (final a in mockData) {
        final local = AiringScheduleService.parseJstNextBroadcast(a.broadcastDay!, a.broadcastTime!);
        final wd = local?.weekday ?? 0;
        grouped[wd]?.add(a);
      }

      for (final list in grouped.values) {
        list.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
      }

      for (final list in grouped.values) {
        list.sort((a, b) => (a.broadcastTime ?? '').compareTo(b.broadcastTime ?? ''));
      }

      stopwatch.stop();
      print('--> [SPEED TEST 4] 1,000 Anime Grouping & Dual-Sort: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(300), reason: 'Grouping and sorting 1,000 anime should take <300ms');
    });

    // 5. In-Memory Full-Text Search
    test('5. Local In-Memory Full-Text Search Throughput', () {
      final catalog = List.generate(5000, (i) {
        return <String, String>{
          'id': '$i',
          'title': 'Digimon Adventure Tri Chapter $i Evolution',
          'title_english': 'Digimon Monsters $i',
          'title_japanese': 'デジモンアドベンチャー',
          'genres': 'Action, Fantasy, Adventure',
        };
      });

      final stopwatch = Stopwatch()..start();
      const queries = ['digimon', 'evolution', 'chapter 49', 'monster', 'デジモン'];
      int totalFound = 0;

      for (final q in queries) {
        final matches = catalog.where((item) {
          final t = item['title']!.toLowerCase();
          final te = item['title_english']!.toLowerCase();
          final tj = item['title_japanese']!.toLowerCase();
          return t.contains(q) || te.contains(q) || tj.contains(q);
        }).toList();
        totalFound += matches.length;
      }
      stopwatch.stop();

      print('--> [SPEED TEST 5] 5 Multi-Term Full-Text Searches across 5,000 records: ${stopwatch.elapsedMilliseconds}ms (Found $totalFound matches)');
      expect(stopwatch.elapsedMilliseconds, lessThan(250), reason: 'Full text searching 5,000 items must take <250ms');
    });

    // 6. Content & Category Exclusions Engine
    test('6. Content & Category Exclusions Engine Filtering Throughput', () {
      final sampleGenres = [
        ['Action', 'Fantasy'],
        ['Romance', 'Comedy', 'Ecchi'],
        ['Horror', 'Gore', 'Suspense'],
        ['Hentai', 'Erotica'],
        ['Slice of Life', 'School'],
        ['Sci-Fi', 'Mecha'],
        ['Boys Love', 'Drama'],
      ];

      final catalog = List.generate(5000, (i) {
        return AnimeModel(
          id: i + 1,
          title: 'Catalog Anime #$i',
          image: 'https://example.com/img$i.jpg',
          genres: sampleGenres[i % sampleGenres.length],
          rating: (i % 7 == 3) ? 'Rx - Hentai' : 'PG-13',
          type: (i % 10 == 0) ? 'Music' : 'TV',
        );
      });

      // Exclusion criteria (e.g., Adult / Explicit preset + Romance)
      final excludedSet = {'hentai', 'erotica', 'ecchi', 'gore', 'boys love', 'music'};

      final stopwatch = Stopwatch()..start();
      final filtered = catalog.where((anime) {
        // 1. Rating check
        final rating = anime.rating.toLowerCase();
        if (rating.contains('hentai') && excludedSet.contains('hentai')) return false;
        if (rating.contains('rx') && excludedSet.contains('hentai')) return false;

        // 2. Type check
        final type = anime.type.toLowerCase();
        if (excludedSet.contains(type)) return false;

        // 3. Genres / themes check
        for (final g in anime.genres) {
          if (excludedSet.contains(g.toLowerCase())) return false;
        }

        return true;
      }).toList();
      stopwatch.stop();

      final totalMs = stopwatch.elapsedMilliseconds;
      final perOpUs = (stopwatch.elapsedMicroseconds / 5000).toStringAsFixed(2);
      print('--> [SPEED TEST 6] 5,000 Anime Exclusions Filter: ${totalMs}ms (${perOpUs}µs per op, Kept ${filtered.length}/5,000)');
      expect(totalMs, lessThan(200), reason: 'Exclusion filtering 5,000 items must take under 200ms');
      expect(filtered.length, lessThan(5000));
    });

    // 7. Random Selector Candidate Matching & Scoring Pipeline
    test('7. Random Selector Candidate Filtering & Studio Matching', () {
      final rng = Random(42);
      final studios = [
        ['MAPPA'],
        ['ufotable'],
        ['Bones'],
        ['Madhouse'],
        ['Kyoto Animation'],
        ['CloverWorks'],
        ['Wit Studio'],
        ['Toei Animation'],
      ];
      final genresList = [
        ['Action', 'Supernatural'],
        ['Drama', 'Romance'],
        ['Comedy', 'School'],
        ['Fantasy', 'Adventure'],
        ['Sci-Fi', 'Psychological'],
      ];

      final mockPool = List.generate(5000, (i) {
        return {
          'id': i + 1,
          'title': 'Random Candidate #$i',
          'score': 6.0 + rng.nextDouble() * 3.9, // 6.0 to 9.9
          'studios': studios[rng.nextInt(studios.length)],
          'genres': genresList[rng.nextInt(genresList.length)],
          'episodes': 12,
        };
      });

      final stopwatch = Stopwatch()..start();
      const targetGenre = 'Action';
      const targetStudio = 'MAPPA';
      const minScore = 8.0;

      final matched = mockPool.where((item) {
        final score = (item['score'] as double?) ?? 0.0;
        if (score < minScore) return false;

        final genres = (item['genres'] as List<String>);
        if (!genres.contains(targetGenre)) return false;

        final studios = (item['studios'] as List<String>);
        if (!studios.contains(targetStudio)) return false;

        return true;
      }).toList();
      stopwatch.stop();

      final totalMs = stopwatch.elapsedMilliseconds;
      print('--> [SPEED TEST 7] 5,000 Random Candidates Filter (Genre: $targetGenre, Studio: $targetStudio, Score >= $minScore): ${totalMs}ms (Matched: ${matched.length})');
      expect(totalMs, lessThan(100), reason: 'Candidate filtering must take under 100ms');
      expect(matched, isNotEmpty);
    });

    // 8. Multi-Dimensional UserRating Dynamic Calculation
    test('8. Multi-Dimensional UserRating Dynamic Recalculation', () {
      final stopwatch = Stopwatch()..start();
      const iterations = 10000;
      double sum = 0.0;

      for (int i = 0; i < iterations; i++) {
        final rating = UserRating(
          story: 8.5 + (i % 15) * 0.1,
          character: 9.0 - (i % 10) * 0.1,
          draw: 8.0,
          animation: 9.5,
          music: (i % 3 == 0) ? 0.0 : 8.0, // Zero excluded
          dialogues: 7.5,
          mainIdea: 8.0,
        );
        sum += rating.computedOverall();
      }
      stopwatch.stop();

      final totalMs = stopwatch.elapsedMilliseconds;
      final perOpUs = (stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(2);
      print('--> [SPEED TEST 8] 10,000 UserRating Multi-Criteria Recalculations: ${totalMs}ms (${perOpUs}µs per op)');
      expect(totalMs, lessThan(300), reason: '10,000 rating recalculations must take under 300ms');
      expect(sum, greaterThan(0));
    });

    // 9. Episode Watch Delta & Airing Status Computation
    test('9. Episode Airing Watch Delta & Progress Computation Throughput', () {
      final stopwatch = Stopwatch()..start();
      const count = 2000;
      int behindCount = 0;
      int caughtUpCount = 0;
      int aheadCount = 0;

      for (int i = 0; i < count; i++) {
        final latestAired = 12 + (i % 10);
        final userProgress = 10 + (i % 14); // Some behind, some caught up, some ahead
        final delta = userProgress - latestAired;

        if (delta < 0) {
          behindCount++;
        } else if (delta == 0) {
          caughtUpCount++;
        } else {
          aheadCount++;
        }
      }
      stopwatch.stop();

      final totalMs = stopwatch.elapsedMilliseconds;
      print('--> [SPEED TEST 9] 2,000 Episode Watch Delta Computations: ${totalMs}ms (Behind: $behindCount, Caught Up: $caughtUpCount, Ahead: $aheadCount)');
      expect(totalMs, lessThan(100), reason: '2,000 delta computations must take under 100ms');
      expect(behindCount + caughtUpCount + aheadCount, count);
    });

    // 10. Franchise Relations Chronological Sorting
    test('10. Franchise Relations Chronological Timeline Sorting', () {
      final relations = [
        AnimeRelationItem(malId: 101, title: 'Season 4 Part 2', relationType: 'Sequel', year: '2022'),
        AnimeRelationItem(malId: 102, title: 'Season 1', relationType: 'Prequel', year: '2013'),
        AnimeRelationItem(malId: 103, title: 'Season 3 Part 1', relationType: 'Sequel', year: '2018'),
        AnimeRelationItem(malId: 104, title: 'Season 2', relationType: 'Sequel', year: '2017'),
        AnimeRelationItem(malId: 105, title: 'Season 3 Part 2', relationType: 'Sequel', year: '2019'),
        AnimeRelationItem(malId: 106, title: 'Season 4 Part 1', relationType: 'Sequel', year: '2020'),
        AnimeRelationItem(malId: 107, title: 'Final Chapters Special 1', relationType: 'Sequel', year: '2023'),
        AnimeRelationItem(malId: 108, title: 'Final Chapters Special 2', relationType: 'Sequel', year: '2023'),
      ];

      final stopwatch = Stopwatch()..start();
      const runs = 2000;
      for (int i = 0; i < runs; i++) {
        final copy = List<AnimeRelationItem>.from(relations);
        copy.sort((a, b) {
          final yearA = int.tryParse(a.year ?? '') ?? 9999;
          final yearB = int.tryParse(b.year ?? '') ?? 9999;
          if (yearA != yearB) return yearA.compareTo(yearB);
          return a.title.compareTo(b.title);
        });
        expect(copy.first.title, 'Season 1');
        expect(copy.last.title, 'Final Chapters Special 2');
      }
      stopwatch.stop();

      final totalMs = stopwatch.elapsedMilliseconds;
      print('--> [SPEED TEST 10] 2,000 Franchise Chronological Timeline Sorts: ${totalMs}ms');
      expect(totalMs, lessThan(300), reason: 'Timeline sorts must take under 300ms');
    });

    // 11. AniList GraphQL Live Search & Mapping Fallback
    test('11. AniList GraphQL Live Search & Mapping Fallback', () async {
      final stopwatch = Stopwatch()..start();
      final results = await JikanService.searchAnime(query: '86', limit: 5);
      stopwatch.stop();

      print('--> [SPEED TEST 11] AniList GraphQL Query: ${stopwatch.elapsedMilliseconds}ms, Found ${results.length} anime (Top: ${results.firstOrNull?.title})');
      expect(results, isNotEmpty);
      expect(results.first.id, greaterThan(0));
    });
  });
}

