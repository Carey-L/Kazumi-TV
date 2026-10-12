import 'dart:convert';
import 'dart:io';

import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/services/logging/logger.dart';

abstract interface class DanmakuCacheReader {
  Future<List<DanmakuEntry>?> getCachedDanmakus(
    int bangumiId,
    String pluginName,
    int episodeNumber,
  );

  Future<void> updateCachedDanmakus(
    int bangumiId,
    String pluginName,
    int episodeNumber,
    List<DanmakuEntry> danmakus,
    int danDanBangumiID,
  );
}

class DownloadDanmakuCacheService implements DanmakuCacheReader {
  DownloadDanmakuCacheService(this._repository);

  final IDownloadRepository _repository;

  String _path(String directory) => '$directory/danmaku.json';

  @override
  Future<List<DanmakuEntry>?> getCachedDanmakus(
    int bangumiId,
    String pluginName,
    int episodeNumber,
  ) async {
    final episode = _repository.getEpisode(
      bangumiId,
      pluginName,
      episodeNumber,
    );
    if (episode == null || episode.downloadDirectory.isEmpty) return null;
    final file = File(_path(episode.downloadDirectory));
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      final values = decoded is Map ? decoded['danmakus'] : decoded;
      if (values is! List) return null;
      return values
          .whereType<Map>()
          .map(
            (value) => DanmakuEntry.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList();
    } catch (error) {
      KazumiLogger().w(
        'DownloadDanmakuCacheService: read failed',
        error: error,
      );
      return null;
    }
  }

  @override
  Future<void> updateCachedDanmakus(
    int bangumiId,
    String pluginName,
    int episodeNumber,
    List<DanmakuEntry> danmakus,
    int danDanBangumiID,
  ) async {
    final record = _repository.getRecord('${pluginName}_$bangumiId');
    final episode = record?.episodes[episodeNumber];
    if (episode == null || episode.downloadDirectory.isEmpty) return;
    try {
      final file = File(_path(episode.downloadDirectory));
      await file.writeAsString(
        jsonEncode({
          'danDanBangumiID': danDanBangumiID,
          'danmakus': danmakus.map((danmaku) => danmaku.toJson()).toList(),
        }),
      );
      if (episode.danmakuData.isNotEmpty && record != null) {
        episode.danmakuData = '';
        await _repository.updateEpisode(record.key, episodeNumber, episode);
      }
    } catch (error) {
      KazumiLogger().w(
        'DownloadDanmakuCacheService: write failed',
        error: error,
      );
    }
  }
}
