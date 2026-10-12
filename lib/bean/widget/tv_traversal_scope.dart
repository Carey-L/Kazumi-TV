import 'package:flutter/material.dart';

/// Lets a D-pad escape a nested [Navigator] back into its enclosing shell.
///
/// Flutter 3.47 routes directional traversal through
/// `FocusNode.focusInDirection`, which only considers the focused node's
/// nearest [FocusScopeNode]. A nested navigator is such a scope, so without
/// this wrapper the side rails of a TV layout shell are unreachable: focus
/// wraps inside the outlet instead of crossing the boundary.
///
/// Wrap the outlet itself, not individual controls, so every route it hosts
/// shares one configured scope.
class TvTraversalScope extends StatefulWidget {
  const TvTraversalScope({super.key, required this.child, this.controller});

  final Widget child;
  final TvTraversalScopeController? controller;

  @override
  State<TvTraversalScope> createState() => _TvTraversalScopeState();
}

class _TvTraversalScopeState extends State<TvTraversalScope> {
  final FocusScopeNode _scope = FocusScopeNode(
    debugLabel: 'TvTraversalScope',
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant TvTraversalScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller?._detach(this);
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _scope.dispose();
    super.dispose();
  }

  bool focusFirstInDirection(TraversalDirection direction) {
    FocusNode current = _scope;
    final visitedScopes = <FocusScopeNode>{};

    // A Navigator adds another FocusScope below this one. Resolve scopes until
    // traversal reaches a real control; requesting a previously unused scope
    // directly would leave primary focus parked on the scope itself.
    while (current is FocusScopeNode && visitedScopes.add(current)) {
      final context = current.context;
      if (context == null) return false;
      final candidate = FocusTraversalGroup.of(
        context,
      ).findFirstFocusInDirection(current, direction);
      if (candidate == null || identical(candidate, current)) return false;
      current = candidate;
    }

    if (current is FocusScopeNode || !current.canRequestFocus) return false;
    current.requestFocus();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _scope,
      // Only `skipTraversal` is set: it keeps this anchor out of the traversal
      // order without affecting descendants. `canRequestFocus: false` must NOT
      // be used here — a FocusScopeNode with it reports
      // descendantsAreFocusable == false, and every descendant's
      // canRequestFocus then becomes false, leaving the whole pane dead.
      skipTraversal: true,
      child: widget.child,
    );
  }
}

/// Moves focus into a [TvTraversalScope] from a sibling such as a TV side rail.
class TvTraversalScopeController {
  _TvTraversalScopeState? _state;

  bool focusFirstInDirection(TraversalDirection direction) =>
      _state?.focusFirstInDirection(direction) ?? false;

  void _attach(_TvTraversalScopeState state) => _state = state;

  void _detach(_TvTraversalScopeState state) {
    if (identical(_state, state)) _state = null;
  }
}
