import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/repositories/history_repository.dart';

void main() {
  late Directory tempDir;
  late Box<History> historiesBox;
  late int appendCount;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('kazumi_history_ctrl_');
    Hive.init(tempDir.path);
    _registerAdapters();
    historiesBox = await Hive.openBox<History>('histories');
  });

  setUp(() async {
    await historiesBox.clear();
    appendCount = 0;
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('coalesces rapid updates into the latest snapshot', () async {
    final repository = HistoryRepository(
      historiesBox: historiesBox,
      privateModeReader: () => false,
      progressSyncAppender:
          ({
            required history,
            required episode,
            required road,
            required progressMs,
            required updatedAt,
          }) async {
            appendCount++;
          },
      deleteSyncAppender: _noopDeleteSync,
      clearSyncAppender: _noopClearSync,
    );
    final controller = HistoryController(repository);
    final identity = _identity(20);

    for (var seconds = 1; seconds <= 5; seconds++) {
      controller.updateHistory(identity, Duration(seconds: seconds));
    }
    await controller.flushPending();

    final history = repository.getHistory('plugin', identity.bangumiItem);
    expect(history!.progresses[1]!.progress, const Duration(seconds: 5));
    expect(appendCount, 1);
  });

  test('flush persists the newest position before disposal', () async {
    final repository = HistoryRepository(
      historiesBox: historiesBox,
      privateModeReader: () => false,
      progressSyncAppender:
          ({
            required history,
            required episode,
            required road,
            required progressMs,
            required updatedAt,
          }) async {
            appendCount++;
          },
      deleteSyncAppender: _noopDeleteSync,
      clearSyncAppender: _noopClearSync,
    );
    final controller = HistoryController(repository);
    final identity = _identity(21);

    controller.updateHistory(identity, const Duration(seconds: 2));
    controller.updateHistory(identity, const Duration(seconds: 42));
    await controller.dispose();

    final history = repository.getHistory('plugin', identity.bangumiItem);
    expect(history!.progresses[1]!.progress, const Duration(seconds: 42));
    expect(appendCount, 1);
  });

  test('keeps separate identities isolated', () async {
    final repository = HistoryRepository(
      historiesBox: historiesBox,
      privateModeReader: () => false,
      progressSyncAppender:
          ({
            required history,
            required episode,
            required road,
            required progressMs,
            required updatedAt,
          }) async {
            appendCount++;
          },
      deleteSyncAppender: _noopDeleteSync,
      clearSyncAppender: _noopClearSync,
    );
    final controller = HistoryController(repository);

    controller.updateHistory(_identity(30), const Duration(seconds: 10));
    controller.updateHistory(_identity(31), const Duration(seconds: 20));
    await controller.flushPending();

    expect(
      repository.getHistory('plugin', _item(30))!.progresses[1]!.progress,
      const Duration(seconds: 10),
    );
    expect(
      repository.getHistory('plugin', _item(31))!.progresses[1]!.progress,
      const Duration(seconds: 20),
    );
    expect(appendCount, 2);
  });
}

PlaybackHistoryIdentity _identity(int id) {
  return PlaybackHistoryIdentity.online(
    bangumiItem: _item(id),
    pluginName: 'plugin',
    episodeNumber: 1,
    episodeTitle: 'EP1',
    road: 0,
    onlineBangumiSrc: 'https://example.com/source',
    episodePageUrl: '/online/1',
  );
}

Future<void> _noopDeleteSync(History history) async {}

Future<void> _noopClearSync() async {}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(HistoryAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(ProgressAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(BangumiItemAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(BangumiTagAdapter());
  }
}

BangumiItem _item(int id) {
  return BangumiItem(
    id: id,
    type: 2,
    name: 'subject $id',
    nameCn: '条目 $id',
    summary: '',
    airDate: '2026-01-01',
    airWeekday: 4,
    rank: 0,
    images: const {
      'large': '',
      'common': '',
      'medium': '',
      'small': '',
      'grid': '',
    },
    tags: const <BangumiTag>[],
    alias: const [],
    ratingScore: 0,
    votes: 0,
    votesCount: const [],
    info: '',
  );
}
