import 'package:flutter/foundation.dart';

@immutable
class SpotifyTrackInfo {
  final String artist;
  final String name;
  final String uri;
  final bool isPaused;

  const SpotifyTrackInfo({
    required this.artist,
    required this.name,
    required this.uri,
    required this.isPaused,
  });

  factory SpotifyTrackInfo.fromMap(Map<dynamic, dynamic> map) {
    return SpotifyTrackInfo(
      artist: map['artist'] as String,
      name: map['name'] as String,
      uri: map['uri'] as String,
      isPaused: map['isPaused'] as bool,
    );
  }

  @override
  String toString() {
    return 'TrackInfo(artist: $artist, name: $name, isPaused: $isPaused, uri: $uri)';
  }
}
