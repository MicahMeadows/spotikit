import 'package:dio/dio.dart';
import 'package:spotikit/models/spotify/spotify_track.dart';

const String _baseUrl = "https://api.spotify.com/v1/";

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
}
