import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

// snippet:circle
Widget circularButton(RevealThemeController controller) =>
    RevealThemeButton(controller: controller);
// end:circle

// snippet:vectors
Widget starButton(RevealThemeController controller) => RevealThemeButton(
  controller: controller,
  revealShape: const RevealShape.star(points: 5, innerRadius: .45),
);

Widget triangleButton(RevealThemeController controller) => RevealThemeButton(
  controller: controller,
  revealShape: const RevealShape.triangle(),
);
// end:vectors

// snippet:animation_short
const animation = RevealAnimationConfig(
  duration: Duration(milliseconds: 900),
  curve: Curves.easeInOutCubic,
  origin: RevealOrigin.gesture(),
  startRotation: -.4,
  endRotation: .4,
  repeatPolicy: RevealRepeatPolicy.queueLatest,
  reducedMotion: RevealReducedMotion.system,
);
// end:animation_short

// snippet:strategies_short
const preserve = RevealAnimationConfig(
  completionStrategy: RevealCompletionStrategy.preserveShape,
);
const morph = RevealAnimationConfig(
  completionStrategy: RevealCompletionStrategy.morphToFullscreen,
  completionStart: .7,
);
const dissolve = RevealAnimationConfig(
  completionStrategy: RevealCompletionStrategy.expandAndDissolve,
);
// end:strategies_short

// snippet:modes_short
Future<bool> chooseMode(
  BuildContext context,
  RevealThemeController controller,
  ThemeMode mode,
) => ThemeRevealViewport.of(
  context,
).setThemeMode(controller, mode, from: context);
// end:modes_short

// snippet:external_app
Widget externalThemeApp(ValueNotifier<ThemeMode> mode) =>
    ValueListenableBuilder(
      valueListenable: mode,
      builder: (context, value, _) => MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: value,
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => ThemeRevealViewport(child: child!),
        home: Scaffold(body: Center(child: externalThemeButton(mode))),
      ),
    );
// end:external_app

// snippet:external_button
Widget externalThemeButton(ValueNotifier<ThemeMode> mode) => Builder(
  builder: (context) => FilledButton(
    child: const Text('Toggle theme'),
    onPressed: () => ThemeRevealViewport.of(context).reveal(
      from: context,
      onThemeChange: () {
        mode.value = mode.value == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark;
      },
    ),
  ),
);
// end:external_button
