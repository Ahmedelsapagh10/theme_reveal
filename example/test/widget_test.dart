import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';
import 'package:theme_reveal_kit_example/app.dart';

void main() {
  testWidgets('compact toggle lives in Settings; tabs preserve state', (
    tester,
  ) async {
    final controller = RevealThemeController(storage: MemoryThemeStorage());
    await tester.pumpWidget(RevealExampleApp(controller: controller));
    expect(find.byType(RevealThemeButton).hitTestable(), findsNothing);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.byType(RevealThemeButton).hitTestable(), findsOneWidget);
    expect(find.text('Current mode: system'), findsOneWidget);
    expect(tester.getSize(find.byType(RevealThemeButton)), const Size(48, 48));
    await tester.tap(find.byKey(const ValueKey('shape-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Star').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('strategy-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morph to fullscreen').last);
    await tester.pumpAndSettle();
    final button = tester.widget<RevealThemeButton>(
      find.byType(RevealThemeButton),
    );
    expect(
      button.revealShape.resolve(),
      same(const RevealShape.star().resolve()),
    );
    expect(
      button.animation.completionStrategy,
      RevealCompletionStrategy.morphToFullscreen,
    );
    final navigator = tester.state(find.byType(Navigator));
    controller.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(Navigator)), same(navigator));
    expect(find.text('Current mode: dark'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.flush();
    controller.dispose();
  });
}
