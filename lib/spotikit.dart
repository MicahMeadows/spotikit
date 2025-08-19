// ignore_for_file: avoid_print

library;

import 'dart:async';
import 'package:flutter/services.dart';

/// Main Spotikit plugin class for Spotify integration
class Spotikit {
  static const MethodChannel _channel = MethodChannel('spotikit/spotify');
  static Spotikit? _instance;

  // Stream controllers for events
  static final StreamController<SpotifyAuthResult> _authController =
      StreamController<SpotifyAuthResult>.broadcast();
  static final StreamController<SpotifyConnectionResult> _connectionController =
      StreamController<SpotifyConnectionResult>.broadcast();

  // Configuration state
  bool _isInitialized = false;

  // Private constructor
  Spotikit._();

  /// Get singleton instance
  static Spotikit get instance => _instance ??= Spotikit._();

  /// Stream of authentication results
  Stream<SpotifyAuthResult> get onAuthResult => _authController.stream;

  /// Stream of connection results
  Stream<SpotifyConnectionResult> get onConnectionResult =>
      _connectionController.stream;

  /// Check if Spotikit has been initialized with configuration
  bool get isInitialized => _isInitialized;

  /// Initialize the plugin and set up method call handlers
  static Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Initialize Spotify configuration
  /// Must be called before using other methods
  Future<SpotifyInitResult> initializeSpotify({
    required String clientId,
    required String clientSecret,
    required String redirectUri,
    required String scope,
  }) async {
    try {
      final result = await _channel.invokeMethod('initializeSpotify', {
        'clientId': clientId,
        'clientSecret': clientSecret,
        'redirectUri': redirectUri,
        'scope': scope,
      });

      if (result is Map) {
        _isInitialized = true;
        return SpotifyInitResult.success(
          clientId: result['clientId'],
          redirectUri: result['redirectUri'],
        );
      }

      _isInitialized = true;
      return SpotifyInitResult.success();
    } on PlatformException catch (e) {
      _isInitialized = false;
      return SpotifyInitResult.failed(
        error: e.code,
        message: e.message ?? 'Failed to initialize Spotify',
        details: e.details,
      );
    } catch (e) {
      _isInitialized = false;
      return SpotifyInitResult.failed(
        error: 'UNKNOWN_ERROR',
        message: e.toString(),
      );
    }
  }

  /// Handle method calls from native platform
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'spotifyAuthSuccess':
        final result = SpotifyAuthResult.success(
          accessToken: call.arguments['accessToken'],
          expiresAt: call.arguments['expiresAt'],
          hasRefreshToken: call.arguments['hasRefreshToken'] ?? false,
        );
        _authController.add(result);
        break;

      case 'spotifyAuthFailed':
        final result = SpotifyAuthResult.failed(
          error: call.arguments['error'] ?? 'unknown_error',
          message: call.arguments['message'] ?? 'Authentication failed',
        );
        _authController.add(result);
        break;

      case 'spotifyAuthCancelled':
        final result = SpotifyAuthResult.cancelled(
          message: call.arguments['message'] ?? 'Authentication cancelled',
        );
        _authController.add(result);
        break;

