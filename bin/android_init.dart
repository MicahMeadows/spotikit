#!/usr/bin/env dart

// ignore_for_file: avoid_print

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

const String spotifyAppRemoteUrl =
    'https://github.com/spotify/android-sdk/releases/download/v0.8.0-appremote_v2.1.0-auth/spotify-app-remote-release-0.8.0.aar';
const String spotifyAuthUrl =
    'https://github.com/spotify/android-sdk/releases/download/v0.8.0-appremote_v2.1.0-auth/spotify-auth-release-2.1.0.aar';
const String pluginTemplateUrl =
    'https://raw.githubusercontent.com/ArdaKoksall/spotikit/refs/heads/master/asset/spotikit_plugin';

Future<void> main(List<String> args) async {
  print('🎵 Initializing Spotikit Android setup...\n');

  try {
    // Check if we're in a Flutter project
    if (!await File('pubspec.yaml').exists()) {
      throw Exception(
        'pubspec.yaml not found. Make sure you\'re running this from the root of your Flutter project.',
      );
    }

    // Check if android/app exists
    final androidAppDir = Directory('android/app');
    if (!await androidAppDir.exists()) {
      throw Exception(
        'android/app directory not found. This command must be run from a Flutter project with Android support.',
      );
    }

    // Get package name from pubspec.yaml or android configuration
    final packageName = await getPackageName();
    print('📦 Detected package name: $packageName\n');

    // Create spotify directory
    final spotifyDir = Directory('android/app/spotify');
    if (!await spotifyDir.exists()) {
      await spotifyDir.create(recursive: true);
      print('📁 Created android/app/spotify directory');
    }

    // Download Spotify SDK files
    await downloadFile(
      spotifyAppRemoteUrl,
      'android/app/spotify/spotify-app-remote-release-0.8.0.aar',
    );
    await downloadFile(
      spotifyAuthUrl,
      'android/app/spotify/spotify-auth-release-2.1.0.aar',
    );

    // Download and process the plugin template
    await downloadAndProcessTemplate(packageName);

    print('\n✅ Spotikit Android initialization completed successfully!');
    print('📝 The following files have been set up:');
    print('   • android/app/spotify/spotify-app-remote-release-0.8.0.aar');
    print('   • android/app/spotify/spotify-auth-release-2.1.0.aar');
    print('   • ${getKotlinPath(packageName)}/SpotikitPlugin.kt');
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}

Future<String> getPackageName() async {
  // First try to get from pubspec.yaml
  try {
    final pubspecContent = await File('pubspec.yaml').readAsString();
    final pubspec = loadYaml(pubspecContent);
    if (pubspec['name'] != null) {
      // Check if there's a custom package name in android configuration
      final androidManifest = File('android/app/src/main/AndroidManifest.xml');
      if (await androidManifest.exists()) {
        final manifestContent = await androidManifest.readAsString();
        final packageMatch = RegExp(
          r'package="([^"]+)"',
        ).firstMatch(manifestContent);
        if (packageMatch != null) {
          return packageMatch.group(1)!;
        }
      }

      // Fallback to a default pattern based on project name
      final projectName = pubspec['name'] as String;
      return 'com.example.$projectName';
    }
  } catch (e) {
    // Continue to fallback method
  }

  // Fallback: try to extract from existing MainActivity
  try {
    final mainActivityFile = await findMainActivity();
    if (mainActivityFile != null) {
      final content = await mainActivityFile.readAsString();
      final packageMatch = RegExp(r'package\s+([^\s;]+)').firstMatch(content);
      if (packageMatch != null) {
        return packageMatch.group(1)!;
      }
    }
  } catch (e) {
    // Continue to error
  }

  throw Exception(
    'Could not determine package name. Please make sure your Android project is properly configured.',
  );
}

Future<File?> findMainActivity() async {
  final srcDir = Directory('android/app/src/main');
  if (!await srcDir.exists()) return null;

  await for (final entity in srcDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('MainActivity.kt')) {
      return entity;
    }
  }

  await for (final entity in srcDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('MainActivity.java')) {
      return entity;
    }
  }

  return null;
}

Future<void> downloadFile(String url, String targetPath) async {
  print('⬇️  Downloading ${path.basename(targetPath)}...');

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final file = File(targetPath);
      await file.writeAsBytes(response.bodyBytes);
      print('✅ Downloaded ${path.basename(targetPath)}');
    } else {
      throw Exception(
        'Failed to download $url (Status: ${response.statusCode})',
      );
    }
  } catch (e) {
    throw Exception('Failed to download ${path.basename(targetPath)}: $e');
  }
}

Future<void> downloadAndProcessTemplate(String packageName) async {
  print('⬇️  Downloading and processing plugin template...');

  try {
    final response = await http.get(Uri.parse(pluginTemplateUrl));
    if (response.statusCode == 200) {
      // Replace PACKAGE_NAME with actual package name
      String content = response.body;
      content = content.replaceAll('PACKAGE_NAME', packageName);

      // Create target directory structure
      final targetPath = getKotlinPath(packageName);
      final targetDir = Directory(path.dirname(targetPath));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Write the processed file
      final targetFile = File(targetPath);
      await targetFile.writeAsString(content);
      print('✅ Created SpotikitPlugin.kt with package name: $packageName');
    } else {
      throw Exception(
        'Failed to download plugin template (Status: ${response.statusCode})',
      );
    }
  } catch (e) {
    throw Exception('Failed to download and process plugin template: $e');
  }
}

String getKotlinPath(String packageName) {
  final packagePath = packageName.replaceAll('.', '/');
  return 'android/app/src/main/kotlin/$packagePath/SpotikitPlugin.kt';
}
