library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'const/methods.dart';
import 'models/auth_state.dart';

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

final Logger _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
  ),
);

class Spotikit {
  static bool _loggingEnabled = false;

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
    try{
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
      log("Spotikit initialized successfully.");
      return true;
    }catch(e){
      _logger.e("Error during initialization: $e");
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

    log("Spotikit initialized and connected to remote successfully.");
  }

  static void enableLogging() {
    _loggingEnabled = true;
    _logger.i("Logging enabled");
  }

  static void log(String message) {
    if (_loggingEnabled) {
      _logger.i(message);
    }
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
        log("Spotify is connected!");
      } else if (result == "Already connected") {
        log("Spotify was already connected");
      }
      return result == "Connected" || result == "Already connected";
    } on PlatformException catch (e) {
      _logger.e('Spotify connection failed: ${e.code} - ${e.message}');
    } catch (e) {
      _logger.e('Unexpected error: $e');
    }
    return false;
  }

  static Future<bool> authenticateSpotify() async{
    try{
      await _channel.invokeMethod<String>(Methods.authenticateSpotify);
      return true;
    } catch(e){
      _logger.e("Error during Spotify authentication: $e");
    }
    return false;
  }

  static Future<String?> getAccessToken() async{
    try{
      return await _channel.invokeMethod<String>(Methods.getAccessToken);
    } catch(e){
      _logger.e("Error retrieving access token: $e");
      return null;
    }
  }

  static Future<void> play(String spotifyUri) async{
    try{
      await _channel.invokeMethod<String>(Methods.play, {
        'spotifyUri': spotifyUri,
      });
    } catch(e){
      _logger.e("Error during play: $e");
    }
  }

  static Future<void> pause() async{
    try{
      await _channel.invokeMethod<String>(Methods.pause);
    } catch(e){
      _logger.e("Error during pause: $e");
      return Future.value(null);
    }
  }

  static Future<void> resume() async {
    try{
      await _channel.invokeMethod<String>(Methods.resume);
    } catch(e){
      _logger.e("Error during resume: $e");
    }
  }

  static Future<void> skipTrack() async {
    try {
      await _channel.invokeMethod<String>(Methods.skipTrack);
    } catch (e) {
      _logger.e("Error during skipTrack: $e");
    }
  }

  static Future<void> previousTrack() async {
    try {
      await _channel.invokeMethod<String>(Methods.previousTrack);
    } catch (e) {
      _logger.e("Error during previousTrack: $e");
    }
  }

  static Future<TrackInfo?> getTrackInfo() async {
    try{
      final Map? result = await _channel.invokeMapMethod(Methods.getTrackInfo);
      if (result == null) return null;
      return TrackInfo.fromMap(result);
    }catch(e){
      _logger.e("Error retrieving track info: $e");
      return null;
    }
  }

  static Future<void> disconnect() async{
    try{
      String? val = await _channel.invokeMethod<String>(Methods.disconnect);

      if (val == "Disconnected") {
        log("Spotify disconnected successfully.");
      } else if (val == "Already disconnected") {
        log("Spotify was already disconnected.");
      }
      else if (val == "Not connected, no action taken") {
        log("Spotify was not connected, no action taken.");
      }
      throw "Unknown response: $val";
    } catch (e) {
      _logger.e("Error during disconnect: $e");
    }
  }

  static Future<void> logout() async {
    try{
      await _channel.invokeMethod<String>(Methods.logout);
    } catch (e) {
      _logger.e("Error during logout: $e");
    }
  }

}
