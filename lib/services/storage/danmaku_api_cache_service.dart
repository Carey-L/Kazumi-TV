import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores raw DanDanPlay API responses for the current app session.
///
/// The cache is deliberately keyed by request path: the two supported APIs
/// already encode the Bangumi or episode identity in their paths.
class DanmakuApiCacheService {
  static const _directoryName = 'dandan_api_cache';

  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, _directoryName));
  }

  Future<File> _fileForPath(String requestPath) async {
    final directory = await _directory();
    final key = sha256.convert(utf8.encode(requestPath)).toString();
    return File(p.join(directory.path, '$key.json'));
  }

  Future<dynamic> read(String requestPath) async {
    final file = await _fileForPath(requestPath);
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } on FormatException {
      // A partial or legacy entry must not prevent a fresh API response.
      await file.delete();
      return null;
    }
  }

  Future<void> write(String requestPath, Object? response) async {
    final file = await _fileForPath(requestPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(response), flush: true);
  }

  Future<int> sizeInBytes() async {
    final directory = await _directory();
    if (!await directory.exists()) return 0;

    var bytes = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) bytes += await entity.length();
    }
    return bytes;
  }

  Future<void> clear() async {
    final directory = await _directory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
