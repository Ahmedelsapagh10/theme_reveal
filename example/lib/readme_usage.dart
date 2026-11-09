// dart format width=100

// snippet:imports:file
// Add these imports to every screen using the recipes below.
import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';
// end:imports
export 'readme_external_app.dart' show ExternalThemeApp;
export 'readme_settings.dart' show SettingsPage;
export 'readme_storage.dart' show AppThemeStorage;
export 'readme_managed.dart' show main;
export 'readme_notifier.dart' show NotifierThemeApp;

Widget externalButton(VoidCallback changeTheme) =>
    // snippet:external_button:expression
    // Put this button below ThemeRevealViewport in your home screen.
    // YOUR CODE: changeTheme updates your existing theme state.
    Builder(
      builder: (buttonContext) => FilledButton(
        onPressed: () => ThemeRevealViewport.of(
          buttonContext,
        ).reveal(from: buttonContext, onThemeChange: changeTheme),
        child: const Text('Change theme'),
      ),
    );
// end:external_button

Widget appBarPage(RevealThemeController controller) =>
    // snippet:appbar:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [RevealThemeButton(controller: controller)],
      ),
      body: const Center(child: Text('Welcome')),
    );
// end:appbar

Widget drawerPage(RevealThemeController controller) =>
    // snippet:drawer:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    Scaffold(
      appBar: AppBar(title: const Text('Home')),
      drawer: Drawer(
        child: SafeArea(
          child: ListTile(
            title: const Text('Appearance'),
            trailing: RevealThemeButton(controller: controller),
          ),
        ),
      ),
      body: const Center(child: Text('Open the drawer')),
    );
// end:drawer

Widget floatingPage(RevealThemeController controller) =>
    // snippet:floating:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    Scaffold(
      body: const Center(child: Text('Home')),
      floatingActionButton: RevealThemeButton(controller: controller),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
// end:floating

Widget customButton(RevealThemeController controller) =>
    // snippet:trigger:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    RevealThemeTrigger(
      controller: controller,
      semanticLabel: 'Change appearance',
      child: const Chip(avatar: Icon(Icons.contrast), label: Text('Appearance')),
    );
// end:trigger

Widget circleButton(RevealThemeController controller) =>
    // snippet:circle:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    RevealThemeButton(controller: controller, revealShape: const RevealShape.circle());
// end:circle

Widget triangleButton(RevealThemeController controller) =>
    // snippet:triangle:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    RevealThemeButton(controller: controller, revealShape: const RevealShape.triangle());
// end:triangle

Widget starButton(RevealThemeController controller) =>
    // snippet:star:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    RevealThemeButton(
      controller: controller,
      revealShape: const RevealShape.star(points: 5, innerRadius: .45),
    );
// end:star

Widget heartButton(RevealThemeController controller) =>
    // snippet:heart:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    RevealThemeButton(controller: controller, revealShape: const RevealShape.heart());
// end:heart

Widget roundedButton(RevealThemeController controller) =>
    // snippet:rounded:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    RevealThemeButton(
      controller: controller,
      revealShape: const RevealShape.roundedRectangle(aspectRatio: 1.5, cornerRadius: .16),
    );
// end:rounded

Widget iconButton(RevealThemeController controller) =>
    // snippet:icon:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    RevealThemeButton(controller: controller, revealShape: const RevealShape.icon(Icons.favorite));
// end:icon

Widget svgButton(RevealThemeController controller) =>
    // snippet:svg:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    RevealThemeButton(
      controller: controller,
      revealShape: const RevealShape.svgAsset('assets/logo.svg'),
    );
// end:svg

Widget pngButton(RevealThemeController controller) =>
    // snippet:png:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    RevealThemeButton(
      controller: controller,
      revealShape: const RevealShape.pngAsset('assets/logo.png', alphaThreshold: 32, trim: true),
    );
// end:png

Widget jsonButton(RevealThemeController controller) =>
    // snippet:json:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    RevealThemeButton(
      controller: controller,
      revealShape: const RevealShape.jsonAsset('assets/custom_shape.json'),
    );
// end:json

Widget pathButton(RevealThemeController controller) =>
    // snippet:path:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    RevealThemeButton(
      controller: controller,
      revealShape: RevealShape.customPath(
        builder: (size) => Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(0, size.height / 2)
          ..close(),
      ),
    );
// end:path

