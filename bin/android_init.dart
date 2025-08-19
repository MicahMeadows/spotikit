// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path/path.dart' as p;

const String kSpotifyAppRemoteAar = 'aar\\spotify-app-remote-release-0.8.0.aar';
const String kSpotifyAuthStoreAar = 'aar\\spotify-auth-store-release-2.1.0.aar';

void main(List<String> arguments) async {
  print('🎵 Initializing Spotikit for Android...\n');

  final currentDir = Directory.current;
  final androidDir = Directory(path.join(currentDir.path, 'android'));
  final appDir = Directory(path.join(androidDir.path, 'app'));

  // Verify we're in a Flutter project
  if (!File(path.join(currentDir.path, 'pubspec.yaml')).existsSync()) {
    print('❌ Error: Not in a Flutter project directory');
    exit(1);
  }

  // Verify android directory exists
  if (!androidDir.existsSync()) {
    print(
      '❌ Error: Android directory not found. Make sure you\'re in a Flutter project.',
    );
    exit(1);
  }

  try {
    await _setupSpotifyLibraries(appDir);
    await _updateBuildGradle(appDir);
    await _setupMainActivity(appDir, currentDir);

    print('\n✅ Spotikit Android initialization completed successfully!');
    print('\n📋 Next steps:');
    print('1. Add your Spotify Client ID and Client Secret to MainActivity.kt');
    print(
      '2. Update your redirect URI in AndroidManifest.xml and Spotify Developer Dashboard',
    );
    print(
      '3. Add required permissions to AndroidManifest.xml if not already present',
    );
    print('\n🎉 Happy coding with Spotikit!');
  } catch (e) {
    print('❌ Error during initialization: $e');
    exit(1);
  }
}

Future<void> _setupSpotifyLibraries(Directory appDir) async {
  print('📦 Setting up Spotify libraries...');

  final spotifyDir = Directory(path.join(appDir.path, 'spotify'));
  if (!spotifyDir.existsSync()) {
    await spotifyDir.create(recursive: true);
    print('   Created android/app/spotify/ directory');
  }

  // Copy AAR files
  final appRemoteSource = getPluginAsset(kSpotifyAppRemoteAar);
  final authStoreSource = getPluginAsset(kSpotifyAuthStoreAar);

  final appRemoteDest = File(path.join(spotifyDir.path, kSpotifyAppRemoteAar));
  final authStoreDest = File(path.join(spotifyDir.path, kSpotifyAuthStoreAar));

  if (appRemoteSource.existsSync()) {
    await appRemoteSource.copy(appRemoteDest.path);
    print('   ✓ Copied $kSpotifyAppRemoteAar');
  }

  if (authStoreSource.existsSync()) {
    await authStoreSource.copy(authStoreDest.path);
    print('   ✓ Copied $kSpotifyAuthStoreAar');
  }
}

Future<void> _updateBuildGradle(Directory appDir) async {
  print('🔧 Updating build.gradle.kts...');

  final buildGradleFile = File(path.join(appDir.path, 'build.gradle.kts'));
  if (!buildGradleFile.existsSync()) {
    // Try .gradle extension
    final buildGradleGroovyFile = File(path.join(appDir.path, 'build.gradle'));
    if (!buildGradleGroovyFile.existsSync()) {
      throw Exception('build.gradle(.kts) or build.gradle file not found in android/app/');
    } else {
      await _updateGroovyBuildGradle(buildGradleGroovyFile);
      return;
    }
  }

  String content = await buildGradleFile.readAsString();

  // Add flatDir repository if not already present
  if (!content.contains('flatDir')) {
    final repositoriesPattern = RegExp(r'repositories\s*\{');
    final match = repositoriesPattern.firstMatch(content);

    if (match != null) {
      final insertPosition = match.end;
      final repositoriesAddition = '''
    flatDir {
        dirs("spotify")
    }''';
      content =
          content.substring(0, insertPosition) +
          repositoriesAddition +
          content.substring(insertPosition);
      print('   ✓ Added flatDir repository');
    }
  }

  // Add dependencies if not already present
  final dependenciesToAdd = [
    'implementation(files("spotify/spotify-app-remote-release-0.8.0.aar"))',
    'implementation(files("spotify/spotify-auth-store-release-2.1.0.aar"))',
    'implementation("com.google.code.gson:gson:2.10.1")',
    'implementation("com.squareup.okhttp3:okhttp:4.12.0")',
    'implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")',
    'implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")',
  ];

  final dependenciesPattern = RegExp(r'dependencies\s*\{');
  final dependenciesMatch = dependenciesPattern.firstMatch(content);

  if (dependenciesMatch != null) {
    bool hasChanges = false;
    final insertPosition = dependenciesMatch.end;
    String dependenciesToInsert = '';

    for (String dependency in dependenciesToAdd) {
      if (!content.contains(dependency.split('(')[0])) {
        // Check for base dependency name
        dependenciesToInsert += '\n    $dependency';
        hasChanges = true;
      }
    }

    if (hasChanges) {
      content =
          content.substring(0, insertPosition) +
          dependenciesToInsert +
          content.substring(insertPosition);
      print('   ✓ Added Spotify dependencies');
    }
  }

  await buildGradleFile.writeAsString(content);
}

