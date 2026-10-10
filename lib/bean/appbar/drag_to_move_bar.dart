import 'package:flutter/material.dart';

/// A widget for drag to move window.
///
/// Android TV has no window to drag, so this simply forwards its child.
/// The widget is kept so call sites stay unchanged if a movable window is
/// reintroduced on another form factor.
class DragToMoveArea extends StatelessWidget {
  const DragToMoveArea({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}