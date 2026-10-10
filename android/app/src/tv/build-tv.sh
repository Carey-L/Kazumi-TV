#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
flutter_output="$project_root/build/app/outputs/flutter-apk/app-tv-release.apk"
output_directory="$project_root/build/tv"
final_output="$output_directory/Kazumi-TV-armv7-arm64-release.apk"

# ech_http needs CMake >=3.22, but its hook picks an SDK CMake by sorting the
# version directories as strings, so '3.6.4111459' outranks '3.22.1'. Putting
# the newest CMake first on PATH makes the hook use it instead.
prepend_newest_cmake() {
  local sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  if [ -z "$sdk_root" ]; then
    sdk_root="$(sed -n 's/^sdk\.dir=//p' "$project_root/android/local.properties" 2>/dev/null | head -1)"
  fi
  [ -n "$sdk_root" ] || return 0
  # local.properties escapes separators for Java properties files.
  sdk_root="${sdk_root//\\\\//}"
  [ -d "$sdk_root/cmake" ] || return 0

  local newest
  newest="$(find "$sdk_root/cmake" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
  [ -n "$newest" ] || return 0
  [ -f "$newest/bin/cmake.exe" ] || [ -x "$newest/bin/cmake" ] || {
    echo "warning: no cmake binary under $newest; leaving PATH unchanged" >&2
    return 0
  }

  export PATH="$newest/bin:$PATH"
  echo "Using CMake from $newest"
}

prepend_newest_cmake

cd "$project_root"
flutter pub get
flutter build apk \
  --release \
  --flavor tv \
  --target-platform android-arm,android-arm64 \
  "$@"

test -f "$flutter_output"
mkdir -p "$output_directory"
cp "$flutter_output" "$final_output"

apk_entries="$(unzip -Z1 "$final_output")"
grep -Fxq 'lib/arm64-v8a/libapp.so' <<<"$apk_entries"
grep -Fxq 'lib/armeabi-v7a/libapp.so' <<<"$apk_entries"

echo "TV APK created: $final_output"
