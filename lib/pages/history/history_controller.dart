import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/repositories/history_repository.dart';
import 'package:kazumi/modules/history/history_module.dart';

part 'history_controller.g.dart';

class HistoryController = _HistoryController with _$HistoryController;

class _PendingHistoryUpdate {
  _PendingHistoryUpdate({
    required this.identity,
    required this.progress,
    required this.duration,
  });

  PlaybackHistoryIdentity identity;
  Duration progress;
  Duration duration;
  Timer? timer;
}

abstract class _HistoryController with Store {
  _HistoryController(this._historyRepository) {
    _changesSubscription = _historyRepository.changes.listen((_) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(milliseconds: 250), init);
    });
  }

  static const _writeThrottle = Duration(seconds: 3);

  final IHistoryRepository _historyRepository;
  final Map<String, _PendingHistoryUpdate> _pendingUpdates = {};
  StreamSubscription<void>? _changesSubscription;
  Timer? _refreshTimer;

  @observable
  ObservableList<History> histories = ObservableList<History>();

  void init() {
    final temp = _historyRepository.getAllHistories();
    histories.clear();
    histories.addAll(temp);
  }

  /// Queues the latest playback position for [identity], coalescing rapid
  /// updates so only the newest snapshot reaches storage and sync.
  void updateHistory(
    PlaybackHistoryIdentity identity,
    Duration progress, {
    Duration duration = Duration.zero,
  }) {
    final key = History.getKey(
      identity.pluginName,
      identity.bangumiItem,
      entryKind: identity.entryKind,
    );
    final pending = _pendingUpdates[key];
    if (pending != null) {
      pending.identity = identity;
      pending.progress = progress;
      pending.duration = duration;
      pending.timer ??= Timer(_writeThrottle, () => _flushKey(key));
      return;
    }

    final next = _PendingHistoryUpdate(
      identity: identity,
      progress: progress,
      duration: duration,
    );
    _pendingUpdates[key] = next;
    next.timer = Timer(_writeThrottle, () => _flushKey(key));
  }

  /// Persists every queued position immediately, e.g. on pause, episode
  /// switch, or route disposal.
  Future<void> flushPending() async {
    final keys = List<String>.of(_pendingUpdates.keys);
    await Future.wait(keys.map(_flushKey));
  }

  Future<void> dispose() async {
    _refreshTimer?.cancel();
    await _changesSubscription?.cancel();
    await flushPending();
  }

  Future<void> _flushKey(String key) async {
    final pending = _pendingUpdates.remove(key);
    if (pending == null) return;
    pending.timer?.cancel();
    await _historyRepository.updateHistory(
      identity: pending.identity,
      progress: pending.progress,
      duration: pending.duration,
    );
  }

  Progress? lastWatching(
    BangumiItem bangumiItem,
    String adapterName, {
    String entryKind = HistoryEntryKind.online,
  }) {
    return _historyRepository.getLastWatchingProgress(
      bangumiItem,
      adapterName,
      entryKind: entryKind,
    );
  }

  Progress? findProgress(
    BangumiItem bangumiItem,
    String adapterName,
    int episode, {
    String entryKind = HistoryEntryKind.online,
  }) {
    return _historyRepository.findProgress(
      bangumiItem,
      adapterName,
      episode,
      entryKind: entryKind,
    );
  }

  Future<void> deleteHistory(History history) async {
    await flushPending();
    await _historyRepository.deleteHistory(history);
    _refreshTimer?.cancel();
    histories.removeWhere((item) => item.key == history.key);
  }

  Future<void> clearAll() async {
    await flushPending();
    await _historyRepository.clearAllHistories();
    _refreshTimer?.cancel();
    histories.clear();
  }
}
