// Documentation capture fixture. Drives the real example; no library changes.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';
import 'package:theme_reveal_kit_example/app.dart';
import 'package:theme_reveal_kit_example/example_storage.dart';
import 'package:theme_reveal_kit_example/reveal_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => binding.platformDispatcher.semanticsEnabledTestValue = true);
  tearDownAll(binding.platformDispatcher.clearSemanticsEnabledTestValue);
  testWidgets(
    'record real macOS example flows for the README',
    (tester) async {
      const short = bool.fromEnvironment('MEDIA_SHORT');
      final suffix = const bool.fromEnvironment('MEDIA_RESTORE')
          ? '-restore'
          : short
          ? '-short'
          : '-loop';
      final output =
          '${Directory.systemTemp.path}/theme-reveal-documentation$suffix';
      final ipc = Directory(output);
      if (ipc.existsSync()) ipc.deleteSync(recursive: true);
      ipc.createSync(recursive: true);
      debugPrint('MEDIA_DIR=$output');
      final preferences = RevealPreferences();
      final storage = ExampleThemeStorage(
        key: 'theme_reveal_kit.documentation.mode',
      );
      if (!const bool.fromEnvironment('MEDIA_RESTORE')) {
        await storage.write(ThemeMode.dark);
      }
      final controller = await RevealThemeController.create(
        defaultMode: ThemeMode.light,
        storage: storage,
      );
      await tester.pumpWidget(
        RevealExampleApp(
          controller: controller,
          preferences: preferences,
          storage: storage,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      File('$output/ready').writeAsStringSync(
        'Bring the example window to the foreground; then create start.',
      );
      debugPrint('MEDIA READY: waiting for foreground and start signal');
      final deadline = DateTime.now().add(const Duration(minutes: 4));
      while (!File('$output/start').existsSync()) {
        if (DateTime.now().isAfter(deadline)) fail('No media start signal');
        await tester.pump(const Duration(milliseconds: 100));
      }
      Future<void> pause(int milliseconds) async {
        final until = DateTime.now().add(Duration(milliseconds: milliseconds));
        while (DateTime.now().isBefore(until)) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      void foreground() {
        expect(
          binding.lifecycleState,
          AppLifecycleState.resumed,
          reason: 'Recording requires the real app in the foreground',
        );
      }

      var sequence = 0;
      Future<File> request(String name, String kind, int seconds) async {
        foreground();
        final id = ++sequence;
        File('$output/request.json').writeAsStringSync(
          jsonEncode({
            'id': id,
            'name': name,
            'kind': kind,
            'seconds': seconds,
          }),
        );
        final started = File('$output/$id.started');
        while (!started.existsSync()) {
          await pause(25);
        }
        return File('$output/$id.finished');
      }

      Future<void> record(
        String name,
        int seconds,
        Future<void> Function() flow,
      ) async {
        if (short && !['shapes', 'strategies'].contains(name)) return;
        debugPrint('MEDIA recording $name');
        final finished = await request(name, 'video', seconds);
        await pause(1000);
        await flow();
        while (!finished.existsSync()) {
          await pause(25);
        }
        expect(finished.readAsStringSync(), '0');
        foreground();
      }

      Future<void> toggle() async {
        foreground();
        await tester.tap(find.byKey(const ValueKey('settings-theme-button')));
        await tester.pumpAndSettle();
        await pause(350);
      }

      Future<void> screenshot(String name) async {
        if (short) return;
        final finished = await request(name, 'image', 0);
        while (!finished.existsSync()) {
          await pause(25);
        }
        expect(finished.readAsStringSync(), '0');
      }

      Future<void> select(String id, String value) async {
        final field = find.byKey(ValueKey(id));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pumpAndSettle();
        final popup = find.byType(Scrollable).last;
        tester.state<ScrollableState>(popup).position.jumpTo(0);
        await tester.pump();
        final item = find.descendant(of: popup, matching: find.text(value));
        await tester.scrollUntilVisible(item, 140, scrollable: popup);
        await tester.ensureVisible(item);
        await tester.pumpAndSettle();
        await tester.tap(item);
        await tester.pumpAndSettle();
      }

      if (const bool.fromEnvironment('MEDIA_RESTORE')) {
        expect(controller.themeMode, ThemeMode.light);
        await record('persistence_after', 3, () => pause(1000));
      } else {
        await screenshot('settings_tab');
        await record('hero', 5, () async {
          await toggle();
          await pause(500);
          await toggle();
        });
        preferences.selectShape('Triangle');
        await tester.pumpAndSettle();
        await record('shapes', 10, () async {
          for (final name in [
            'Triangle',
            'Star',
            'Heart',
            'Rounded rectangle',
          ]) {
            preferences.selectShape(name);
            await tester.pumpAndSettle();
            await toggle();
          }
          preferences.selectShape('Triangle');
          await tester.pumpAndSettle();
        });
        preferences.selectShape('SVG');
        await tester.pumpAndSettle();
        await record('logo_svg', 5, () async {
          await toggle();
          await pause(450);
          await toggle();
        });
        preferences.selectShape('PNG');
        await tester.pumpAndSettle();
        await record('logo_png', 5, () async {
          await toggle();
          await pause(450);
          await toggle();
        });
        preferences.selectShape('Star');
        preferences.selectStrategy('Preserve shape');
        await tester.pumpAndSettle();
        await record('strategies', 10, () async {
          for (final name in [
            'Preserve shape',
            'Morph to fullscreen',
            'Expand and dissolve',
          ]) {
            preferences.selectStrategy(name);
            await tester.pumpAndSettle();
            await toggle();
          }
          // Return to the initial mode for a visually continuous loop.
          preferences.selectStrategy('Preserve shape');
          await tester.pumpAndSettle();
          await toggle();
        });
        if (short) {
          await tester.pumpWidget(const SizedBox.shrink());
          await controller.flush();
          controller.dispose();
          preferences.dispose();
          File('$output/finished').writeAsStringSync('done');
          return;
        }
        preferences.reset();
        controller.setThemeMode(ThemeMode.dark);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Playground').last);
        await tester.pumpAndSettle();
        await record('playground', 12, () async {
          final scroll = find
              .descendant(
                of: find.byKey(const PageStorageKey('playground-scroll')),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('duration')),
            250,
            scrollable: scroll,
          );
          await tester.ensureVisible(find.byKey(const ValueKey('duration')));
          await tester.pumpAndSettle();
          await tester.tapAt(
            tester.getCenter(find.byKey(const ValueKey('duration'))) +
                const Offset(60, 0),
          );
          await tester.pumpAndSettle();
          await select('curve', 'Linear');
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('origin')),
            250,
            scrollable: scroll,
          );
          await select('origin', 'Screen center');
          await tester.tap(
            find.byKey(const ValueKey('playground-theme-button')),
          );
          await tester.pumpAndSettle();
          await pause(300);
          await tester.tap(
            find.byKey(const ValueKey('playground-theme-button')),
          );
          await tester.pumpAndSettle();
          preferences.reset();
          tester.state<ScrollableState>(scroll).position.jumpTo(0);
          await tester.pumpAndSettle();
        });
        await tester.tap(find.text('Home').last);
        controller.setThemeMode(ThemeMode.light);
        await tester.pumpAndSettle();
        await screenshot('home_light');
        controller.setThemeMode(ThemeMode.dark);
        await tester.pumpAndSettle();
        await screenshot('home_dark');
        await tester.tap(find.text('Settings').last);
        preferences.reset();
        await tester.pumpAndSettle();
        await record('persistence_before', 4, () async {
          await toggle();
          await controller.flush();
        });
        expect(controller.themeMode, ThemeMode.light);
        // A second OS process is required for persistence_after; this test exits.
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.flush();
      controller.dispose();
      preferences.dispose();
      File('$output/finished').writeAsStringSync('done');
    },
    timeout: const Timeout(Duration(minutes: 8)),
    skip: !const bool.fromEnvironment('RECORD_MEDIA'),
  );
}
