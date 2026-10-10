import 'package:flutter/services.dart' show appFlavor;

/// Whether the current executable was built from the Android TV flavor.
///
/// Keeping this compile-time value in one place lets TV interaction changes
/// stay isolated from the phone and desktop builds.
const bool isTvBuild = appFlavor == 'tv';