      default:
        print('Unhandled method call: ${call.method}');
    }
  }

  /// Check if initialized, throw exception if not
  void _requireInitialization() {
    if (!_isInitialized) {
      throw SpotikitException(
        'Spotikit not initialized. Call initializeSpotify() first with your configuration.',
        'NOT_INITIALIZED',
      );
    }
  }

  /// Connect to Spotify App Remote
  Future<SpotifyConnectionResult> connectToSpotify() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('connectToSpotify');
      if (result is Map) {
        return SpotifyConnectionResult.fromMap(
          Map<String, dynamic>.from(result),
        );
      }
      return SpotifyConnectionResult.connected();
    } on PlatformException catch (e) {
      return SpotifyConnectionResult.failed(
        error: e.code,
        message: e.message ?? 'Connection failed',
        details: e.details,
      );
    } catch (e) {
      return SpotifyConnectionResult.failed(
        error: 'UNKNOWN_ERROR',
        message: e.toString(),
      );
    }
  }

  /// Start Spotify authentication flow
  Future<SpotifyAuthResult> authenticate() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('authenticateSpotify');
      if (result is Map) {
        final status = result['status'] as String?;
        if (status == 'authentication_started') {
          return SpotifyAuthResult.started();
        }
      }
      return SpotifyAuthResult.started();
    } on PlatformException catch (e) {
      return SpotifyAuthResult.failed(
        error: e.code,
        message: e.message ?? 'Authentication failed',
      );
    }
  }

  /// Get current access token
  Future<SpotifyTokenResult> getAccessToken() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('getAccessToken');
      if (result is Map) {
        return SpotifyTokenResult.fromMap(Map<String, dynamic>.from(result));
      }
      return SpotifyTokenResult.invalid();
    } on PlatformException catch (e) {
      return SpotifyTokenResult.error(
        error: e.code,
        message: e.message ?? 'Failed to get token',
        requiresAuth: e.details?['requiresAuth'] ?? false,
      );
    }
  }

  /// Refresh the access token
  Future<SpotifyTokenResult> refreshToken() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('refreshToken');
      if (result is Map) {
        return SpotifyTokenResult.fromMap(Map<String, dynamic>.from(result));
      }
      return SpotifyTokenResult.invalid();
    } on PlatformException catch (e) {
      return SpotifyTokenResult.error(
        error: e.code,
        message: e.message ?? 'Failed to refresh token',
        requiresAuth: e.details?['requiresAuth'] ?? false,
      );
    }
  }

  /// Check if token is valid
  Future<SpotifyTokenValidation> isTokenValid() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('isTokenValid');
      if (result is Map) {
        return SpotifyTokenValidation.fromMap(
          Map<String, dynamic>.from(result),
        );
      }
      return SpotifyTokenValidation(isValid: false);
    } on PlatformException catch (e) {
      return SpotifyTokenValidation(isValid: false, error: e.message);
    }
  }

  /// Play a track by Spotify URI
  Future<SpotifyPlaybackResult> play(String spotifyUri) async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('play', {
        'spotifyUri': spotifyUri,
      });
      if (result is Map) {
        return SpotifyPlaybackResult.fromMap(Map<String, dynamic>.from(result));
      }
      return SpotifyPlaybackResult.success();
    } on PlatformException catch (e) {
      return SpotifyPlaybackResult.failed(
        error: e.code,
        message: e.message ?? 'Failed to play track',
      );
    }
  }

  /// Pause playback
  Future<SpotifyPlaybackResult> pause() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('pause');
      if (result is Map) {
        return SpotifyPlaybackResult.fromMap(Map<String, dynamic>.from(result));
      }
      return SpotifyPlaybackResult.success();
    } on PlatformException catch (e) {
      return SpotifyPlaybackResult.failed(
        error: e.code,
        message: e.message ?? 'Failed to pause playback',
      );
    }
  }

  /// Resume playback
  Future<SpotifyPlaybackResult> resume() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('resume');
      if (result is Map) {
        return SpotifyPlaybackResult.fromMap(Map<String, dynamic>.from(result));
      }
      return SpotifyPlaybackResult.success();
    } on PlatformException catch (e) {
      return SpotifyPlaybackResult.failed(
        error: e.code,
        message: e.message ?? 'Failed to resume playback',
      );
    }
  }

  /// Skip to next track
  Future<SpotifyPlaybackResult> skipNext() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('skipTrack');
      if (result is Map) {
        return SpotifyPlaybackResult.fromMap(Map<String, dynamic>.from(result));
      }
      return SpotifyPlaybackResult.success();
    } on PlatformException catch (e) {
      return SpotifyPlaybackResult.failed(
        error: e.code,
        message: e.message ?? 'Failed to skip track',
      );
    }
  }

  /// Skip to previous track
  Future<SpotifyPlaybackResult> skipPrevious() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('previousTrack');
      if (result is Map) {
        return SpotifyPlaybackResult.fromMap(Map<String, dynamic>.from(result));
      }
      return SpotifyPlaybackResult.success();
    } on PlatformException catch (e) {
      return SpotifyPlaybackResult.failed(
        error: e.code,
        message: e.message ?? 'Failed to skip to previous track',
      );
    }
  }

  /// Set playback volume (0.0 to 1.0)
  Future<SpotifyPlaybackResult> setVolume(double volume) async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('setVolume', {
        'volume': volume,
      });
      if (result is Map) {
        return SpotifyPlaybackResult.fromMap(Map<String, dynamic>.from(result));
      }
      return SpotifyPlaybackResult.success();
    } on PlatformException catch (e) {
      return SpotifyPlaybackResult.failed(
        error: e.code,
        message: e.message ?? 'Failed to set volume',
      );
    }
  }

  /// Seek to position in milliseconds
  Future<SpotifyPlaybackResult> seekTo(int positionMs) async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('seekTo', {
        'positionMs': positionMs,
      });
      if (result is Map) {
        return SpotifyPlaybackResult.fromMap(Map<String, dynamic>.from(result));
      }
      return SpotifyPlaybackResult.success();
    } on PlatformException catch (e) {
      return SpotifyPlaybackResult.failed(
        error: e.code,
        message: e.message ?? 'Failed to seek',
      );
    }
  }

  /// Get current track information
  Future<SpotifyTrackInfo?> getCurrentTrack() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('getTrackInfo');
      if (result is Map) {
        return SpotifyTrackInfo.fromMap(Map<String, dynamic>.from(result));
      }
      return null;
    } on PlatformException catch (e) {
      print('Failed to get track info: ${e.message}');
      return null;
    }
  }

  /// Get complete player state
  Future<SpotifyPlayerState?> getPlayerState() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('getPlayerState');
      if (result is Map) {
        return SpotifyPlayerState.fromMap(Map<String, dynamic>.from(result));
      }
      return null;
    } on PlatformException catch (e) {
      print('Failed to get player state: ${e.message}');
      return null;
    }
  }

  /// Check if connected to Spotify
  Future<bool> isConnected() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('isConnected');
      if (result is Map) {
        return result['isConnected'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Disconnect from Spotify
  Future<SpotifyConnectionResult> disconnect() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('disconnect');
      if (result is Map) {
        return SpotifyConnectionResult.fromMap(
          Map<String, dynamic>.from(result),
        );
      }
      return SpotifyConnectionResult.disconnected();
    } on PlatformException catch (e) {
      return SpotifyConnectionResult.failed(
        error: e.code,
        message: e.message ?? 'Failed to disconnect',
      );
    }
  }

  /// Logout and clear all stored data
  Future<SpotifyConnectionResult> logout() async {
    _requireInitialization();

    try {
      final result = await _channel.invokeMethod('logout');
      if (result is Map) {
        return SpotifyConnectionResult.fromMap(
          Map<String, dynamic>.from(result),
        );
      }
      return SpotifyConnectionResult.loggedOut();
    } on PlatformException catch (e) {
      return SpotifyConnectionResult.failed(
        error: e.code,
        message: e.message ?? 'Failed to logout',
      );
    }
  }
}

