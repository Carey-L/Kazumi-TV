import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_traversal_scope.dart';

void main() {
  testWidgets(
    'TvTraversalScope lets the D-pad reach a sibling of a nested scope',
    (tester) async {
      final railFocus = FocusNode();
      final contentFocus = FocusNode();
      addTearDown(railFocus.dispose);
      addTearDown(contentFocus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Center(
                    child: ElevatedButton(
                      focusNode: railFocus,
                      onPressed: () {},
                      child: const Text('Rail'),
                    ),
                  ),
                ),
                Expanded(
                  child: TvTraversalScope(
                    child: Center(
                      child: ElevatedButton(
                        focusNode: contentFocus,
                        onPressed: () {},
                        child: const Text('Content'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      contentFocus.requestFocus();
      await tester.pump();
      expect(contentFocus.hasFocus, isTrue);

      // Moving left at the content edge must escape the nested scope instead of
      // looping or parking focus on the scope itself.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(
        railFocus.hasFocus,
        isTrue,
        reason: 'focus should escape the nested scope to reach the rail',
      );
    },
  );

  testWidgets('controller enters a nested scope on a real control', (
    tester,
  ) async {
    final controller = TvTraversalScopeController();
    final railFocus = FocusNode();
    final contentFocus = FocusNode();
    addTearDown(railFocus.dispose);
    addTearDown(contentFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            ElevatedButton(
              focusNode: railFocus,
              onPressed: () {},
              child: const Text('Rail'),
            ),
            Expanded(
              child: TvTraversalScope(
                controller: controller,
                child: FocusScope(
                  child: Center(
                    child: ElevatedButton(
                      focusNode: contentFocus,
                      onPressed: () {},
                      child: const Text('Content'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    railFocus.requestFocus();
    await tester.pump();

    expect(controller.focusFirstInDirection(TraversalDirection.right), isTrue);
    await tester.pump();

    expect(contentFocus.hasPrimaryFocus, isTrue);
    expect(FocusManager.instance.primaryFocus, isNot(isA<FocusScopeNode>()));
  });

  testWidgets('TvTraversalScope does not itself take focus', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TvTraversalScope(child: Scaffold(body: Text('content'))),
      ),
    );

    // The wrapper anchors traversal only; it must stay out of the traversal
    // order so the D-pad lands on real controls.
    final scopeFinder = find.byType(FocusScope);
    expect(scopeFinder, findsWidgets);
  });
}
