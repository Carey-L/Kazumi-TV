import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_focus_highlight.dart';

void main() {
  testWidgets('TV card observes focus held by a descendant', (tester) async {
    final buttonFocus = FocusNode();
    addTearDown(buttonFocus.dispose);
    var highlighted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFocusHighlight(
          enabled: true,
          onFocusChange: (value) => highlighted = value,
          child: ElevatedButton(
            focusNode: buttonFocus,
            onPressed: () {},
            child: const Text('Card'),
          ),
        ),
      ),
    );

    buttonFocus.requestFocus();
    await tester.pump();

    expect(highlighted, isTrue);
  });

  testWidgets('focused TV card is automatically scrolled into view',
      (tester) async {
    final controller = ScrollController();
    final buttonFocus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(buttonFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 120,
          child: ListView(
            controller: controller,
            children: [
              const SizedBox(height: 600),
              TvFocusHighlight(
                enabled: true,
                child: ElevatedButton(
                  focusNode: buttonFocus,
                  onPressed: () {},
                  child: const Text('Offscreen card'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    buttonFocus.requestFocus();
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
  });

  testWidgets('mobile card bypasses TV focus treatment', (tester) async {
    final buttonFocus = FocusNode();
    addTearDown(buttonFocus.dispose);
    var highlighted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFocusHighlight(
          enabled: false,
          onFocusChange: (value) => highlighted = value,
          child: ElevatedButton(
            focusNode: buttonFocus,
            onPressed: () {},
            child: const Text('Mobile card'),
          ),
        ),
      ),
    );
    buttonFocus.requestFocus();
    await tester.pump();

    expect(highlighted, isFalse);
    expect(find.text('Mobile card'), findsOneWidget);
  });
}
