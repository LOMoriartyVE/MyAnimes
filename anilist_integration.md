# AniList GraphQL API Integration Guide

This guide outlines how to integrate the AniList GraphQL API v2 into **MyAnimes** as an alternative or replacement sync provider to MyAnimeList.

---

## 1. Overview of AniList API
AniList uses a modern **GraphQL API** (rather than REST). All operations (queries and mutations) are sent as `POST` requests to a single endpoint:
- **Endpoint:** `https://graphql.anilist.co`
- **Authentication:** Bearer tokens (OAuth2) sent in the `Authorization` header.

### Why AniList?
1. **No Strict Rate Limits:** Far more forgiving than Jikan/MAL.
2. **GraphQL Power:** Request only the exact fields needed, saving user data.
3. **Rich Data:** Interactive studio lists, airing countdowns, and character relations.

---

## 2. Setting Up AniList Client in Flutter

We can use the `graphql_flutter` package or execute plain `http` requests by sending the query as a JSON body. Using the standard `http` package is lightweight and matches our existing architecture.

### Lightweight HTTP Client Implementation:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AniListService {
  static const String _url = 'https://graphql.anilist.co';
  
  static Future<Map<String, dynamic>> executeQuery(String query, {Map<String, dynamic>? variables, String? accessToken}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final response = await http.post(
      Uri.parse(_url),
      headers: headers,
      body: json.encode({
        'query': query,
        if (variables != null) 'variables': variables,
      }),
    );

    final decoded = json.decode(response.body);
    if (response.statusCode != 200) {
      throw Exception('AniList API Error: ${decoded['errors']?[0]?['message'] ?? 'Unknown error'}');
    }
    return decoded['data'];
  }
}
```

---

## 3. Key API Operations (Queries & Mutations)

### A. Searching Anime/Manga
GraphQL query to search and retrieve media content:

```graphql
query ($search: String, $type: MediaType) {
  Page(page: 1, perPage: 20) {
    media(search: $search, type: $type) {
      id
      title {
        romaji
        english
        native
      }
      coverImage {
        large
        medium
      }
      averageScore
      description
      status
      episodes
      chapters
      genres
      studios(isMain: true) {
        nodes {
          name
        }
      }
    }
  }
}
```

### B. Fetching User Anime List
Retrieve all entries in a user's library:

```graphql
query ($userId: Int) {
  MediaListCollection(userId: $userId, type: ANIME) {
    lists {
      name
      isCustomList
      status
      entries {
        id
        progress
        score(format: POINT_10)
        status
        media {
          id
          title {
            english
            romaji
          }
          coverImage {
            large
          }
        }
      }
    }
  }
}
```

### C. Mutating List Progress (Syncing progress back to AniList)
Update status, episode count, or score:

```graphql
mutation ($mediaId: Int, $status: MediaListStatus, $progress: Int, $score: Float) {
  SaveMediaListEntry(mediaId: $mediaId, status: $status, progress: $progress, score: $score) {
    id
    progress
    status
    score
  }
}
```

---

## 4. Authentication Flow (OAuth2)

AniList supports Authorization Code Grant and Implicit Grant. Implicit Grant is ideal for native apps:

1. Redirect the user to the AniList authorization page:
   `https://anilist.co/api/v2/oauth/authorize?client_id={CLIENT_ID}&response_type=token`
2. Catch the redirect callback URL using a deep link listener or a WebView inside the app.
3. Parse the access token from the URL hash:
   `myanimes://anilist-auth#access_token={ACCESS_TOKEN}&token_type=Bearer&expires_in=31536000`
4. Persist the access token in Hive (similar to MAL credentials) and use it for subsequent queries.
