import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/danmaku_api_cache_service.dart';
import 'package:kazumi/services/storage/image_cache_service.dart';

class StorageSettingsPage extends StatefulWidget {
  const StorageSettingsPage({super.key});

  @override
  State<StorageSettingsPage> createState() => _StorageSettingsPageState();
}

class _StorageSettingsPageState extends State<StorageSettingsPage> {
  final _cache = ImageCacheService();
  final _danmakuCache = DanmakuApiCacheService();
  late Future<int> _cacheSize = _cache.sizeInBytes();
  late Future<int> _danmakuCacheSize = _danmakuCache.sizeInBytes();
  bool _clearing = false;
  bool _clearingDanmaku = false;

  void _refreshSize() => setState(() {
    _cacheSize = _cache.sizeInBytes();
  });

  void _refreshDanmakuSize() => setState(() {
    _danmakuCacheSize = _danmakuCache.sizeInBytes();
  });

  void _message(String message) {
    KazumiDialog.showToast(context: context, message: message);
  }

  void _refreshAfterClear(void Function() refresh, String cacheName) {
    try {
      refresh();
    } catch (error, stackTrace) {
      // The files were already cleared. A size-refresh failure must not turn
      // that successful operation into a false failure message.
      KazumiLogger().w(
        'StorageSettingsPage: failed to refresh $cacheName cache size',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _confirmClear() async {
    if (_clearing) return;
    final confirmed = await KazumiDialog.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cleaning_services_rounded),
        title: const Text('清除图片缓存？'),
        content: const Text('图片会在下次加载时重新下载。视频、记录和设置不会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除缓存'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    var cleared = false;
    try {
      await _cache.clear();
      cleared = true;
    } catch (error, stackTrace) {
      KazumiLogger().w(
        'StorageSettingsPage: failed to clear image cache',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    setState(() => _clearing = false);
    if (!cleared) {
      _message('清除失败，请稍后重试');
      return;
    }
    _refreshAfterClear(_refreshSize, 'image');
    _message('图片缓存已清除');
  }

  Future<void> _confirmClearDanmaku() async {
    if (_clearingDanmaku) return;
    final confirmed = await KazumiDialog.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cleaning_services_rounded),
        title: const Text('清除弹幕缓存？'),
        content: const Text('弹幕会在下次播放时重新获取。视频、记录和设置不会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除缓存'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearingDanmaku = true);
    var cleared = false;
    try {
      await _danmakuCache.clear();
      cleared = true;
    } catch (error, stackTrace) {
      KazumiLogger().w(
        'StorageSettingsPage: failed to clear danmaku cache',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    setState(() => _clearingDanmaku = false);
    if (!cleared) {
      _message('清除失败，请稍后重试');
      return;
    }
    _refreshAfterClear(_refreshDanmakuSize, 'danmaku');
    _message('弹幕缓存已清除');
  }

  String _cacheDescription(AsyncSnapshot<int> snapshot, bool clearing) {
    if (clearing) return '正在清除…';
    if (snapshot.connectionState != ConnectionState.done) return '正在统计…';
    if (snapshot.hasError) return '统计失败';
    return '${(snapshot.requireData / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
    title: const Text('存储与日志'),
    body: FutureBuilder<int>(
      future: _cacheSize,
      builder: (context, snapshot) => SettingsList(
        sections: [
          SettingsSection(
            title: const Text('缓存'),
            tiles: [
              SettingsTile(
                leading: Icons.image_outlined,
                title: const Text('清除图片缓存'),
                description: Text(_cacheDescription(snapshot, _clearing)),
                enabled:
                    snapshot.connectionState == ConnectionState.done &&
                    !_clearing,
                onPressed: (_) => _confirmClear(),
                trailing:
                    snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasError &&
                        !_clearing
                    ? IconButton(
                        tooltip: '重新统计',
                        onPressed: _refreshSize,
                        icon: const Icon(Icons.refresh_rounded),
                      )
                    : const Icon(Icons.cleaning_services_rounded),
              ),
              FutureBuilder<int>(
                future: _danmakuCacheSize,
                builder: (context, danmakuSnapshot) => SettingsTile(
                  leading: Icons.subtitles_outlined,
                  title: const Text('清除弹幕缓存'),
                  description: Text(
                    _cacheDescription(danmakuSnapshot, _clearingDanmaku),
                  ),
                  enabled:
                      danmakuSnapshot.connectionState == ConnectionState.done &&
                      !_clearingDanmaku,
                  onPressed: (_) => _confirmClearDanmaku(),
                  trailing:
                      danmakuSnapshot.connectionState == ConnectionState.done &&
                          danmakuSnapshot.hasError &&
                          !_clearingDanmaku
                      ? IconButton(
                          tooltip: '重新统计',
                          onPressed: _refreshDanmakuSize,
                          icon: const Icon(Icons.refresh_rounded),
                        )
                      : const Icon(Icons.cleaning_services_rounded),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('诊断'),
            tiles: [
              SettingsTile(
                leading: Icons.receipt_long_rounded,
                title: const Text('错误日志'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onPressed: (_) => context.pushNamed('/settings/storage/logs'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