/// Custom exception for Spotikit errors
class SpotikitException implements Exception {
  final String message;
  final String code;

  const SpotikitException(this.message, this.code);

  @override
  String toString() => 'SpotikitException($code): $message';
}

/// Initialization result
class SpotifyInitResult {
  final bool success;
  final String? clientId;
  final String? redirectUri;
  final String? error;
  final String? message;
  final Map<String, dynamic>? details;

  const SpotifyInitResult({
    required this.success,
    this.clientId,
    this.redirectUri,
    this.error,
    this.message,
    this.details,
  });

  factory SpotifyInitResult.success({String? clientId, String? redirectUri}) {
    return SpotifyInitResult(
      success: true,
      clientId: clientId,
      redirectUri: redirectUri,
      message: 'Spotify initialized successfully',
    );
  }

  factory SpotifyInitResult.failed({
    required String error,
    required String message,
    Map<String, dynamic>? details,
  }) {
    return SpotifyInitResult(
      success: false,
      error: error,
      message: message,
      details: details,
    );
  }
}

/// Authentication result
class SpotifyAuthResult {
  final SpotifyAuthStatus status;
  final String? accessToken;
  final int? expiresAt;
  final bool hasRefreshToken;
  final String? error;
  final String? message;

  const SpotifyAuthResult({
    required this.status,
    this.accessToken,
    this.expiresAt,
    this.hasRefreshToken = false,
    this.error,
    this.message,
  });

  factory SpotifyAuthResult.success({
    required String accessToken,
    required int expiresAt,
    required bool hasRefreshToken,
  }) {
    return SpotifyAuthResult(
      status: SpotifyAuthStatus.success,
      accessToken: accessToken,
      expiresAt: expiresAt,
      hasRefreshToken: hasRefreshToken,
    );
  }

  factory SpotifyAuthResult.failed({
    required String error,
    required String message,
  }) {
    return SpotifyAuthResult(
      status: SpotifyAuthStatus.failed,
      error: error,
      message: message,
    );
  }

  factory SpotifyAuthResult.cancelled({required String message}) {
    return SpotifyAuthResult(
      status: SpotifyAuthStatus.cancelled,
      message: message,
    );
  }

  factory SpotifyAuthResult.started() {
    return const SpotifyAuthResult(
      status: SpotifyAuthStatus.started,
      message: 'Authentication flow started',
    );
  }
}

enum SpotifyAuthStatus { success, failed, cancelled, started }

