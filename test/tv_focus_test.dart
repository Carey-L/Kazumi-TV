import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_focus_scope.dart';
import 'package:kazumi/pages/player/player_keyboard_shortcuts.dart';

void main() {
  testWidgets('TV select activates the focused Material control',
      (tester) async {
    var activations = 0;
    final buttonFocus = FocusNode();
    addTearDown(buttonFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TvFocusScope(
          child: ElevatedButton(
            focusNode: buttonFocus,
            onPressed: () => activations++,
            child: const Text('Play'),
          ),
        ),
      ),
    );
    buttonFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(activations, 1);
  });

  testWidgets('TV player handles select while the player scope owns focus',
      (tester) async {
    var playPauseCalls = 0;
    final playerFocus = FocusNode();
    addTearDown(playerFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: playerFocus,
          autofocus: true,
          child: PlayerKeyboardShortcuts(
            focusScopeNode: playerFocus,
            tvMode: true,
            actions: {
              'playorpause': () => playPauseCalls++,
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(playPauseCalls, 1);
  });

  testWidgets('TV player shows the control panel on down while the surface owns focus',
      (tester) async {
    var showPanelCalls = 0;
    final playerFocus = FocusNode();
    addTearDown(playerFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: playerFocus,
          autofocus: true,
          child: PlayerKeyboardShortcuts(
            focusScopeNode: playerFocus,
            tvMode: true,
            actions: {
              'showpanel': () => showPanelCalls++,
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(showPanelCalls, 1);
  });

  testWidgets('TV player yields D-pad keys to a focused child control',
      (tester) async {
    var seekCalls = 0;
    var buttonActivations = 0;
    final playerFocus = FocusNode();
    final buttonFocus = FocusNode();
    addTearDown(playerFocus.dispose);
    addTearDown(buttonFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TvFocusScope(
          child: Focus(
            focusNode: playerFocus,
            child: Column(
              children: [
                PlayerKeyboardShortcuts(
                  focusScopeNode: playerFocus,
                  tvMode: true,
                  actions: {
                    'forward': () => seekCalls++,
                    'playorpause': () => seekCalls++,
                  },
                ),
                ElevatedButton(
                  focusNode: buttonFocus,
                  onPressed: () => buttonActivations++,
                  child: const Text('Control'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    buttonFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);

    expect(seekCalls, 0);
    expect(buttonActivations, 1);
  });

  testWidgets('TV media keys remain active while a child control has focus',
      (tester) async {
    var playCalls = 0;
    final playerFocus = FocusNode();
    final buttonFocus = FocusNode();
    addTearDown(playerFocus.dispose);
    addTearDown(buttonFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: playerFocus,
          child: Column(
            children: [
              PlayerKeyboardShortcuts(
                focusScopeNode: playerFocus,
                tvMode: true,
                actions: {
                  'play': () => playCalls++,
                },
              ),
              ElevatedButton(
                focusNode: buttonFocus,
                onPressed: () {},
                child: const Text('Control'),
              ),
            ],
          ),
        ),
      ),
    );
    buttonFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
    expect(playCalls, 1);
  });
}
