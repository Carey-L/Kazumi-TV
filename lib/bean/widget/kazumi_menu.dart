import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/platform_variant.dart';

typedef KazumiMenuBuilder =
    Widget Function(BuildContext context, VoidCallback? toggle);

/// Menus render in an overlay rather than a route, so a remote's back button
/// does not dismiss them the way it pops a page. Every open menu registers here
/// so the app-level back handler can close them first.
final Set<MenuController> _openMenus = <MenuController>{};

/// Closes every open [KazumiMenuButton] menu. Returns true if any was open.
bool dismissAllOpenMenus() {
  if (_openMenus.isEmpty) return false;
  final open = _openMenus
      .where((controller) => controller.isOpen)
      .toList(growable: false);
  _openMenus.clear();
  for (final controller in open) {
    controller.close();
  }
  return open.isNotEmpty;
}

const _menuItemStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(144, 48)),
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
  alignment: AlignmentDirectional.centerStart,
  visualDensity: VisualDensity.standard,
);

class KazumiMenuButton extends StatelessWidget {
  const KazumiMenuButton({
    super.key,
    required this.builder,
    required this.menuChildren,
    this.controller,
    this.enabled = true,
    this.animated = false,
    this.crossAxisUnconstrained = true,
    this.onOpen,
    this.onClose,
    this.style,
    this.dialogTitle,
  });

  final KazumiMenuBuilder builder;
  final List<Widget> menuChildren;
  final MenuController? controller;
  final bool enabled;

  /// Opt in only for menus that previously animated.
  final bool animated;
  final bool crossAxisUnconstrained;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final MenuStyle? style;
  final String? dialogTitle;

  bool get _usesDialog =>
      isTvBuild &&
      controller == null &&
      menuChildren.every(
        (child) => child is KazumiMenuItem || child is Divider,
      );

  Future<void> _showDialog(BuildContext context) async {
    if (!enabled ||
        menuChildren.isEmpty ||
        KazumiDialog.observer.hasKazumiDialog) {
      return;
    }
    onOpen?.call();
    try {
      await KazumiDialog.show<void>(
        context: context,
        builder: (_) => _KazumiMenuDialog(
          title: dialogTitle ?? '选择操作',
          children: menuChildren,
        ),
      );
    } finally {
      onClose?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_usesDialog) {
      return builder(
        context,
        enabled && menuChildren.isNotEmpty ? () => _showDialog(context) : null,
      );
    }
    return MenuButtonTheme(
      data: MenuButtonThemeData(
        // Submenu entries must use the same inset as ordinary menu items.
        style: _menuItemStyle.merge(MenuButtonTheme.of(context).style),
      ),
      child: Builder(
        builder: (outerContext) {
          // MenuAnchor resolves the effective controller (supplied or its own)
          // in the builder, so capture it for the open/close hooks.
          MenuController? resolved;
          return MenuAnchor(
            controller: controller,
            consumeOutsideTap: true,
            crossAxisUnconstrained: crossAxisUnconstrained,
            animated: animated && !MediaQuery.disableAnimationsOf(context),
            onOpen: () {
              final menu = resolved;
              if (menu != null && menu.isOpen) {
                _openMenus.add(menu);
              }
              onOpen?.call();
            },
            onClose: () {
              final menu = resolved;
              if (menu != null) _openMenus.remove(menu);
              onClose?.call();
            },
            style: style,
            menuChildren: menuChildren,
            builder: (context, menuController, _) {
              resolved = menuController;
              return builder(
                context,
                enabled && menuChildren.isNotEmpty
                    ? () => menuController.isOpen
                          ? menuController.close()
                          : menuController.open()
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

class KazumiMenuItem extends StatelessWidget {
  const KazumiMenuItem({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.selected,
    this.destructive = false,
    this.requestFocusOnHover = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leadingIcon;

  /// Null for actions; a bool exposes single-choice selection semantics.
  final bool? selected;
  final bool destructive;
  final bool requestFocusOnHover;

  Widget _dialogTile(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final selectedColor = selected == true ? colors.primaryContainer : null;
    final foreground = destructive
        ? colors.error
        : selected == true
        ? colors.onPrimaryContainer
        : null;
    return Material(
      color: selectedColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        enabled: enabled,
        leading: leadingIcon,
        title: Text(label),
        selected: selected == true,
        selectedColor: foreground,
        iconColor: foreground,
        trailing: selected == true ? const Icon(Icons.check_rounded) : null,
        onTap: enabled
            ? () {
                Navigator.of(context).pop();
                onPressed!();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive
        ? colors.error
        : selected == true
        ? colors.primary
        : null;
    final foregroundColor = color == null
        ? null
        : WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.disabled) ? null : color,
          );
    return MenuItemButton(
      onPressed: onPressed,
      requestFocusOnHover: requestFocusOnHover,
      style: ButtonStyle(
        foregroundColor: foregroundColor,
        iconColor: foregroundColor,
      ),
      leadingIcon: leadingIcon,
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: selected == null ? null : true,
        child: Text(label, textAlign: TextAlign.start),
      ),
    );
  }
}

class _KazumiMenuDialog extends StatelessWidget {
  const _KazumiMenuDialog({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FocusScope(
      autofocus: true,
      child: AlertDialog(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 440),
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(title),
        content: SizedBox(
          width: 392,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: children.length,
              separatorBuilder: (_, index) => children[index] is Divider
                  ? const SizedBox()
                  : const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final child = children[index];
                return child is KazumiMenuItem
                    ? child._dialogTile(context)
                    : child;
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
