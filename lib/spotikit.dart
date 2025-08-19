import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// A data class to hold information about the current track.
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

// A sealed class to represent the different outcomes of the authentication flow.
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


/// The main class for interacting with the Spotikit plugin.
class Spotikit {
  // The method channel used to interact with the native platform.
  static const MethodChannel _channel = MethodChannel('spotikit');

  // A stream controller to handle events coming from the native side.
  // This is used for events that are not direct responses to a method call,
  // like the result of the Spotify login activity.
  static final StreamController<AuthState> _authController = StreamController<AuthState>.broadcast();

  // A public stream for developers to listen to authentication state changes.
  static Stream<AuthState> get onAuthStateChanged => _authController.stream;

  // A flag to ensure the listener is only set up once.
  static bool _isListenerInitialized = false;

  /// Initializes the Spotikit plugin with your Spotify Developer credentials.
  ///
  /// This method MUST be called once before any other methods are used.
  /// A good place to call this is in your app's `main` function.
  static Future<void> initialize({
    required String clientId,
    required String redirectUri,
    required String clientSecret,
    required String scope,
  }) async {
    // Set up the listener for native-to-Dart events if it hasn't been already.
    if (!_isListenerInitialized) {
      _channel.setMethodCallHandler(_handleNativeEvents);
      _isListenerInitialized = true;
    }

    // Call the native 'initialize' method with the provided credentials.
    await _channel.invokeMethod('initialize', {
      'clientId': clientId,
      'redirectUri': redirectUri,
      'clientSecret': clientSecret,
      'scope': scope,
    });
  }

  /// Handles events invoked from the native side (Kotlin).
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
      // Handle other potential events or ignore them.
        break;
    }
  }

  /// Connects to the Spotify app on the device.
  ///
  /// The user must have Spotify installed.
  static Future<String?> connectToSpotify() => _channel.invokeMethod<String>('connectToSpotify');

  /// Starts the Spotify authentication flow.
  ///
  /// This will open the Spotify app or a web view for the user to log in.
  /// The result of this flow will be emitted on the [onAuthStateChanged] stream.
  static Future<String?> authenticateSpotify() => _channel.invokeMethod<String>('authenticateSpotify');

  /// Gets the current valid access token.
  ///
  /// If the token is expired, it will automatically attempt to refresh it.
  static Future<String?> getAccessToken() => _channel.invokeMethod<String>('getAccessToken');

  /// Plays a track, album, or playlist using its Spotify URI.
  static Future<String?> play(String spotifyUri) =>
      _channel.invokeMethod<String>('play', {'spotifyUri': spotifyUri});

  /// Pauses the current playback.
  static Future<String?> pause() => _channel.invokeMethod<String>('pause');

  /// Resumes the current playback.
  static Future<String?> resume() => _channel.invokeMethod<String>('resume');

  /// Skips to the next track in the queue.
  static Future<String?> skipTrack() => _channel.invokeMethod<String>('skipTrack');

  /// Skips to the previous track.
  static Future<String?> previousTrack() => _channel.invokeMethod<String>('previousTrack');

  /// Retrieves information about the currently playing track.
  static Future<TrackInfo?> getTrackInfo() async {
    final Map? result = await _channel.invokeMapMethod('getTrackInfo');
    if (result == null) return null;
    return TrackInfo.fromMap(result);
  }

  /// Disconnects from the Spotify app.
  static Future<String?> disconnect() => _channel.invokeMethod<String>('disconnect');

  /// Disconnects, clears all tokens from persistent storage, and effectively logs the user out.
  static Future<String?> logout() => _channel.invokeMethod<String>('logout');
}