/// Connection result
class SpotifyConnectionResult {
  final SpotifyConnectionStatus status;
  final String? error;
  final String? message;
  final Map<String, dynamic>? details;

  const SpotifyConnectionResult({
    required this.status,
    this.error,
    this.message,
    this.details,
  });

  factory SpotifyConnectionResult.connected() {
    return const SpotifyConnectionResult(
      status: SpotifyConnectionStatus.connected,
      message: 'Connected to Spotify',
    );
  }

  factory SpotifyConnectionResult.disconnected() {
    return const SpotifyConnectionResult(
      status: SpotifyConnectionStatus.disconnected,
      message: 'Disconnected from Spotify',
    );
  }

  factory SpotifyConnectionResult.loggedOut() {
    return const SpotifyConnectionResult(
      status: SpotifyConnectionStatus.loggedOut,
      message: 'Logged out successfully',
    );
  }

  factory SpotifyConnectionResult.failed({
    required String error,
    required String message,
    Map<String, dynamic>? details,
  }) {
    return SpotifyConnectionResult(
      status: SpotifyConnectionStatus.failed,
      error: error,
      message: message,
      details: details,
    );
  }

  factory SpotifyConnectionResult.fromMap(Map<String, dynamic> map) {
    final statusString = map['status'] as String?;
    SpotifyConnectionStatus status;

    switch (statusString) {
      case 'connected':
      case 'already_connected':
        status = SpotifyConnectionStatus.connected;
        break;
      case 'disconnected':
      case 'already_disconnected':
        status = SpotifyConnectionStatus.disconnected;
        break;
      case 'logged_out':
        status = SpotifyConnectionStatus.loggedOut;
        break;
      case 'failed':
      default:
        status = SpotifyConnectionStatus.failed;
        break;
    }

    return SpotifyConnectionResult(
      status: status,
      error: map['error'],
      message: map['message'],
      details: map['details'],
    );
  }
}

enum SpotifyConnectionStatus { connected, disconnected, loggedOut, failed }

/// Token result
class SpotifyTokenResult {
  final String? token;
  final int? expiresAt;
  final bool isValid;
  final String? error;
  final String? message;
  final bool requiresAuth;

  const SpotifyTokenResult({
    this.token,
    this.expiresAt,
    this.isValid = false,
    this.error,
    this.message,
    this.requiresAuth = false,
  });

  factory SpotifyTokenResult.fromMap(Map<String, dynamic> map) {
    return SpotifyTokenResult(
      token: map['token'],
      expiresAt: map['expiresAt'],
      isValid: map['isValid'] ?? false,
    );
  }

  factory SpotifyTokenResult.invalid() {
    return const SpotifyTokenResult(
      isValid: false,
      message: 'No valid token',
      requiresAuth: true,
    );
  }

  factory SpotifyTokenResult.error({
    required String error,
    required String message,
    required bool requiresAuth,
  }) {
    return SpotifyTokenResult(
      isValid: false,
      error: error,
      message: message,
      requiresAuth: requiresAuth,
    );
  }
}

/// Token validation result
class SpotifyTokenValidation {
  final bool isValid;
  final int? expiresAt;
  final bool hasRefreshToken;
  final String? error;

  const SpotifyTokenValidation({
    required this.isValid,
    this.expiresAt,
    this.hasRefreshToken = false,
    this.error,
  });

  factory SpotifyTokenValidation.fromMap(Map<String, dynamic> map) {
    return SpotifyTokenValidation(
      isValid: map['isValid'] ?? false,
      expiresAt: map['expiresAt'],
      hasRefreshToken: map['hasRefreshToken'] ?? false,
    );
  }
}

/// Playback result
class SpotifyPlaybackResult {
  final bool success;
  final String? status;
  final String? error;
  final String? message;
  final Map<String, dynamic>? details;

  const SpotifyPlaybackResult({
    required this.success,
    this.status,
    this.error,
    this.message,
    this.details,
  });

  factory SpotifyPlaybackResult.success({String? status}) {
    return SpotifyPlaybackResult(success: true, status: status);
  }

  factory SpotifyPlaybackResult.failed({
    required String error,
    required String message,
    Map<String, dynamic>? details,
  }) {
    return SpotifyPlaybackResult(
      success: false,
      error: error,
      message: message,
      details: details,
    );
  }

  factory SpotifyPlaybackResult.fromMap(Map<String, dynamic> map) {
    return SpotifyPlaybackResult(
      success: true,
      status: map['status'],
      details: map,
    );
  }
}

/// Track information
class SpotifyTrackInfo {
  final String artist;
  final String name;
  final String uri;
  final String album;
  final String imageUri;
  final int duration;
  final int playbackPosition;
  final bool isPaused;

