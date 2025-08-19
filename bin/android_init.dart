import 'dart:io';
import 'package:path/path.dart' as p;
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
      print('Script location: ${Platform.script.toFilePath()}');

      if (!initConfig()) {
        print('Failed to load config. Exiting.');
        return;
      }

      final pluginFile = findPluginFile();
      if (pluginFile == null) {
        print('Cannot find SpotikitPlugin.kt. Please check your project structure.');
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
    // 1. Get the URI of the script that is currently running.
    final scriptUri = Platform.script;

    // 2. Find the root directory of your plugin by navigating UP from the script's location.
    //    This assumes your script is in a subdirectory of the plugin root, like `tool/`.
    final scriptPath = scriptUri.toFilePath();
    final pluginRoot = p.dirname(p.dirname(scriptPath));

    // 3. Now, build a reliable path to your Kotlin file from the plugin root.
    final pluginFilePath = p.join(
      pluginRoot,
      'android',
      'src',
      'main',
      'kotlin',
      'com',
      'ardakoksal',
      'spotikit',
      'SpotikitPlugin.kt',
    );

    final file = File(pluginFilePath);

    if (file.existsSync()) {
      return file;
    } else {
      print('Error: Could not find plugin file.');
      print('       Calculated path was: $pluginFilePath');
      return null;
    }
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