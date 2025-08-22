import '../spotify/spotify_track.dart';
import '../spotify/spotify_track_info.dart';

sealed class TrackResult {}

class SpotifyTrackResult extends TrackResult {
  final SpotifyTrack? track;
  SpotifyTrackResult(this.track);
}

class TrackInfoResult extends TrackResult {
  final SpotifyTrackInfo? track;
  TrackInfoResult(this.track);
}
