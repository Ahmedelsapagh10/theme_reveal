import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

void main() {
  testWidgets(
    'default button, icon switch, press scale, tooltip, instant fallback',
    (tester) async {
      final controller = RevealThemeController(
        defaultMode: ThemeMode.dark,
        storage: MemoryThemeStorage(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: RevealThemeButton(controller: controller)),
          ),
        ),
      );
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
      expect(
        tester.getSize(find.byType(RevealThemeButton)),
        const Size(48, 48),
      );
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'Switch to light theme',
      );
      final pointer = await tester.startGesture(
        tester.getCenter(find.byType(RevealThemeButton)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        .92,
      );
      await pointer.up();
      await tester.pumpAndSettle();
      expect(controller.themeMode, ThemeMode.light);
      expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.flush();
      controller.dispose();
    },
  );

  testWidgets('semantics, keyboard Enter/Space, RTL and disabled trigger', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = RevealThemeController(
      defaultMode: ThemeMode.light,
      storage: MemoryThemeStorage(),
    );
    Widget app(bool enabled) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: RevealThemeTrigger(
            controller: controller,
            enabled: enabled,
            semanticLabel: 'Change appearance',
            child: const Text('Custom theme control'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    expect(
      tester.getSemantics(find.byType(RevealThemeTrigger)),
      matchesSemantics(
        label: 'Change appearance',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    final focusable = find.descendant(
      of: find.byType(RevealThemeTrigger),
      matching: find.byType(FocusableActionDetector),
    );
    final focus = Focus.of(
      tester.element(
        find
            .descendant(of: focusable, matching: find.byType(GestureDetector))
            .first,
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.dark);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.light);
    await tester.pumpWidget(app(false));
    await tester.tap(find.byType(RevealThemeTrigger));
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.light);
    expect(
      tester.getSemantics(find.byType(RevealThemeTrigger)),
      matchesSemantics(
        label: 'Change appearance',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.flush();
    controller.dispose();
    semantics.dispose();
  });

  testWidgets('custom styles and automatic theme-aware colors', (tester) async {
    final controller = RevealThemeController(storage: MemoryThemeStorage());
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.green),
        home: Scaffold(
          body: Row(
            children: [
              RevealThemeButton(controller: controller),
              RevealThemeButton(
                controller: controller,
                style: const RevealButtonStyle(
                  size: 56,
                  iconSize: 30,
                  foregroundColor: Colors.red,
                  backgroundColor: Colors.yellow,
                  darkIcon: Icons.nightlight,
                  lightIcon: Icons.wb_sunny,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    final context = tester.element(find.byType(RevealThemeButton).first);
    expect(icons.first.color, Theme.of(context).colorScheme.onPrimaryContainer);
    expect(icons.last.color, Colors.red);
    expect(icons.last.size, 30);
    expect(
      tester.getSize(find.byType(RevealThemeButton).last),
      const Size(56, 56),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'managed settings disable only implicit theme interpolation and preserve Navigator',
    (tester) async {
      final controller = RevealThemeController(storage: MemoryThemeStorage());
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        RevealThemeBuilder(
          controller: controller,
          builder: (context, settings) => MaterialApp(
            navigatorKey: navigatorKey,
            themeMode: settings.themeMode,
            themeAnimationDuration: settings.themeAnimationDuration,
            builder: settings.builder,
            home: const Scaffold(body: Text('Home')),
          ),
        ),
      );
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .themeAnimationDuration,
        Duration.zero,
      );
      final navigator = navigatorKey.currentState;
      navigator!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Detail')),
        ),
      );
      await tester.pumpAndSettle();
      controller.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(navigatorKey.currentState, same(navigator));
      expect(find.text('Detail'), findsOneWidget);
      final viewport = tester.state<ThemeRevealViewportState>(
        find.byType(ThemeRevealViewport),
      );
      final changed = viewport.setThemeMode(
        controller,
        ThemeMode.light,
        config: const RevealAnimationConfig(enabled: false),
      );
      await tester.pumpAndSettle();
      expect(await changed, isTrue);
      expect(find.text('Detail'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.flush();
      controller.dispose();
    },
  );
}
