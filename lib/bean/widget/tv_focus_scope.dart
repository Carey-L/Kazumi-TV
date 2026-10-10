import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Adds the activation keys commonly emitted by TV remotes and gamepads.
///
/// Directional traversal is still provided by Flutter's focus system. This
/// wrapper only translates select-style keys into the standard [ActivateIntent]
/// understood by Material controls.
class TvFocusScope extends StatelessWidget {
  const TvFocusScope({super.key, required this.child});

  final Widget child;

  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
  };

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _shortcuts,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: child,
      ),
    );
  }
}
