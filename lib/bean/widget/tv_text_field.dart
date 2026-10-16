import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A text field tuned for a TV remote.
///
/// Focusing the field only shows the caret; the on-screen keyboard opens after
/// the confirm key is pressed, and the back key drops the caret instead of
/// leaving the page.
class TvTextField extends StatefulWidget {
  const TvTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.decoration,
    this.style,
    this.textInputAction,
    this.keyboardType,
    this.onSubmitted,
    this.onChanged,
    this.onTapOutside,
    this.textAlignVertical,
    this.maxLines = 1,
    this.minLines,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final void Function(PointerDownEvent)? onTapOutside;
  final TextAlignVertical? textAlignVertical;
  final int? maxLines;
  final int? minLines;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool autofocus;
  final bool enabled;

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  bool _editing = false;

  @override
  void dispose() {
    widget.focusNode.removeListener(_releaseWhenUnfocused);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_releaseWhenUnfocused);
  }

  void _releaseWhenUnfocused() {
    if (!mounted) return;
    if (!widget.focusNode.hasFocus && _editing) {
      setState(() => _editing = false);
      return;
    }
    setState(() {});
  }

  bool _isConfirm(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.gameButtonA;

  bool _isBack(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.browserBack;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_isBack(key)) {
      if (_editing) {
        setState(() => _editing = false);
        widget.focusNode.unfocus();
        return KeyEventResult.ignored;
      } else {
        return KeyEventResult.handled;
      }
    }
    if (_isConfirm(key) && !_editing) {
      setState(() => _editing = true);
      widget.focusNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.focusNode.hasFocus) {
          SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        }
      });
      return KeyEventResult.handled;
    }
    // While not editing, arrows move focus between items instead of being
    // swallowed by the (read-only) editable's caret handling.
    if (!_editing) {
      final direction = _arrowDirection(key);
      if (direction != null) {
        widget.focusNode.focusInDirection(direction);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  TraversalDirection? _arrowDirection(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return TraversalDirection.up;
    if (key == LogicalKeyboardKey.arrowDown) return TraversalDirection.down;
    if (key == LogicalKeyboardKey.arrowLeft) return TraversalDirection.left;
    if (key == LogicalKeyboardKey.arrowRight) return TraversalDirection.right;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        readOnly: !_editing,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        showCursor: widget.focusNode.hasFocus,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textAlignVertical: widget.textAlignVertical,
        style: widget.style,
        decoration: widget.decoration,
        onTapOutside: widget.onTapOutside,
        onChanged: widget.onChanged,
        onSubmitted: (value) {
          setState(() => _editing = false);
          widget.onSubmitted?.call(value);
        },
      ),
    );
  }
}
