#!/usr/bin/env dart

import 'dart:io';

// ignore_for_file: avoid_print
const String _spotifyAppRemoteDir = 'android/spotify-app-remote';
const String _spotifyAuthDir = 'android/spotify-auth';

Future<void> main() async {
  print("Starting Android cleanup...");
  try {
    await deleteSpotify();
    await resetGradle();
    print("✅ Android cleanup completed successfully.");
    exit(0);
  } catch (e) {
    print("Error during cleanup: $e");
    exit(1);
  }
}

Future<void> deleteSpotify() async {
  final remoteFolder = Directory(_spotifyAppRemoteDir);
  if (await remoteFolder.exists()) {
    await remoteFolder.delete(recursive: true);
  } else {
    print('$_spotifyAppRemoteDir does not exist, skipping.');
  }

  final authFolder = Directory(_spotifyAuthDir);
  if (await authFolder.exists()) {
    await authFolder.delete(recursive: true);
  } else {
    print('$_spotifyAuthDir does not exist, skipping.');
  }
  print('✅ Deleted Spotify directories successfully.');
}

Future<void> resetGradle() async {
  final gradleFiles = [
    File('android/settings.gradle'),
    File('android/settings.gradle.kts'),
  ];

  File? file;
  for (var f in gradleFiles) {
    if (await f.exists()) {
      file = f;
      break;
    }
  }

  if (file == null) {
    throw Exception(
      '⚠️ Neither settings.gradle nor settings.gradle.kts exists.',
    );
  }

  final spotifyLines = [
    'include(":spotify-app-remote")',
    'include(":spotify-auth")',
  ];

  final existingLines = await file.readAsLines();

  if (existingLines.length >= 2 &&
      existingLines[0].trim() == spotifyLines[0] &&
      existingLines[1].trim() == spotifyLines[1]) {
    final newContent = existingLines.sublist(2).join('\n');
    await file.writeAsString(newContent);
  } else {
    print(
      'ℹ️ Spotify includes not found at the top of ${file.path}, nothing removed.',
    );
  }
}
