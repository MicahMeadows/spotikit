import 'package:dio/dio.dart';
import 'package:spotikit/models/spotify/spotify_track.dart';

const String _baseUrl = "https://api.spotify.com/v1/";

enum SearchType { album, artist, playlist, track, show, episode, audiobook }

class SpotifyApi {
  final Dio _dio;
  SpotifyApi() : _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  Future<SpotifyTrack?> getTrackById({
    required String id,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.get(
        'tracks/$id',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return SpotifyTrack.fromJson(response.data);
      } else {
        print(
          'Spotify API returned status code ${response.statusCode}, message ${response.statusMessage}',
        );
        return null;
      }
    } on DioException catch (e) {
      if (e.response != null) {
        print(
          'Spotify API error: ${e.response?.statusCode} - ${e.response?.data}',
        );
      } else {
        print('Spotify API error: ${e.message}');
      }
      return null;
    } catch (e) {
      print('Unexpected error: $e');
      return null;
    }
  }

  Future<dynamic> search({
    required String query,
    required SearchType type,
    required String accessToken,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        'search',
        queryParameters: {
          'q': query,
          'type': type.toString(),
          'limit': limit,
          'offset': offset,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        print(
          'Spotify API returned status code ${response.statusCode}, message ${response.statusMessage}',
        );
        return null;
      }
    } on DioException catch (e) {
      if (e.response != null) {
        print(
          'Spotify API error: ${e.response?.statusCode} - ${e.response?.data}',
        );
      } else {
        print('Spotify API error: ${e.message}');
      }
      return null;
    } catch (e) {
      print('Unexpected error: $e');
      return null;
    }
  }

  Future<String?> searchAndGetFirstTrackId({
    required String query,
    required String accessToken,
  }) async {
    final result = await search(
      query: query,
      type: SearchType.track,
      accessToken: accessToken,
      limit: 1,
    );

    if (result != null &&
        result['tracks'] != null &&
        result['tracks']['items'] != null &&
        result['tracks']['items'].isNotEmpty) {
      return  result['tracks']['items'][0]['id'];
    } else {
      print('No tracks found for query: $query');
      return null;
    }
  }
}
