#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
flutter_output="$project_root/build/app/outputs/flutter-apk/app-tv-release.apk"
output_directory="$project_root/build/tv"
final_output="$output_directory/Kazumi-TV-armv7-arm64-release.apk"

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
