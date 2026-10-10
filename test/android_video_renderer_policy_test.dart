import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/android_video_renderer_policy.dart';

void main() {
  group('resolveAndroidVideoRenderer', () {
    test('uses OpenGL for auto mode on an emulator', () {
      expect(
        resolveAndroidVideoRenderer(
          configuredRenderer: 'auto',
          androidSdkVersion: 36,
          isEmulator: true,
        ),
        'gpu',
      );
    });

    test('downgrades an explicit gpu-next renderer on an emulator', () {
      expect(
        resolveAndroidVideoRenderer(
          configuredRenderer: 'gpu-next',
          androidSdkVersion: 36,
          isEmulator: true,
        ),
        'gpu',
      );
    });

    test('keeps gpu-next for a modern physical device', () {
      expect(
        resolveAndroidVideoRenderer(
          configuredRenderer: 'auto',
          androidSdkVersion: 34,
          isEmulator: false,
        ),
        'gpu-next',
      );
    });

    test('uses OpenGL on older physical devices', () {
      expect(
        resolveAndroidVideoRenderer(
          configuredRenderer: 'auto',
          androidSdkVersion: 33,
          isEmulator: false,
        ),
        'gpu',
      );
    });
  });
}
