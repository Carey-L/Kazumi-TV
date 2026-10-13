import 'package:flutter/material.dart';

import 'package:kazumi/utils/platform_variant.dart';
import 'package:kazumi/utils/theme.dart';

/// Gives TV cards a consistent ten-foot focus treatment.
///
/// The wrapper does not participate in focus traversal itself. Instead, it
/// observes focus held by any interactive descendant, so nested controls (for
/// example a card menu button) keep the whole card visible and highlighted.
class TvFocusHighlight extends StatefulWidget {
  const TvFocusHighlight({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.enabled = isTvBuild,
    this.scale = 1.025,
    this.onFocusChange,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final bool enabled;
  final double scale;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<TvFocusHighlight> createState() => _TvFocusHighlightState();
}

class _TvFocusHighlightState extends State<TvFocusHighlight> {
  static const _animationDuration = Duration(milliseconds: 140);
  bool _hasFocus = false;

  void _handleFocusChange(bool hasFocus) {
    if (_hasFocus == hasFocus) return;
    setState(() => _hasFocus = hasFocus);
    widget.onFocusChange?.call(hasFocus);
    if (!hasFocus) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasFocus) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: _animationDuration,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _handleFocusChange,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _hasFocus ? 1 : 0),
        duration: _animationDuration,
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) => Transform.scale(
          scale: 1 + (widget.scale - 1) * progress,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              border: Border.all(
                color: kTvFocusBorderColor.withValues(alpha: progress),
                width: 4,
              ),
            ),
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
