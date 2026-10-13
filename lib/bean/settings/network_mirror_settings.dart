import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/split_list_row.dart';
import 'package:kazumi/services/network/bangumi_acceleration.dart';
import 'package:kazumi/services/network/image_acceleration.dart';
import 'package:kazumi/services/storage/storage.dart';

class NetworkMirrorSettings extends StatefulWidget {
  const NetworkMirrorSettings({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  State<NetworkMirrorSettings> createState() => _NetworkMirrorSettingsState();
}

class _NetworkMirrorSettingsState extends State<NetworkMirrorSettings> {
  Future<void> _save<T>(SettingKey<T> key, T value) async {
    await GStorage.putSetting(key, value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bangumiAcceleration = BangumiAcceleration.current;
    final gitProxy = GStorage.getSetting(SettingsKeys.enableGitProxy);
    final imageAcceleration = ImageAcceleration.fromSetting(
      GStorage.getSetting(SettingsKeys.imageAcceleration),
    );
    return SettingsSection(
      title: const Text('访问加速'),
      margin: widget.margin,
      tiles: [
        SettingsTile(
          leading: Icons.travel_explore_rounded,
          title: const Text('番剧条目加速'),
          description: const Text(
            '番剧信息与评论',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          value: SizedBox(
            width: 60,
            child: Text(bangumiAcceleration.label, textAlign: TextAlign.center),
          ),
          onPressed: (context) => _selectAcceleration(
            context,
            title: '番剧条目加速',
            current: bangumiAcceleration,
            modes: BangumiAcceleration.values,
            label: (mode) => mode.label,
            description: (mode) => mode.description,
            setting: SettingsKeys.bangumiAcceleration,
          ),
        ),
        SettingsTile.switchTile(
          leading: Icons.extension_rounded,
          title: const Text('规则仓库镜像'),
          description: const Text('加速规则的下载与更新'),
          initialValue: gitProxy,
          onToggle: (value) =>
              _save(SettingsKeys.enableGitProxy, value ?? !gitProxy),
        ),
        SettingsTile(
          leading: Icons.image_rounded,
          title: const Text('图片加速'),
          description: const Text(
            '封面与头像',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          value: SizedBox(
            width: 60,
            child: Text(imageAcceleration.label, textAlign: TextAlign.center),
          ),
          onPressed: (context) => _selectAcceleration(
            context,
            title: '图片加速',
            current: imageAcceleration,
            modes: ImageAcceleration.values,
            label: (mode) => mode.label,
            description: (mode) => mode.description,
            setting: SettingsKeys.imageAcceleration,
          ),
        ),
      ],
    );
  }

  Future<void> _selectAcceleration<T extends Enum>(
    BuildContext context, {
    required String title,
    required T current,
    required List<T> modes,
    required String Function(T) label,
    required String Function(T) description,
    required SettingKey<String> setting,
  }) async {
    await KazumiDialog.show<void>(
      context: context,
      builder: (_) => _AccelerationDialog<T>(
        title: title,
        value: current,
        modes: modes,
        label: label,
        description: description,
        onChanged: (value) => _save(setting, value.name),
      ),
    );
  }
}

class _AccelerationDialog<T extends Enum> extends StatefulWidget {
  const _AccelerationDialog({
    required this.title,
    required this.value,
    required this.modes,
    required this.label,
    required this.description,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> modes;
  final String Function(T) label;
  final String Function(T) description;
  final Future<void> Function(T) onChanged;

  @override
  State<_AccelerationDialog<T>> createState() => _AccelerationDialogState<T>();
}

class _AccelerationDialogState<T extends Enum>
    extends State<_AccelerationDialog<T>> {
  late T _value = widget.value;
  bool _saving = false;

  Future<void> _select(T? value) async {
    if (value == null || _saving) return;
    setState(() {
      _value = value;
      _saving = true;
    });
    await widget.onChanged(value);
    if (mounted) KazumiDialog.dismiss(context: context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: SizedBox(
      width: 360,
      child: RadioGroup<T>(
        groupValue: _value,
        onChanged: _select,
        child: SplitListGroup(
          children: [
            for (final mode in widget.modes)
              SettingsTile<T>.radioTile(
                title: Text(widget.label(mode)),
                description: Text(widget.description(mode)),
                radioValue: mode,
                enabled: !_saving,
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => KazumiDialog.dismiss(context: context),
        child: const Text('取消'),
      ),
    ],
  );
}

extension on BangumiAcceleration {
  String get description => switch (this) {
    BangumiAcceleration.direct => '访问官方接口',
    BangumiAcceleration.ech => '启用加密握手',
    BangumiAcceleration.mirror => '使用 Kazumi 镜像接口',
  };
}

extension on ImageAcceleration {
  String get label => switch (this) {
    ImageAcceleration.direct => '直连',
    ImageAcceleration.ech => 'ECH',
    ImageAcceleration.mirror => '镜像',
  };

  String get description => switch (this) {
    ImageAcceleration.direct => '加载原始图片',
    ImageAcceleration.ech => '加密握手（推荐）',
    ImageAcceleration.mirror => '使用图片镜像',
  };
}