  const SpotifyTrackInfo({
    required this.artist,
    required this.name,
    required this.uri,
    required this.album,
    required this.imageUri,
    required this.duration,
    required this.playbackPosition,
    required this.isPaused,
  });

  factory SpotifyTrackInfo.fromMap(Map<String, dynamic> map) {
    return SpotifyTrackInfo(
      artist: map['artist'] ?? '',
      name: map['name'] ?? '',
      uri: map['uri'] ?? '',
      album: map['album'] ?? '',
      imageUri: map['imageUri'] ?? '',
      duration: map['duration'] ?? 0,
      playbackPosition: map['playbackPosition'] ?? 0,
      isPaused: map['isPaused'] ?? true,
    );
  }
}

/// Complete player state
class SpotifyPlayerState {
  final SpotifyTrack track;
  final bool isPaused;
  final double playbackSpeed;
  final int playbackPosition;
  final SpotifyPlaybackOptions playbackOptions;
  final SpotifyPlaybackRestrictions playbackRestrictions;

  const SpotifyPlayerState({
    required this.track,
    required this.isPaused,
    required this.playbackSpeed,
    required this.playbackPosition,
    required this.playbackOptions,
    required this.playbackRestrictions,
  });

  factory SpotifyPlayerState.fromMap(Map<String, dynamic> map) {
    return SpotifyPlayerState(
      track: SpotifyTrack.fromMap(Map<String, dynamic>.from(map['track'])),
      isPaused: map['isPaused'] ?? true,
      playbackSpeed: (map['playbackSpeed'] ?? 1.0).toDouble(),
      playbackPosition: map['playbackPosition'] ?? 0,
      playbackOptions: SpotifyPlaybackOptions.fromMap(
        Map<String, dynamic>.from(map['playbackOptions'] ?? {}),
      ),
      playbackRestrictions: SpotifyPlaybackRestrictions.fromMap(
        Map<String, dynamic>.from(map['playbackRestrictions'] ?? {}),
      ),
    );
  }
}

/// Track details
class SpotifyTrack {
  final String artist;
  final String name;
  final String uri;
  final String album;
  final String imageUri;
  final int duration;

  const SpotifyTrack({
    required this.artist,
    required this.name,
    required this.uri,
    required this.album,
    required this.imageUri,
    required this.duration,
  });

  factory SpotifyTrack.fromMap(Map<String, dynamic> map) {
    return SpotifyTrack(
      artist: map['artist'] ?? '',
      name: map['name'] ?? '',
      uri: map['uri'] ?? '',
      album: map['album'] ?? '',
      imageUri: map['imageUri'] ?? '',
      duration: map['duration'] ?? 0,
    );
  }
}

/// Playback options
class SpotifyPlaybackOptions {
  final bool isShuffling;
  final SpotifyRepeatMode repeatMode;

  const SpotifyPlaybackOptions({
    required this.isShuffling,
    required this.repeatMode,
  });

  factory SpotifyPlaybackOptions.fromMap(Map<String, dynamic> map) {
    final repeatModeIndex = map['repeatMode'] ?? 0;
    return SpotifyPlaybackOptions(
      isShuffling: map['isShuffling'] ?? false,
      repeatMode:
          SpotifyRepeatMode.values[repeatModeIndex.clamp(
            0,
            SpotifyRepeatMode.values.length - 1,
          )],
    );
  }
}

/// Repeat mode enum
enum SpotifyRepeatMode { off, track, context }

/// Playback restrictions
class SpotifyPlaybackRestrictions {
  final bool canSkipNext;
  final bool canSkipPrev;
  final bool canRepeatTrack;
  final bool canRepeatContext;
  final bool canToggleShuffle;
  final bool canSeek;

  const SpotifyPlaybackRestrictions({
    required this.canSkipNext,
    required this.canSkipPrev,
    required this.canRepeatTrack,
    required this.canRepeatContext,
    required this.canToggleShuffle,
    required this.canSeek,
  });

  factory SpotifyPlaybackRestrictions.fromMap(Map<String, dynamic> map) {
    return SpotifyPlaybackRestrictions(
      canSkipNext: map['canSkipNext'] ?? true,
      canSkipPrev: map['canSkipPrev'] ?? true,
      canRepeatTrack: map['canRepeatTrack'] ?? true,
      canRepeatContext: map['canRepeatContext'] ?? true,
      canToggleShuffle: map['canToggleShuffle'] ?? true,
      canSeek: map['canSeek'] ?? true,
    );
  }
}
