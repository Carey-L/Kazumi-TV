String resolveAndroidVideoRenderer({
  required String configuredRenderer,
  required int androidSdkVersion,
  required bool isEmulator,
}) {
  // Android Emulator's Vulkan implementation can abort the whole virtual
  // device when libplacebo initializes gpu-next. OpenGL is slower but stable.
  if (isEmulator && configuredRenderer == 'gpu-next') {
    return 'gpu';
  }
  if (configuredRenderer != 'auto') {
    return configuredRenderer;
  }
  if (isEmulator) {
    return 'gpu';
  }
  return androidSdkVersion >= 34 ? 'gpu-next' : 'gpu';
}
