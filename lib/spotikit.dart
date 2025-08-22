library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:spotikit/log/spotikit_log.dart';

import 'api/spotify_api.dart';
import 'const/methods.dart';
import 'models/auth_state.dart';
import 'models/sealed/track_result.dart';
import 'models/spotify/spotify_track_info.dart';

class Spotikit {
  static final SpotifyApi _api = SpotifyApi();
  static SpotifyApi get api => _api;

  static const MethodChannel _channel = MethodChannel('spotikit');

  static final StreamController<AuthState> _authController =
      StreamController<AuthState>.broadcast();

  static Stream<AuthState> get onAuthStateChanged => _authController.stream;

  static bool _isListenerInitialized = false;

  static const String _defaultScope =
      "user-read-playback-state user-modify-playback-state user-read-currently-playing app-remote-control streaming playlist-read-private playlist-read-collaborative playlist-modify-public playlist-modify-private user-library-modify user-library-read user-top-read user-read-playback-position user-read-recently-played user-follow-read user-follow-modify user-read-email user-read-private";

  static Future<bool> initialize({
    required String clientId,
    required String redirectUri,
    required String clientSecret,
    String scope = _defaultScope,
  }) async {
    try {
      if (!_isListenerInitialized) {
        _channel.setMethodCallHandler(_handleNativeEvents);
        _isListenerInitialized = true;
      }
      await _channel.invokeMethod('initialize', {
        'clientId': clientId,
        'redirectUri': redirectUri,
        'clientSecret': clientSecret,
        'scope': scope,
      });
      SpotikitLog.log("Spotikit initialized successfully.");
      return true;
    } catch (e) {
      SpotikitLog.error("Error during initialization: $e");
    }
    return false;
  }

  static Future<void> fullInitialize({
    required String clientId,
    required String redirectUri,
    required String clientSecret,
    String scope = _defaultScope,
  }) async {
    await initialize(
      clientId: clientId,
      redirectUri: redirectUri,
      clientSecret: clientSecret,
      scope: scope,
    );
    if (!await authenticateSpotify()) return;
    if (!await connectToSpotify()) return;

    SpotikitLog.log(
      "Spotikit initialized and connected to remote successfully.",
    );
  }

  static void enableLogging() {
    SpotikitLog.enableLogging();
  }

  static Future<void> _handleNativeEvents(MethodCall call) async {
    switch (call.method) {
      case 'spotifyAuthSuccess':
        final args = call.arguments as Map;
        _authController.add(AuthSuccess(args['accessToken'] as String));
        break;
      case 'spotifyAuthFailed':
        final args = call.arguments as Map;
        final error = args['error'] as String;
        if (error == 'cancelled') {
          _authController.add(AuthCancelled());
        } else {
          _authController.add(AuthFailure(error, args['message'] as String?));
        }
        break;
      default:
        break;
    }
  }

  static Future<bool> connectToSpotify() async {
    try {
      String? result = await _channel.invokeMethod<String>('connectToSpotify');
      if (result == "Connected") {
        SpotikitLog.log("Spotify is connected!");
      } else if (result == "Already connected") {
        SpotikitLog.log("Spotify was already connected");
      }
      return result == "Connected" || result == "Already connected";
    } on PlatformException catch (e) {
      SpotikitLog.error('Spotify connection failed: ${e.code} - ${e.message}');
    } catch (e) {
      SpotikitLog.error('Unexpected error: $e');
    }
    return false;
  }

  static Future<bool> authenticateSpotify() async {
    try {
      await _channel.invokeMethod<String>(Methods.authenticateSpotify);
      return true;
    } catch (e) {
      SpotikitLog.error("Error during Spotify authentication: $e");
    }
    return false;
  }

  static Future<String?> getAccessToken() async {
    try {
      return await _channel.invokeMethod<String>(Methods.getAccessToken);
    } catch (e) {
      SpotikitLog.error("Error retrieving access token: $e");
      return null;
    }
  }

