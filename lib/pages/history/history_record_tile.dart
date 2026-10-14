import 'package:flutter/material.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/history/history_module.dart';

class HistoryRecordTile extends StatelessWidget {
  const HistoryRecordTile({
    super.key,
    required this.history,
    required this.onPlay,
    required this.onDetails,
    required this.onDelete,
    required this.collectType,
    required this.onChangeCollect,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.editing = false,
    this.busy = false,
    this.autofocus = false,
    this.focusNode,
  });

  final History history;
  final VoidCallback onPlay;
  final VoidCallback onDetails;
  final Future<void> Function() onDelete;
  final CollectType collectType;
  final ValueChanged<CollectType>? onChangeCollect;
  final BorderRadius borderRadius;
  final bool editing;
  final bool busy;
  final bool autofocus;
  final FocusNode? focusNode;

  String get _position {
    final progress = history.progresses[history.lastWatchEpisode]?.progress;
    if (progress == null || progress.inSeconds <= 0) return '';
    final seconds = (progress.inSeconds % 60).toString().padLeft(2, '0');
    final minutes = (progress.inMinutes % 60).toString().padLeft(2, '0');
    final position = progress.inHours > 0
        ? '${progress.inHours}:$minutes:$seconds'
        : '${progress.inMinutes}:$seconds';
    return '看到 $position';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = history.bangumiItem.nameCn.isEmpty
        ? history.bangumiItem.name
        : history.bangumiItem.nameCn;
    final episode = history.lastWatchEpisodeName.isEmpty
        ? '第 ${history.lastWatchEpisode} 话'
        : history.lastWatchEpisodeName;
    final source =
        HistoryEntryKind.normalize(history.entryKind) ==
            HistoryEntryKind.offline
        ? '缓存'
        : '在线';
    final time = TimeOfDay.fromDateTime(
      history.lastWatchTime.toLocal(),
    ).format(context);
    final image = history.bangumiItem.images['large'] ?? '';
    final position = _position;

    return Dismissible(
      key: ValueKey(history.key),
      direction: busy || editing
          ? DismissDirection.none
          : DismissDirection.endToStart,
      // The parent removes saved deletions; failed writes keep the row usable.
      confirmDismiss: (_) async {
        await onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: borderRadius,
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colors.onErrorContainer,
        ),
      ),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 600;
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(14) > 21;
                  final coverWidth = wide ? 72.0 : 60.0;
                  final content = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        episode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (position.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          position,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        [
                          source,
                          if (history.adapterName.isNotEmpty)
                            history.adapterName,
                          time,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                  final actions = _actions(context, wide: wide || largeText);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ExcludeSemantics(
                            child: IgnorePointer(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: image.isEmpty
                                    ? Container(
                                        width: coverWidth,
                                        height: coverWidth * 1.4,
                                        color: colors.surfaceContainerHighest,
                                        child: Icon(
                                          Icons.movie_outlined,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      )
                                    : NetworkImgLayer(
                                        src: image,
                                        width: coverWidth,
                                        height: coverWidth * 1.4,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ExcludeSemantics(
                              child: IgnorePointer(child: content),
                            ),
                          ),
                          if (!largeText) ...[
                            const SizedBox(width: 8),
                            actions,
                          ],
                        ],
                      ),
                      if (largeText) ...[
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerRight, child: actions),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, {required bool wide}) {
    final colors = Theme.of(context).colorScheme;
    if (busy) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(child: LoadingIndicator(size: 24)),
      );
    }
    if (editing) {
      return IconButton.filledTonal(
        tooltip: '删除记录',
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: colors.errorContainer,
          foregroundColor: colors.onErrorContainer,
        ),
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline_rounded),
      );
    }

    final buttons = [
      IconButton.filledTonal(
        tooltip: '继续播放',
        focusNode: focusNode,
        autofocus: autofocus,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
        ),
        onPressed: onPlay,
        icon: const Icon(Icons.play_arrow_rounded),
      ),
      IconButton(
        tooltip: '更多操作',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: () => _showMoreDialog(context),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    ];
    return wide
        ? Row(mainAxisSize: MainAxisSize.min, children: buttons)
        : Column(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  Future<void> _showMoreDialog(BuildContext context) => KazumiDialog.show<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('播放记录操作'),
      content: SizedBox(
        width: 300,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('番剧详情'),
              onTap: () {
                Navigator.of(dialogContext).pop();
                onDetails();
              },
            ),
            for (final type in CollectType.values)
              ListTile(
                leading: Icon(
                  collectType == type
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                ),
                title: Text(type.label),
                onTap: onChangeCollect == null
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        onChangeCollect!(type);
                      },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('删除记录'),
              textColor: Theme.of(context).colorScheme.error,
              iconColor: Theme.of(context).colorScheme.error,
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await onDelete();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
