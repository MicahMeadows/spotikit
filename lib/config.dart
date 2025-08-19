import 'dart:io';
import 'package:yaml/yaml.dart';

class ManifestConfig {
  final String scheme;
  final String host;

  ManifestConfig({
    required this.scheme,
    required this.host,
  });
}

class SpotikitConfig {
  final String redirectUri;
  final String clientId;
  final String clientSecret;
  final String scope;
  final String packageName;
  final ManifestConfig manifest;

  static const String defaultScope =
      "user-read-private user-read-email user-modify-playback-state user-read-playback-state streaming app-remote-control";

  SpotikitConfig({
    required this.redirectUri,
    required this.clientId,
    required this.clientSecret,
    required this.manifest,
    required this.packageName,
    String? scope,
  }) : scope = scope ?? defaultScope;

  factory SpotikitConfig.fromPubspec(String packageName) {
    final file = File('pubspec.yaml');
    if (!file.existsSync()) {
      throw Exception('pubspec.yaml not found!');
    }

    final content = file.readAsStringSync();
    final yamlMap = loadYaml(content);

    if (yamlMap['spotikit_android'] == null) {
      throw Exception('spotikit_android configuration missing in pubspec.yaml');
    }

    final configMap = yamlMap['spotikit_android'];
    return SpotikitConfig(
      redirectUri: configMap['redirect_uri'] ?? '',
      clientId: configMap['client_id'] ?? '',
      clientSecret: configMap['client_secret'] ?? '',
      manifest: ManifestConfig(
        scheme: configMap['scheme'] ?? '',
        host: configMap['host'] ?? '',
      ),
      scope: configMap['scope'],
    );
  }
}
