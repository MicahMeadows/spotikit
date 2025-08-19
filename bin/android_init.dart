import 'dart:io';
import 'package:spotikit/config.dart';

void main() async {
  print('=== Spotikit Android Init Script ===');

  final androidInit = AndroidInit();
  await androidInit.run();

  print('=== Done ===');
  exit(0);
}

class AndroidInit {
  late final SpotikitConfig _config;

  Future<void> run() async {
    try {
      print('Current working directory: ${Directory.current.path}');

      if (!initConfig()) {
        print('Failed to load config. Exiting.');
        return;
      }

      final pluginFile = findPluginFile();
      if (pluginFile == null) {
        print('Cannot find SpotikitPlugin.kt. Check your path.');
        return;
      }

      print('Found SpotikitPlugin.kt at: ${pluginFile.absolute.path}');

      if (!await injectSpotifyConfig(pluginFile)) {
        print('Failed to inject Spotify configuration.');
        return;
      }

      print('Spotikit Android Init completed successfully!');
    } catch (e) {
      print('Unexpected error: $e');
    }
  }

  bool initConfig() {
    try {
      _config = SpotikitConfig.fromPubspec();
      print('Loaded config: clientId=${_config.clientId}, redirectUri=${_config.redirectUri}');
      return true;
    } catch (e) {
      print('Error loading config: $e');
      return false;
    }
  }

  File? findPluginFile() {
    // Relative path from plugin root to SpotikitPlugin.kt
    final relativePath = 'android/src/main/kotlin/com/ardakoksal/spotikit/SpotikitPlugin.kt';
    final file = File(relativePath);

    if (file.existsSync()) return file;

    // Try alternative: relative to current directory
    final altFile = File('${Directory.current.path}/$relativePath');
    if (altFile.existsSync()) return altFile;

    return null;
  }

  Future<bool> injectSpotifyConfig(File file) async {
    try {
      String content = await file.readAsString();

      content = content
          .replaceFirst('X_USER_CLIENT_ID', _config.clientId)
          .replaceFirst('X_USER_REDIRECT_URI', _config.redirectUri)
          .replaceFirst('X_USER_CLIENT_SECRET', _config.clientSecret)
          .replaceFirst('X_USER_SCOPE', _config.scope);

      await file.writeAsString(content);
      print('SpotikitPlugin.kt updated successfully.');
      return true;
    } catch (e) {
      print('Error injecting config: $e');
      return false;
    }
  }
}
