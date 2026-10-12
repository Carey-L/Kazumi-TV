import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/utils/platform_variant.dart';
import 'package:kazumi/bean/widget/tv_traversal_scope.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key, required this.location});

  final String location;

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class _ScaffoldMenu extends State<ScaffoldMenu> with RouteAware {
  final _outletKey = GlobalKey<RouterOutletState>();
  final FocusNode _railFocus = FocusNode(debugLabel: 'MenuRail');
  final FocusNode _railEntryFocus = FocusNode(debugLabel: 'MenuRailEntry');
  final FocusNode _contentFocus = FocusNode(debugLabel: 'MenuContent');
  final TvTraversalScopeController _contentTraversal =
      TvTraversalScopeController();
  late int _selectedIndex = menu.indexForPath(widget.location);
  DateTime? _lastExitPromptAt;

  /// The shell sits at the bottom of the root stack and stays mounted while
  /// other pages cover it, so it publishes that state for its subtree.
  bool _isCovered = false;

  @override
  void didUpdateWidget(covariant ScaffoldMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _selectedIndex = menu.indexForPath(widget.location);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      rootRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    rootRouteObserver.unsubscribe(this);
    _railFocus.dispose();
    _railEntryFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  void didPushNext() => _setCovered(true);

  @override
  void didPopNext() => _setCovered(false);

  void _setCovered(bool value) {
    if (!mounted || _isCovered == value) {
      return;
    }
    setState(() => _isCovered = value);
  }

  void _selectDestination(int index) {
    _lastExitPromptAt = null;
    if (index == _selectedIndex) {
      return;
    }
    final outlet = _outletKey.currentState;
    if (outlet == null) return;
    outlet.navigate('/tab${menu.getPath(index)}/');
    setState(() => _selectedIndex = index);
  }

  void _handleSystemBack(BuildContext context) {
    if (dismissAllOpenMenus()) {
      _lastExitPromptAt = null;
      return;
    }

    if (_outletKey.currentState?.maybePop() ?? false) {
      _lastExitPromptAt = null;
      return;
    }

    if (_selectedIndex != 0) {
      _selectDestination(0);
      return;
    }

    final now = DateTime.now();
    final lastPromptAt = _lastExitPromptAt;
    if (lastPromptAt == null ||
        now.difference(lastPromptAt) > const Duration(seconds: 2)) {
      _lastExitPromptAt = now;
      KazumiDialog.showToast(message: '再按一次退出应用', context: context);
      return;
    }

    _lastExitPromptAt = null;
    SystemNavigator.pop();
  }

  /// Moves focus off the rail and into the content pane. Traversal cannot do
  /// this on its own: the rail lives in the shell scope while the content sits
  /// in the outlet's nested scope.
  KeyEventResult _handleRailKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    final moved = _focusContentPane();
    return moved ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  /// Focuses the left-most traversable control in the content pane.
  bool _focusContentPane() =>
      _contentTraversal.focusFirstInDirection(TraversalDirection.right);

  /// Traverses within the pane first, then returns to the rail at its left
  /// edge. A nested Navigator can otherwise consume the edge and never expose
  /// the shell's navigation controls.
  KeyEventResult _handleContentKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || !primary.ancestors.contains(_contentFocus)) {
      return KeyEventResult.ignored;
    }
    // Nested app-bar controls (for example the recommendation category
    // selector) can report a successful left traversal by looping inside their
    // own scope. Detect the pane's actual left edge before delegating so that
    // the D-pad always returns to the navigation rail from its first column.
    if (!_hasFocusableNodeToLeftOf(primary)) {
      _railEntryFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (primary.focusInDirection(TraversalDirection.left)) {
      return KeyEventResult.handled;
    }
    _railEntryFocus.requestFocus();
    return KeyEventResult.handled;
  }

  bool _hasFocusableNodeToLeftOf(FocusNode primary) {
    final primaryRect = primary.rect;
    return _contentFocus.traversalDescendants.any(
      (node) =>
          node is! FocusScopeNode &&
          node != primary &&
          node.context != null &&
          node.rect.center.dx < primaryRect.center.dx,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RouteVisibility(
      isCovered: _isCovered,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _handleSystemBack(context);
          }
        },
        child: OrientationBuilder(
          builder: (context, orientation) {
            return orientation == Orientation.portrait
                ? _bottomMenu(context, _selectedIndex)
                : _sideMenu(context, _selectedIndex);
          },
        ),
      ),
    );
  }

  Widget _outlet(BuildContext context, {BorderRadius? borderRadius}) {
    Widget child = NotificationListener<NavigationNotification>(
      // A non-poppable outlet must not override the shell's PopScope state.
      onNotification: (notification) => !notification.canHandlePop,
      // The outlet nests its own Navigator, whose focus scope would otherwise
      // trap the D-pad away from the side rail.
      child: TvTraversalScope(
        controller: _contentTraversal,
        child: RouterOutlet(key: _outletKey),
      ),
    );
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius, child: child);
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }

  Widget _bottomMenu(BuildContext context, int selectedIndex) {
    return Scaffold(
      body: _outlet(context),
      bottomNavigationBar: NavigationBar(
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: '推荐',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.timeline),
            icon: Icon(Icons.timeline_outlined),
            label: '时间表',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.favorite),
            icon: Icon(Icons.favorite_outlined),
            label: '追番',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.settings),
            icon: Icon(Icons.settings),
            label: '我的',
          ),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: _selectDestination,
      ),
    );
  }

  Widget _sideMenu(BuildContext context, int selectedIndex) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(16),
      bottomLeft: Radius.circular(16),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          Focus(
            focusNode: _railFocus,
            // Pure key-event interceptor: it must not take focus itself or sit
            // in the traversal order between the rail's own destinations.
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (node, event) => _handleRailKey(event),
            child: EmbeddedNativeControlArea(
              child: NavigationRail(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                groupAlignment: 1,
                leading: FloatingActionButton(
                  focusNode: _railEntryFocus,
                  autofocus: isTvBuild,
                  elevation: 0,
                  heroTag: null,
                  onPressed: () => context.pushNamed('/search/'),
                  child: const Icon(Icons.search),
                ),
                labelType: NavigationRailLabelType.selected,
                destinations: const <NavigationRailDestination>[
                  NavigationRailDestination(
                    selectedIcon: Icon(Icons.home),
                    icon: Icon(Icons.home_outlined),
                    label: Text('推荐'),
                  ),
                  NavigationRailDestination(
                    selectedIcon: Icon(Icons.timeline),
                    icon: Icon(Icons.timeline_outlined),
                    label: Text('时间表'),
                  ),
                  NavigationRailDestination(
                    selectedIcon: Icon(Icons.favorite),
                    icon: Icon(Icons.favorite_border),
                    label: Text('追番'),
                  ),
                  NavigationRailDestination(
                    selectedIcon: Icon(Icons.settings),
                    icon: Icon(Icons.settings_outlined),
                    label: Text('我的'),
                  ),
                ],
                selectedIndex: selectedIndex,
                onDestinationSelected: _selectDestination,
              ),
            ),
          ),
          Expanded(
            child: Focus(
              focusNode: _contentFocus,
              // This is an event boundary only; child controls remain in the
              // traversal order and retain their own focus.
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: (node, event) => _handleContentKey(event),
              child: _outlet(context, borderRadius: borderRadius),
            ),
          ),
        ],
      ),
    );
  }
}
