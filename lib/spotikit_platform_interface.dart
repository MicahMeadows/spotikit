import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'spotikit_method_channel.dart';

abstract class SpotikitPlatform extends PlatformInterface {
  /// Constructs a SpotikitPlatform.
  SpotikitPlatform() : super(token: _token);

  static final Object _token = Object();

  static SpotikitPlatform _instance = MethodChannelSpotikit();

  /// The default instance of [SpotikitPlatform] to use.
  ///
  /// Defaults to [MethodChannelSpotikit].
  static SpotikitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SpotikitPlatform] when
  /// they register themselves.
  static set instance(SpotikitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