  static Future<void> playUri({required String spotifyUri}) async {
    try {
      await _channel.invokeMethod<String>(Methods.play, {
        'spotifyUri': spotifyUri,
      });
    } catch (e) {
      SpotikitLog.error("Error during play: $e");
    }
  }

  static Future<void> pause() async {
    try {
      await _channel.invokeMethod<String>(Methods.pause);
    } catch (e) {
      SpotikitLog.error("Error during pause: $e");
      return Future.value(null);
    }
  }

  static Future<void> resume() async {
    try {
      await _channel.invokeMethod<String>(Methods.resume);
    } catch (e) {
      SpotikitLog.error("Error during resume: $e");
    }
  }

  static Future<void> skipTrack() async {
    try {
      await _channel.invokeMethod<String>(Methods.skipTrack);
    } catch (e) {
      SpotikitLog.error("Error during skipTrack: $e");
    }
  }

  static Future<void> previousTrack() async {
    try {
      await _channel.invokeMethod<String>(Methods.previousTrack);
    } catch (e) {
      SpotikitLog.error("Error during previousTrack: $e");
    }
  }

  static Future<TrackResult?> getPlayingTrackInfo({bool full = false}) async {
    try {
      final Map? result = await _channel.invokeMapMethod(Methods.getTrackInfo);
      if (result == null) return null;
      final trackInfo = SpotifyTrackInfo.fromMap(result);
      if (!full) {
        return TrackInfoResult(trackInfo);
      }
      final id = trackInfo.uri.split(":").last;

      final String? accessToken = await getAccessToken();
      if (accessToken == null) {
        SpotikitLog.error(
          "Access token is null, cannot fetch full track info.",
        );
        return null;
      }
      final track = await _api.getTrackById(id: id, accessToken: accessToken);
      if (track == null) {
        SpotikitLog.error("Failed to fetch full track info from Spotify API.");
        return null;
      }
      return SpotifyTrackResult(track);
    } catch (e) {
      SpotikitLog.error("Error retrieving track info: $e");
      return null;
    }
  }

  static Future<void> disconnect() async {
    try {
      String? val = await _channel.invokeMethod<String>(Methods.disconnect);

      if (val == "Disconnected") {
        SpotikitLog.log("Spotify disconnected successfully.");
      } else if (val == "Already disconnected") {
        SpotikitLog.log("Spotify was already disconnected.");
      } else if (val == "Not connected, no action taken") {
        SpotikitLog.log("Spotify was not connected, no action taken.");
      }
      throw "Unknown response: $val";
    } catch (e) {
      SpotikitLog.error("Error during disconnect: $e");
    }
  }

  static Future<void> logout() async {
    try {
      await _channel.invokeMethod<String>(Methods.logout);
    } catch (e) {
      SpotikitLog.error("Error during logout: $e");
    }
  }

  static Future<bool> isPlaying() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(Methods.isPlaying);
      return result ?? false;
    } catch (e) {
      SpotikitLog.error("Error checking if playing: $e");
      return false;
    }
  }

  static Future<void> seekTo({required int positionMs}) async {
    try {
      await _channel.invokeMethod(Methods.seekTo, {"positionMs": positionMs});
    } catch (e) {
      SpotikitLog.error("Error during seekTo: $e");
    }
  }

  static Future<void> skipForward({double seconds = 5}) async {
    try {
      await _channel.invokeMethod(Methods.skipForward, {
        "seconds": (seconds * 1000).toInt(),
      });
    } catch (e) {
      SpotikitLog.error("Error during skipForward: $e");
    }
  }

  static Future<void> skipBackward({double seconds = 5}) async {
    try {
      await _channel.invokeMethod(Methods.skipBackward, {
        "seconds": (seconds * 1000).toInt(),
      });
    } catch (e) {
      SpotikitLog.error("Error during skipBackward: $e");
    }
  }
}
