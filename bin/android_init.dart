// ignore_for_file: avoid_print

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

// URLs for direct file downloads
final kMainActivityUrl = Uri.parse(
    'https://raw.githubusercontent.com/ArdaKoksall/spotikit/master/assets/source/main_activity.txt');
final kSpotifyAppRemoteAarUrl = Uri.parse(
    'https://github.com/ArdaKoksall/spotikit/raw/master/assets/aar/spotify-app-remote-release-0.8.0.aar');
final kSpotifyAuthStoreAarUrl = Uri.parse(
    'https://github.com/ArdaKoksall/spotikit/raw/master/assets/aar/spotify-auth-store-release-2.1.0.aar');

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
    await _setupMainActivity(appDir);

    print('\n✅ Spotikit Android initialization completed successfully!');
    print('\n📋 Next steps:');
    print('1. Add your Spotify Client ID to MainActivity.kt');
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

/// Downloads a file from a URL and saves it to a destination path.
Future<void> _downloadFile(Uri url, String destinationPath) async {
  print('   Downloading ${path.basename(destinationPath)}...');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final file = File(destinationPath);
      await file.writeAsBytes(response.bodyBytes);
      print('   ✓ Saved to $destinationPath');
    } else {
      throw Exception(
          'Failed to download ${url.path}. Status code: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error downloading ${url.path}: $e');
  }
}

/// Fetches the content of a text file from a URL as a String.
Future<String> _fetchString(Uri url) async {
  print('   Fetching ${path.basename(url.path)}...');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception(
          'Failed to fetch ${url.path}. Status code: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error fetching ${url.path}: $e');
  }
}


Future<void> _setupSpotifyLibraries(Directory appDir) async {
  print('📦 Setting up Spotify libraries...');

  final spotifyDir = Directory(path.join(appDir.path, 'spotify'));
  if (!spotifyDir.existsSync()) {
    await spotifyDir.create(recursive: true);
    print('   Created android/app/spotify/ directory');
  }

  // Download and save AAR files
  final appRemoteDestPath =
  path.join(spotifyDir.path, 'spotify-app-remote-release-0.8.0.aar');
  final authStoreDestPath =
  path.join(spotifyDir.path, 'spotify-auth-store-release-2.1.0.aar');

  await _downloadFile(kSpotifyAppRemoteAarUrl, appRemoteDestPath);
  await _downloadFile(kSpotifyAuthStoreAarUrl, authStoreDestPath);
}

Future<void> _updateBuildGradle(Directory appDir) async {
  print('🔧 Updating build.gradle.kts...');

  final buildGradleFile = File(path.join(appDir.path, 'build.gradle.kts'));
  if (!buildGradleFile.existsSync()) {
    // Try .gradle extension
    final buildGradleGroovyFile = File(path.join(appDir.path, 'build.gradle'));
    if (!buildGradleGroovyFile.existsSync()) {
      throw Exception(
          'build.gradle(.kts) or build.gradle file not found in android/app/');
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
      const repositoriesAddition = '''\n    flatDir {\n        dirs("spotify")\n    }''';
      content = content.substring(0, insertPosition) +
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
      if (!content.contains(dependency.split('(')[1])) {
        dependenciesToInsert += '\n    $dependency';
        hasChanges = true;
      }
    }

    if (hasChanges) {
      content = content.substring(0, insertPosition) +
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
      const repositoriesAddition = '''\n    flatDir {\n        dirs 'spotify'\n    }''';
      content = content.substring(0, insertPosition) +
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
      // A more robust check for groovy
      if (!content.contains(dependency.replaceAll('"', "'")) &&
          !content.contains(dependency.replaceAll("'", '"'))) {
        dependenciesToInsert += '\n    $dependency';
        hasChanges = true;
      }
    }

    if (hasChanges) {
      content = content.substring(0, insertPosition) +
          dependenciesToInsert +
          content.substring(insertPosition);
      print('   ✓ Added Spotify dependencies');
    }
  }

  await buildGradleFile.writeAsString(content);
}

Future<void> _setupMainActivity(Directory appDir) async {
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
  final packageName = packageMatch?.group(1);

  if (packageName == null) {
    print('   ⚠️  Warning: Could not determine package name from MainActivity.kt');
    return;
  }

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
    '\n   📝 Important: Update the CLIENT_ID in MainActivity.kt with your Spotify Client ID.',
  );
  print(
    '   - REDIRECT_URI: Must match your app\'s scheme and Spotify Dashboard settings',
  );
}

Future<String> _generateMainActivity(String packageName) async {
  // Fetch the MainActivity content from the internet
  final content = await _fetchString(kMainActivityUrl);

  // Replace the placeholder package name
  return content.replaceFirst('package PACKAGENAME', 'package $packageName');
}