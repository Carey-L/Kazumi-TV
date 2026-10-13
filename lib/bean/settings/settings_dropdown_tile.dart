import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/split_list_row.dart';

/// A settings row that opens a single-choice dialog.
///
/// The dialog is pushed through [KazumiDialog] so the remote/back key closes
/// it without leaving the settings page.
class SettingsDropdownTile<T> extends StatelessWidget {
  const SettingsDropdownTile({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.leading,
    this.description,
    this.icons = const {},
    this.fallbackLabel = '',
    this.enabled = true,
  });

  final Widget title;
  final IconData? leading;
  final Widget? description;
  final T value;
  final Map<T, String> options;
  final Map<T, IconData> icons;
  final ValueChanged<T> onChanged;
  final String fallbackLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canOpen = enabled && options.isNotEmpty;
    return SettingsTile(
      leading: leading,
      title: title,
      description: description,
      enabled: canOpen,
      onPressed: (context) => KazumiDialog.show<void>(
        builder: (_) => _SettingsDropdownDialog<T>(
          title: title,
          value: value,
          options: options,
          icons: icons,
          onChanged: onChanged,
        ),
      ),
      value: Text(options[value] ?? fallbackLabel),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _SettingsDropdownDialog<T> extends StatelessWidget {
  const _SettingsDropdownDialog({
    required this.title,
    required this.value,
    required this.options,
    required this.icons,
    required this.onChanged,
  });

  final Widget title;
  final T value;
  final Map<T, String> options;
  final Map<T, IconData> icons;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: title,
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: RadioGroup<T>(
          groupValue: value,
          onChanged: (selected) {
            if (selected == null) return;
            onChanged(selected);
            KazumiDialog.dismiss(context: context);
          },
          child: SplitListGroup(
            children: [
              for (final entry in options.entries)
                SettingsTile<T>.radioTile(
                  title: Text(entry.value),
                  leading: icons[entry.key],
                  radioValue: entry.key,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => KazumiDialog.dismiss(context: context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
