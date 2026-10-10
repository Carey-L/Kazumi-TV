import 'package:kazumi/services/storage/storage.dart';

/// Android grants app access to the user-picked download directory directly,
/// so this is an identity function. The interface is kept because download
/// path handling is written against it.
class SecureBookmarkService {
  SecureBookmarkService._();

  static Future<bool> persist(String path) async => true;

  static Future<String?> restore(String path) async => path;

  static Future<void> clear() async {
    await GStorage.putSetting(SettingsKeys.downloadDirectoryBookmark, '');
  }
}