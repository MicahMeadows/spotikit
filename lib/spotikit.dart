import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class TrackInfo {
  final String artist;
  final String name;
  final String uri;
  final bool isPaused;

  const TrackInfo({
    required this.artist,
    required this.name,
    required this.uri,
    required this.isPaused,
  });

  factory TrackInfo.fromMap(Map<dynamic, dynamic> map) {
    return TrackInfo(
      artist: map['artist'] as String,
      name: map['name'] as String,
      uri: map['uri'] as String,
      isPaused: map['isPaused'] as bool,
    );
  }

  @override
  String toString() {
    return 'TrackInfo(artist: $artist, name: $name, isPaused: $isPaused)';
  }
}

@immutable
abstract class AuthState {}

class AuthSuccess extends AuthState {
  final String accessToken;
  AuthSuccess(this.accessToken);
}

class AuthFailure extends AuthState {
  final String error;
  final String? message;
  AuthFailure(this.error, this.message);
}

class AuthCancelled extends AuthState {}

class Spotikit {
  static const MethodChannel _channel = MethodChannel('spotikit');
  static final StreamController<AuthState> _authController = StreamController<AuthState>.broadcast();
  static Stream<AuthState> get onAuthStateChanged => _authController.stream;
  static bool _isListenerInitialized = false;
  static const String _defaultScope = "user-read-playback-state user-modify-playback-state user-read-currently-playing app-remote-control streaming playlist-read-private playlist-read-collaborative playlist-modify-public playlist-modify-private user-library-modify user-library-read user-top-read user-read-playback-position user-read-recently-played user-follow-read user-follow-modify user-read-email user-read-private";

  static Future<void> initialize({
    required String clientId,
    required String redirectUri,
    required String clientSecret,
    String scope = _defaultScope,
  }) async {
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
    try {
      await authenticateSpotify();
    } catch (e) {
      print("Error during Spotify authentication: $e");
      return;
    }
    try {
      await connectToSpotify();
    } catch (e) {
      print("Error connecting to Spotify: $e");
      return;
    }
    print("Spotikit initialized and connected to remote successfully.");
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

  static Future<String?> connectToSpotify() => _channel.invokeMethod<String>('connectToSpotify');
  static Future<String?> authenticateSpotify() => _channel.invokeMethod<String>('authenticateSpotify');
  static Future<String?> getAccessToken() => _channel.invokeMethod<String>('getAccessToken');
  static Future<String?> play(String spotifyUri) =>
      _channel.invokeMethod<String>('play', {'spotifyUri': spotifyUri});
  static Future<String?> pause() => _channel.invokeMethod<String>('pause');
  static Future<String?> resume() => _channel.invokeMethod<String>('resume');
  static Future<String?> skipTrack() => _channel.invokeMethod<String>('skipTrack');
  static Future<String?> previousTrack() => _channel.invokeMethod<String>('previousTrack');
  static Future<TrackInfo?> getTrackInfo() async {
    final Map? result = await _channel.invokeMapMethod('getTrackInfo');
    if (result == null) return null;
    return TrackInfo.fromMap(result);
  }
  static Future<String?> disconnect() => _channel.invokeMethod<String>('disconnect');
  static Future<String?> logout() => _channel.invokeMethod<String>('logout');
}