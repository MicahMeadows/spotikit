# Spotikit

Flutter plugin for integrating Spotify on Android using both the Spotify App Remote SDK (realtime playback control/state) and the Spotify Web API (rich metadata, search, etc.).

> Status: Experimental (v0.0.24). Android only for now. iOS support planned.

---
## Highlights
- 🔐 OAuth (Authorization Code) flow with refresh token persistence
- 📡 Connect & control Spotify playback (play, pause, resume, previous, next, seek, skip forward/backward)
- 🎶 Search helper (play the first track result by query)
- 🛰 Realtime playback state stream (track, artist, progress, paused state, image URI)
- 📦 Fetch full track metadata via Web API (popularity, album images, release date, explicit flag, etc.)
- 🛡 Centralized logging helper
- ♻ Token refresh handling

---
## Platform Support
| Platform | Status | Notes |
|----------|--------|-------|
| Android  | ✅     | Uses Spotify App Remote SDK + Auth + Web API |
| iOS      | ⏳     | Planned (API surface designed to be extendable) |
| Web/Desktop | ❌ | Not currently targeted |

---
## Prerequisites
1. A Spotify Developer account: https://developer.spotify.com/dashboard
2. Create an app & note `Client ID` and (if needed) `Client Secret`.
3. Add a redirect URI in the Spotify dashboard (e.g. `your.app://callback`).
4. Add that same redirect URI inside your Android project manifest intent filter if you customize it.

Scopes currently requested by default (can be overridden):
```
user-read-playback-state user-modify-playback-state user-read-currently-playing app-remote-control streaming playlist-read-private playlist-read-collaborative playlist-modify-public playlist-modify-private user-library-modify user-library-read user-top-read user-read-playback-position user-read-recently-played user-follow-read user-follow-modify user-read-email user-read-private
```
Trim these to the minimum your use-case requires (principle of least privilege).

---
## Installation
Add to `pubspec.yaml`:
```
dependencies:
  spotikit: ^0.0.24
```

Run:
```
flutter pub get
```

---
## Android Setup
(Gradle plugin normally auto‑configures via the Flutter plugin system.)

Ensure minSdk >= 21 (Spotify SDK requirement). If you need custom redirect URI handling, add an intent filter:
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="your.app" android:host="callback" />
</intent-filter>
```
Match `your.app://callback` with the redirect URI you registered in the Spotify dashboard.

---
## Quick Start
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Spotikit.enableLogging();

  await Spotikit.initialize(
    clientId: 'YOUR_CLIENT_ID',
    clientSecret: 'YOUR_CLIENT_SECRET',
    redirectUri: 'your.app://callback',
  );

  // Launch Spotify auth UI
  await Spotikit.authenticateSpotify();

  // After auth success (listen to stream), connect to App Remote
  await Spotikit.connectToSpotify();

  // Play a track
  await Spotikit.playUri(spotifyUri: 'spotify:track:11dFghVXANMlKmJXsNCbNl');

  // Subscribe to playback updates
  Spotikit.onPlaybackStateChanged.listen((state) {
    print('Now playing: ${state.name} by ${state.artist} @ ${(state.progress * 100).toStringAsFixed(1)}%');
  });
}
```

---
## Auth State Stream
```dart
Spotikit.onAuthStateChanged.listen((auth) {
  switch (auth) {
    case AuthSuccess(:final accessToken):
      print('Authenticated. Token: $accessToken');
      break;
    case AuthFailure(:final error, :final message):
      print('Auth failed: $error $message');
      break;
    case AuthCancelled():
      print('User cancelled Spotify login');
      break;
  }
});
```

---
## Playback State Stream
Every active track change or playback status update is pushed:
```dart
final sub = Spotikit.onPlaybackStateChanged.listen((s) {
  print('Track: ${s.name} | Paused: ${s.isPaused} | Position: ${s.positionMs}/${s.durationMs}');
});
```
Model fields:
- `uri`, `name`, `artist`
- `isPaused`
- `positionMs`, `durationMs`
- `imageUri` (raw Spotify App Remote image URI)
- Helpers: `progress`, `id`

---
## Core Control APIs
| Action | Method |
|--------|--------|
| Play by URI | `Spotikit.playUri(spotifyUri: ...)` |
| Pause | `Spotikit.pause()` |
| Resume | `Spotikit.resume()` |
| Next | `Spotikit.skipTrack()` |
| Previous | `Spotikit.previousTrack()` |
| Seek absolute | `Spotikit.seekTo(positionMs: ...)` |
| Skip fwd/back | `Spotikit.skipForward(seconds: 5)` / `skipBackward(seconds: 5)` |
| Currently playing (basic) | `Spotikit.getPlayingTrackInfo()` |
| Full metadata | `Spotikit.getPlayingTrackFull()` |
| Search & play first | `Spotikit.playSong(query: '...')` |
| Is playing? | `Spotikit.isPlaying()` |
| Disconnect | `Spotikit.disconnect()` |
| Logout (clear tokens) | `Spotikit.logout()` |

---
## Example App
A full demo lives under `example/` illustrating:
- Init + auth + connect lifecycle
- Manual URI playback
- Search & auto-play first result
- Realtime progress slider seeking
- Skip forward/backwards convenience

Run it:
```
cd example
flutter run
```
(Remember to fill real credentials in `example/lib/main.dart`).

---
## Token Handling
- Authorization Code flow exchanges code for access & refresh tokens
- Tokens cached in SharedPreferences (Android)
- Refresh triggered automatically when `getAccessToken` is requested and expired
- (Future) proactive refresh + error surfaced via auth stream

Security Tips:
- Do NOT commit secrets
- Use `--dart-define` or env injection for build pipelines
- Consider a lightweight backend proxy for token exchange if distributing public apps

---
## Error Handling
Native errors propagate as Flutter `PlatformException` via invoked methods; plugin logs details through `SpotikitLog`. Extendable future plan: unify under a strong `SpotikitException` wrapper.

---
## Roadmap
- iOS implementation parity
- Shuffle / repeat mode controls
- Queue operations (add, view)
- Volume & context metadata
- EventChannel migration for high‑frequency playback updates
- Additional Web API wrappers (playlists, user profile, library)
- Proactive token refresh & recovery events
- Track change filtered stream & last known playback cache

---
## Contributing
PRs welcome. Suggested steps:
1. Fork & clone
2. Create feature branch
3. Implement + add/update example usage & docs
4. Run `flutter format .` & ensure analyzer passes
5. Submit PR describing change & testing notes

---
## Development Scripts
The repo contains helper executables (see `pubspec.yaml`):
```
dart run spotikit:android_init
dart run spotikit:android_clean
```

---
## License
MIT © 2025 spotikit contributors

---
## Attribution
Uses Spotify App Remote SDK & Web API. This project is not affiliated with or endorsed by Spotify.

---
## Support
File issues / feature requests: https://github.com/ArdaKoksall/spotikit/issues

Enjoy building with Spotikit! 🎧
