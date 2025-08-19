import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'spotikit_platform_interface.dart';

/// An implementation of [SpotikitPlatform] that uses method channels.
class MethodChannelSpotikit extends SpotikitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('spotikit');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
