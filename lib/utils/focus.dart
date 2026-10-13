import 'package:flutter/widgets.dart';

/// True when the primary focus is a text input (a `TextField`'s focus node).
bool isTextInputFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Clears focus from a text input when one holds it.
///
/// Returns true when the back press was consumed, so callers can let the
/// first back press drop the keyboard/caret before acting on the route.
bool unfocusTextInputOnBack() {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null || !isTextInputFocused()) return false;
  focus.unfocus();
  return true;
}
