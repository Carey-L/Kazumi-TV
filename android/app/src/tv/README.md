# Kazumi TV Android source set

This directory contains the Android TV-specific manifest, launcher banner, and
build helpers. It is the `tv` Android product flavor and reuses the main
Flutter application and Android platform implementation.

The TV flavor:

- uses application ID `com.predidit.kazumi.tv`;
- declares Android Leanback support and no touchscreen requirement;
- exposes the launcher activity through `LEANBACK_LAUNCHER`;
- locks the TV activity to landscape;
- builds one APK containing `arm64-v8a` and `armeabi-v7a`.

Remote control behavior:

- D-pad navigation uses Flutter's focus traversal throughout the app;
- home, timeline, and collection cards show a focus ring, scale slightly, and
  scroll into view when focused;
- the landscape navigation rail's search action is the initial focus target;
- Select, Enter, and gamepad A activate the focused control;
- on the video surface, Select toggles playback, left/right seek, up changes
  volume, and down enters the visible playback controls;
- once a playback control has focus, D-pad and Select are reserved for control
  navigation instead of being intercepted as player shortcuts;
- play, pause, fast-forward, rewind, next, previous, and volume media keys are
  mapped to their corresponding player actions.

Build on Windows:

```powershell
.\android\app\src\tv\build-tv.ps1
```

Build on Linux or macOS:

```bash
bash android/app/src/tv/build-tv.sh
```

Extra Flutter arguments can be appended to either command, for example the
project's release credential `--dart-define` values. The resulting package is
written to:

```text
build/tv/Kazumi-TV-armv7-arm64-release.apk
```

The scripts inspect the completed APK and fail unless both requested ABI
variants are present. To build the existing phone package, use the `mobile`
flavor:

```bash
flutter build apk --release --flavor mobile
```
