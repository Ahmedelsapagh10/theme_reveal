// Additional widget and persistence examples.
// snippet:quick_start
import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await RevealThemeController.create();
  runApp(QuickStartApp(controller: controller));
}

class QuickStartApp extends StatefulWidget {
  const QuickStartApp({super.key, required this.controller});
  final RevealThemeController controller;

  @override
  State<QuickStartApp> createState() => _QuickStartAppState();
}

class _QuickStartAppState extends State<QuickStartApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RevealThemeBuilder(
    controller: widget.controller,
    onError: (error, stack) => debugPrint('Reveal fallback: $error'),
    builder: (context, settings) => MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      themeMode: settings.themeMode,
      themeAnimationDuration: settings.themeAnimationDuration,
      builder: settings.builder,
      home: Scaffold(
        appBar: AppBar(title: const Text('Theme Reveal Kit')),
        body: Center(child: RevealThemeButton(controller: widget.controller)),
      ),
    ),
  );
}
// end:quick_start

// snippet:persistence
Future<RevealThemeController> restoreSavedTheme() =>
    RevealThemeController.create(
      defaultMode: ThemeMode.system,
      storage: SharedPrefsThemeStorage(
        key: 'theme_reveal_kit.mode',
        legacyBoolKey: 'wasDark',
      ),
      onPersistenceError: (error, stack) => debugPrint('Storage: $error'),
    );
// end:persistence

// snippet:modes
Widget modeSelector(RevealThemeController controller) => ListenableBuilder(
  listenable: controller,
  builder: (context, _) => Wrap(
    spacing: 8,
    children: [
      for (final mode in ThemeMode.values)
        Builder(
          builder: (chipContext) => ChoiceChip(
            label: Text(mode.name),
            selected: controller.themeMode == mode,
            onSelected: (_) => ThemeRevealViewport.of(
              chipContext,
            ).setThemeMode(controller, mode, from: chipContext),
          ),
        ),
    ],
  ),
);
// end:modes

// snippet:settings
Widget settingsAppearance(RevealThemeController controller) => Card(
  child: ListTile(
    title: const Text('Appearance'),
    subtitle: const Text('Light, dark, or follow the system'),
    trailing: RevealThemeButton(controller: controller),
  ),
);
// end:settings

// snippet:icon
Widget iconMaskButton(RevealThemeController controller) => RevealThemeButton(
  controller: controller,
  style: const RevealButtonStyle(
    lightIcon: Icons.wb_sunny_outlined,
    darkIcon: Icons.nightlight_outlined,
  ),
  revealShape: const RevealShape.icon(Icons.favorite),
);
// end:icon

// snippet:svg
Widget svgMaskButton(RevealThemeController controller) => RevealThemeButton(
  controller: controller,
  logo: const FlutterLogo(),
  logoAnimation: RevealLogoAnimation.rotate,
  revealShape: const RevealShape.svgAsset('assets/logo.svg'),
);
// end:svg

// snippet:png
Widget pngMaskButton(RevealThemeController controller) => RevealThemeButton(
  controller: controller,
  revealShape: const RevealShape.pngAsset(
    'assets/logo.png',
    alphaThreshold: 32,
    trim: true,
  ),
);
// end:png

// snippet:json
Widget jsonMaskButton(RevealThemeController controller) => RevealThemeButton(
  controller: controller,
  revealShape: const RevealShape.jsonAsset('assets/custom_shape.json'),
);
// end:json

// snippet:json_path
const jsonPathDocument = '''{
  "type": "path",
  "viewBox": [0, 0, 100, 100],
  "paths": [
    {
      "d": "M50 5 L95 90 L5 90 Z",
      "fillRule": "evenOdd",
      "transform": "rotate(10 50 50)"
    }
  ]
}''';
// end:json_path

// snippet:json_shape
const jsonShapeDocument = '''{
  "type": "shape",
  "shape": "star",
  "parameters": {"points": 5, "innerRadius": 0.45}
}''';
// end:json_shape

// snippet:path
RevealShape diamondPath() => RevealShape.customPath(
  builder: (size) => Path()
    ..moveTo(size.width / 2, 0)
    ..lineTo(size.width, size.height / 2)
    ..lineTo(size.width / 2, size.height)
    ..lineTo(0, size.height / 2)
    ..close(),
);
// end:path

// snippet:strategies
RevealAnimationConfig preservingStar() => const RevealAnimationConfig(
  completionStrategy: RevealCompletionStrategy.preserveShape,
);

RevealAnimationConfig morphingStar() => const RevealAnimationConfig(
  completionStrategy: RevealCompletionStrategy.morphToFullscreen,
  completionStart: .7,
);

RevealAnimationConfig dissolvingLogo() => const RevealAnimationConfig(
  completionStrategy: RevealCompletionStrategy.expandAndDissolve,
  completionStart: .7,
);
// end:strategies

// snippet:animation
RevealAnimationConfig animatedConfiguration() => const RevealAnimationConfig(
  enabled: true,
  duration: Duration(milliseconds: 850),
  curve: Curves.easeInOutCubic,
  delay: Duration(milliseconds: 50),
  completionDelay: Duration.zero,
  origin: RevealOrigin.gesture(),
  initialSize: 8,
  startRotation: 0,
  endRotation: .4,
  alignment: Alignment.center,
  maskFit: RevealMaskFit.contain,
  completionStrategy: RevealCompletionStrategy.auto,
  morphToFullscreen: false,
  completionStart: .7,
  edgeColor: Colors.indigo,
  edgeWidth: 2,
  glowColor: Colors.indigoAccent,
  glowRadius: 8,
  feather: 2,
  repeatPolicy: RevealRepeatPolicy.queueLatest,
  reducedMotion: RevealReducedMotion.system,
);
// end:animation

// snippet:trigger
Widget customThemeTrigger(RevealThemeController controller) =>
    RevealThemeTrigger(
      controller: controller,
      animation: const RevealAnimationConfig(origin: RevealOrigin.gesture()),
      child: const Chip(
        avatar: Icon(Icons.contrast),
        label: Text('Change appearance'),
      ),
    );
// end:trigger

// snippet:storage
class SessionThemeStorage implements ThemeStorage {
  ThemeMode? _mode;

  @override
  Future<ThemeMode?> read() async => _mode;

  @override
  Future<void> write(ThemeMode mode) async => _mode = mode;
}

Future<RevealThemeController> sessionController() =>
    RevealThemeController.create(storage: SessionThemeStorage());
// end:storage

// snippet:programmatic
Future<bool> revealFromCenter(
  BuildContext context,
  RevealThemeController controller,
) => ThemeRevealViewport.of(context).toggleTheme(
  controller,
  from: context,
  shape: const RevealShape.circle(),
  config: const RevealAnimationConfig(origin: RevealOrigin.screenCenter()),
);
// end:programmatic

// snippet:accessibility
Widget accessibleThemeButton(RevealThemeController controller) =>
    RevealThemeButton(
      controller: controller,
      tooltip: 'Change color theme',
      semanticLabel: 'Switch color theme',
      animation: const RevealAnimationConfig(
        reducedMotion: RevealReducedMotion.system,
      ),
    );
// end:accessibility
