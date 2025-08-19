import 'package:flutter_test/flutter_test.dart';
import 'package:spotikit/spotikit_platform_interface.dart';
import 'package:spotikit/spotikit_method_channel.dart';

void main() {
  final SpotikitPlatform initialPlatform = SpotikitPlatform.instance;

  test('$MethodChannelSpotikit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSpotikit>());
  });
}
