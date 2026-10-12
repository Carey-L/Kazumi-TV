import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/services/download/download_manager.dart';

abstract interface class OfflinePlaybackReader {
  DownloadEpisode? getEpisode(
    int bangumiId,
    String pluginName,
    int episodeNumber,
  );

  List<DownloadEpisode> getCompletedEpisodes(int bangumiId, String pluginName);

  String? getLocalVideoPath(
    int bangumiId,
    String pluginName,
    int episodeNumber,
  );
}

class DownloadQueryService implements OfflinePlaybackReader {
  DownloadQueryService(this._repository, this._downloadManager);

  final IDownloadRepository _repository;
  final IDownloadManager _downloadManager;

  @override
  DownloadEpisode? getEpisode(
    int bangumiId,
    String pluginName,
    int episodeNumber,
  ) {
    return _repository.getEpisode(bangumiId, pluginName, episodeNumber);
  }

  @override
  List<DownloadEpisode> getCompletedEpisodes(int bangumiId, String pluginName) {
    return _repository.getCompletedEpisodes(bangumiId, pluginName);
  }

  @override
  String? getLocalVideoPath(
    int bangumiId,
    String pluginName,
    int episodeNumber,
  ) {
    final episode = getEpisode(bangumiId, pluginName, episodeNumber);
    return episode == null ? null : _downloadManager.getLocalVideoPath(episode);
  }
}