Future<void> _updateGroovyBuildGradle(File buildGradleFile) async {
  print('🔧 Updating build.gradle (Groovy)...');

  String content = await buildGradleFile.readAsString();

  // Add flatDir repository if not already present
  if (!content.contains('flatDir')) {
    final repositoriesPattern = RegExp(r'repositories\s*\{');
    final match = repositoriesPattern.firstMatch(content);

    if (match != null) {
      final insertPosition = match.end;
      final repositoriesAddition = '''
    flatDir {
        dirs 'spotify'
    }''';
      content =
          content.substring(0, insertPosition) +
          repositoriesAddition +
          content.substring(insertPosition);
      print('   ✓ Added flatDir repository');
    }
  }

  // Add dependencies if not already present (Groovy syntax)
  final dependenciesToAdd = [
    'implementation files("spotify/spotify-app-remote-release-0.8.0.aar")',
    'implementation files("spotify/spotify-auth-store-release-2.1.0.aar")',
    'implementation "com.google.code.gson:gson:2.10.1"',
    'implementation "com.squareup.okhttp3:okhttp:4.12.0"',
    'implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"',
    'implementation "androidx.lifecycle:lifecycle-runtime-ktx:2.7.0"',
  ];

  final dependenciesPattern = RegExp(r'dependencies\s*\{');
  final dependenciesMatch = dependenciesPattern.firstMatch(content);

  if (dependenciesMatch != null) {
    bool hasChanges = false;
    final insertPosition = dependenciesMatch.end;
    String dependenciesToInsert = '';

    for (String dependency in dependenciesToAdd) {
      if (!content.contains(dependency.split(' ')[1].split(':')[0])) {
        dependenciesToInsert += '\n    $dependency';
        hasChanges = true;
      }
    }

    if (hasChanges) {
      content =
          content.substring(0, insertPosition) +
          dependenciesToInsert +
          content.substring(insertPosition);
      print('   ✓ Added Spotify dependencies');
    }
  }

  await buildGradleFile.writeAsString(content);
}

Future<void> _setupMainActivity(Directory appDir, Directory projectDir) async {
  print('🏗️ Setting up MainActivity...');

  // Find MainActivity.kt
  final kotlinDir = Directory(path.join(appDir.path, 'src', 'main', 'kotlin'));
  File? mainActivityFile;

  if (kotlinDir.existsSync()) {
    await for (FileSystemEntity entity in kotlinDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('MainActivity.kt')) {
        mainActivityFile = entity;
        break;
      }
    }
  }

  if (mainActivityFile == null) {
    print('   ⚠️  Warning: MainActivity.kt not found');
    print(
      '   Please manually add the Spotikit integration code to your MainActivity.kt',
    );
    return;
  }

  final content = await mainActivityFile.readAsString();

  // Extract package name from MainActivity
  final packageMatch = RegExp(r'package\s+([\w.]+)').firstMatch(content);
  final packageName = packageMatch?.group(1) ?? 'com.example.app';

  // Create improved MainActivity with the extracted package name
  final improvedMainActivity = await _generateMainActivity(packageName);

  // Backup original file
  final backupFile = File('${mainActivityFile.path}.backup');
  await mainActivityFile.copy(backupFile.path);
  print('   ✓ Created backup: ${path.basename(backupFile.path)}');

  // Write improved MainActivity
  await mainActivityFile.writeAsString(improvedMainActivity);
  print('   ✓ Updated MainActivity.kt with Spotikit integration');

  print(
    '\n   📝 Important: Update the following constants in MainActivity.kt:',
  );
  print('   - CLIENT_ID: Your Spotify Client ID');
  print(
    '   - CLIENT_SECRET: Your Spotify Client Secret (use secure storage in production!)',
  );
  print(
    '   - REDIRECT_URI: Must match your app\'s scheme and Spotify Dashboard settings',
  );
}

Future<String> _generateMainActivity(String packageName) async {
  final file = getPluginAsset('source/main_activity.txt');

  final lines = await file.readAsLines();

  if (lines.isNotEmpty) {
    lines[0] = lines[0].replaceAll('PACKAGENAME', packageName);
  }

  return lines.join('\n');
}

File getPluginAsset(String relativePath) {
  // Current running script folder
  final scriptDir = File.fromUri(Platform.script).parent;

  // Plugin root is one level up from bin/
  final packageRoot = scriptDir.parent;

  // Full path to asset
  final assetPath = p.join(packageRoot.path, 'assets', relativePath);

  final file = File(assetPath);
  if (!file.existsSync()) {
    throw Exception('Asset not found: $assetPath');
  }

  return file;
}