Widget animatedButton(RevealThemeController controller) =>
    // snippet:config:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    RevealThemeButton(
      controller: controller,
      revealShape: const RevealShape.star(),
      animation: const RevealAnimationConfig(
        duration: Duration(milliseconds: 900),
        curve: Curves.easeInOutCubic,
        origin: RevealOrigin.gesture(),
        completionStrategy: RevealCompletionStrategy.expandAndDissolve,
        reducedMotion: RevealReducedMotion.system,
      ),
    );
// end:config

Widget themeSelector(RevealThemeController controller) =>
    // snippet:selector:expression
    // Put this in your screen below the managed MaterialApp.
    // controller is the one you created in main().
    ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ButtonSegment(value: ThemeMode.system, label: Text('System')),
        ],
        selected: {controller.themeMode},
        onSelectionChanged: (selection) => ThemeRevealViewport.of(
          context,
        ).setThemeMode(controller, selection.single, from: context),
      ),
    );
// end:selector

void setExample(BuildContext context, RevealThemeController controller) {
  // snippet:set:statements
  // Call from onPressed with a context below the viewport. Select dark mode immediately.
  controller.setThemeMode(ThemeMode.dark);
  // end:set
}

void toggleExample(BuildContext context, RevealThemeController controller) {
  // snippet:toggle:statements
  // Call from onPressed with a context below the viewport. Switch light/dark immediately.
  controller.toggleTheme();
  // end:toggle
}

void resetExample(BuildContext context, RevealThemeController controller) {
  // snippet:reset:statements
  // Call from onPressed with a context below the viewport. Follow device brightness immediately.
  controller.resetToSystem();
  // end:reset
}

void revealSetExample(BuildContext context, RevealThemeController controller) {
  // snippet:reveal_set:statements
  // Call from onPressed with a context below the viewport. Reveal dark mode.
  ThemeRevealViewport.of(context).setThemeMode(controller, ThemeMode.dark, from: context);
  // end:reveal_set
}

void revealToggleExample(BuildContext context, RevealThemeController controller) {
  // snippet:reveal_toggle:statements
  // Call from onPressed with a context below the viewport. Reveal the opposite light/dark mode.
  ThemeRevealViewport.of(context).toggleTheme(controller, from: context);
  // end:reveal_toggle
}

void revealResetExample(BuildContext context, RevealThemeController controller) {
  // snippet:reveal_reset:statements
  // Call from onPressed with a context below the viewport. Reveal the system theme and follow device brightness.
  ThemeRevealViewport.of(context).setThemeMode(controller, ThemeMode.system, from: context);
  // end:reveal_reset
}

void centerExample(BuildContext context, RevealThemeController controller) {
  // snippet:center:statements
  // Call from onPressed below the viewport; reveal from the screen center.
  ThemeRevealViewport.of(context).toggleTheme(
    controller,
    from: context,
    config: const RevealAnimationConfig(origin: RevealOrigin.screenCenter()),
  );
  // end:center
}

Widget keyAnchor(GlobalKey anchor) =>
    // snippet:key_anchor:expression
    // Put this widget in your screen; keep final anchor = GlobalKey() in its State.
    Text('Reveal starts here', key: anchor);
// end:key_anchor

void keyExample(BuildContext context, RevealThemeController controller, GlobalKey anchor) {
  // snippet:key_call:statements
  // Call from onPressed; anchor is the GlobalKey attached to the widget above.
  ThemeRevealViewport.of(context).toggleTheme(
    controller,
    from: context,
    config: RevealAnimationConfig(origin: RevealOrigin.fromKey(anchor)),
  );
  // end:key_call
}

Future<RevealThemeController> restoreTheme(ThemeStorage storage) async {
  // snippet:restore:statements
  // 2) In main(), initialize bindings and await this before runApp.
  // YOUR CODE: pass AppThemeStorage(load: yourRead, save: yourWrite) as storage.
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await RevealThemeController.create(
    storage: storage,
    defaultMode: ThemeMode.system,
    onPersistenceError: (error, stack) => debugPrint('Theme storage: $error'),
  );
  // end:restore
  return controller;
}

Future<void> saveDarkTheme(RevealThemeController controller) async {
  // snippet:persistence:statements
  // In an async callback, save dark mode and wait for the write to finish.
  controller.setThemeMode(ThemeMode.dark);
  await controller.flush();
  if (controller.lastPersistenceError != null) {
    debugPrint('Theme preference could not be saved');
  }
  // end:persistence
}

Future<void> refreshTheme(RevealThemeController controller) async {
  // snippet:reload:statements
  // Read the preference again after another part of your app changes storage.
  await controller.reloadFromStorage();
  // end:reload
}
