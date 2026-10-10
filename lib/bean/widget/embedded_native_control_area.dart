import 'package:flutter/material.dart';

/// Wraps content to avoid native window controls on platforms that draw them
/// over the Flutter view. Android draws no such controls, so this is a
/// passthrough that keeps call sites free of platform checks.
class EmbeddedNativeControlArea extends StatelessWidget {
  const EmbeddedNativeControlArea({
    super.key,
    this.requireOffset = true,
    required this.child,
  });

  final Widget child;
  final bool requireOffset;

  @override
  Widget build(BuildContext context) => child;
}