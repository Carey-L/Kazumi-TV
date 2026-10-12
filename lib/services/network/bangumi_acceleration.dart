import 'package:kazumi/services/storage/storage.dart';

enum BangumiAcceleration {
  direct,
  ech,
  mirror;

  static BangumiAcceleration get current => switch (GStorage.getSetting(
    SettingsKeys.bangumiAcceleration,
  )) {
    'direct' => direct,
    'ech' => ech,
    'mirror' => mirror,
    // Covers settings written by older builds before this explicit choice was
    // introduced. They now follow the ECH default rather than enabling the
    // mirror implicitly.
    _ => ech,
  };

  String get label => switch (this) {
    direct => '直连',
    ech => 'ECH',
    mirror => '镜像',
  };
}
