# Theme Reveal Kit

## 1. Product overview

Persistent light, dark and system themes for Flutter, with an outward reveal
from a button, gesture or configured origin. The default is a circle. The old
Flutter frame becomes a temporary overlay while the real application below it
changes theme; Navigator, focus and tab state stay in the live tree.

Version **0.1.0**. MIT © 2026 Ahmed Elsapagh. Repository/homepage metadata is
still a clearly marked release placeholder in pubspec.yaml; this checkout has
not been published by this release check.

## 2. Default Circular Reveal GIF

**Pending.** No distributable GIF or screenshot recording has been produced for
this README, so no preview link is provided. Run the example to see the circular
reveal; native macOS pixel checks are listed in section 23.

## 3. Custom shape demonstrations

**Preview media pending.** The runnable Playground demonstrates circle, ellipse,
rectangle, rounded rectangle, triangle, star, heart, diamond, hexagon, polygon,
custom Path, Icon, SVG, PNG and JSON. The bundled SVG/PNG/custom ring have holes
and demonstrate dissolve fallback. No missing preview files are referenced.

## 4. Feature overview

- Restore a preference before runApp; persist subsequent changes in serialized
  writes with error reporting and optional legacy bool migration.
- Managed controller mode or controller-independent external state.
- Shape-independent placement, coverage sizing and completion, with bounded
  raster decoding and data-only SVG/JSON parsing.
- Accessible custom-child triggers and a compact 48px default theme button.
- Configurable origins, timing, fit, rotation, alignment, completion, vector
  effects, repeat policy and reduced motion.

Three separate choices must not be confused:

| Choice | API | Effect |
| --- | --- | --- |
| Button appearance | RevealButtonStyle | Size, color, border, radius and moon/sun icons |
| Decorative logo | RevealThemeButton.logo / logoAnimation | A fitted widget inside the button; never the reveal mask |
| Reveal mask | revealShape | The vector path or raster alpha silhouette exposing the live app |

The public barrel is `package:theme_reveal_kit/theme_reveal_kit.dart`. It exports
controller/storage types, managed settings/builder, viewport/state, button/style/
trigger/logo animation, shape/resolved-shape/errors, origin, config, fit,
completion and motion/repeat/state enums, and their callback typedefs. Rendering,
parser and decode implementations stay under `src/` and are not barrel exports.

## 5. Installation

Requires **Flutter >=3.41.0 and Dart >=3.11.0 <4.0.0**, matching the pinned
shared_preferences 2.5.6 Flutter minimum. This checkout was checked using Flutter
3.41.9 / Dart 3.11.5; minimum-SDK execution has not been tested separately.

The following hosted constraint is for after 0.1.0 is available on pub.dev:

```yaml
dependencies:
  theme_reveal_kit: ^0.1.0
```

For the unpublished local checkout, use a path dependency pointing to this
package. Fetch dependencies with `flutter pub get`. No native setup specific to
this package is required beyond its shared_preferences dependency.

Application-owned masks must be declared in the application's pubspec. These
three files actually exist in the example:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/logo.svg
    - assets/logo.png
    - assets/custom_shape.json
```

The package does not silently bundle an application logo. Asset factories accept
`package` and `bundle` for package-owned assets or an injected bundle.

## 6. Five-minute quick start

Use this as an application's main.dart. The app owns/disposes the controller.
Pass **all three** managed settings to MaterialApp: themeMode,
themeAnimationDuration (always zero), and builder.

```dart
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
```

The viewport is installed through MaterialApp.builder above Navigator. It keeps
one permanent Stack containing the RepaintBoundary(child) and the overlay; the
live application is not reparented into a snapshot branch. Theme rebuilds are
normal Flutter rebuilds, while its route/state identity remains mounted.

Every Dart block below is copied from compiled functions in
`example/lib/readme_snippets.dart` or
`example/lib/readme_external.dart`. Blocks without imports
use the quick-start imports. `example/test/readme_snippets_test.dart`
check exact source matches and compile the source modules.

## 7. Theme persistence

Initialize bindings first, then await restoration before the first frame:

```dart
Future<RevealThemeController> restoreSavedTheme() =>
    RevealThemeController.create(
      defaultMode: ThemeMode.system,
      storage: SharedPrefsThemeStorage(
        key: 'theme_reveal_kit.mode',
        legacyBoolKey: 'wasDark',
      ),
      onPersistenceError: (error, stack) => debugPrint('Storage: $error'),
    );
```

The codec accepts only the case-sensitive strings light, dark and system.
Missing/invalid values use the controller's configured default mode. Legacy bool
migration occurs only when the new key is absent; true means dark, false light.
The old key is removed only after a successful new write. Migration reads only
keys visible through the configured backend; legacy API prefixes or different
platform stores may require an adapter.

Controller changes notify immediately; disk writes are serialized. Use flush()
when you need writes to finish, reloadFromStorage() to re-read, and
lastPersistenceError/onPersistenceError to surface failures. Storage errors do
not revert the live theme. Shared preferences are preference storage, not a
transactional or critical-data durability guarantee.

## 8. Light / Dark / System

System follows platform brightness, and the button's default icon/label follows
the effective brightness. This selector animates explicit mode changes:

```dart
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
```

A direct controller.setThemeMode/toggleTheme/resetToSystem call changes the
preference immediately without requesting a reveal. Use viewport helpers when
you want an animated programmatic change.

## 9. Settings Tab integration

Place the main button inside the Settings layout; the package injects no
floating button:

```dart
Widget settingsAppearance(RevealThemeController controller) => Card(
  child: ListTile(
    title: const Text('Appearance'),
    subtitle: const Text('Light, dark, or follow the system'),
    trailing: RevealThemeButton(controller: controller),
  ),
);
```

The full example keeps the selector, current mode, persistence explanation,
shared pickers, Playground shortcut and persistence lab in this tab.

## 10. Custom Icon

Style icons describe the button; RevealShape.icon describes the raster mask.
They can be different:

```dart
Widget iconMaskButton(RevealThemeController controller) => RevealThemeButton(
  controller: controller,
  style: const RevealButtonStyle(
    lightIcon: Icons.wb_sunny_outlined,
    darkIcon: Icons.nightlight_outlined,
  ),
  revealShape: const RevealShape.icon(Icons.favorite),
);
```

Enable uses-material-design for Material Icons. Icon masks use TextPainter with
the supplied font family/package/fallbacks and are trimmed to tight alpha bounds.
Load custom fonts first. Empty/missing-glyph masks report RevealShapeException;
the engine reports onError and uses the circle. A fallback font containing the
glyph can still render it; rasterization does not prove custom-font identity.

## 11. SVG logo

This example deliberately uses a decorative FlutterLogo widget and a different
SVG reveal silhouette:

```dart
Widget svgMaskButton(RevealThemeController controller) => RevealThemeButton(
  controller: controller,
  logo: const FlutterLogo(),
  logoAnimation: RevealLogoAnimation.rotate,
  revealShape: const RevealShape.svgAsset('assets/logo.svg'),
);
```

SVG input is data only, parsed with xml and path_drawing. It never executes
scripts or fetches external resources. Limits: **1 MiB UTF-8, 2000 elements**.

| SVG feature | Support |
| --- | --- |
| path; rect with rx/ry; circle; ellipse; polygon; filled polyline | Supported filled geometry |
| Nested g; matrix, translate, scale, rotate (optional center), skewX/skewY | Supported transforms |
| Inherited fill/fill-rule; inline style; evenodd/nonzero; fill=none; display:none | Supported |
| viewBox; numeric/px root width/height; framing/clipping | Supported |
| Multiple elements | Union with Path.combine; holes within paths are preserved |
| Gradients/resource fills, clipPath, mask, filter, use, text, stroke-only elements | Skipped, with warnings |
| External resources, images, nested SVG viewports, scripts, stylesheets | Not loaded/executed; skipped with warnings |
| CSS selectors, percentage lengths, opacity/color rendering, stroke expansion, animation | Not a supported rendering model |

Geometry affected by clip-path/mask/filter or resource fills is skipped rather
than silently painting an incorrect outline. DOCTYPE/ENTITY declarations are
rejected. No supported filled geometry means an error, not an empty reveal.
Warnings are available on low-level ResolvedShape.warnings. For unsupported
artwork, export a transparent PNG. See `doc/asset_masks.md`.

## 12. PNG logo

```dart
Widget pngMaskButton(RevealThemeController controller) => RevealThemeButton(
  controller: controller,
  revealShape: const RevealShape.pngAsset(
    'assets/logo.png',
    alphaThreshold: 32,
    trim: true,
  ),
);
```

PNG/bytes masks use image alpha with dstOut, not brightness or background
removal. **A fully opaque PNG is a rectangle.** Pixels below alphaThreshold
(1–255) become transparent; surviving partial alpha is retained. Trim removes
transparent margins; false keeps the original canvas proportions/margins.

Encoded input is capped at **8 MiB**, source area at **16 megapixels**, and the
decoded longest side at **256 px**. The first frame of supported animated input
is used as a static mask. Entirely transparent/thresholded-away masks fail.
Temporary buffer, descriptor, codec and images are disposed. Raster masks ignore
edge, glow and feather. Small alpha details may be lost at the resolution cap.
RevealShape.bytes accepts copied encoded bytes with the same options and limits.

## 13. JSON shape

```dart
Widget jsonMaskButton(RevealThemeController controller) => RevealThemeButton(
  controller: controller,
  revealShape: const RevealShape.jsonAsset('assets/custom_shape.json'),
);
```

The data-only schema has two document forms. A path document:

```json
{
  "type": "path",
  "viewBox": [0, 0, 100, 100],
  "paths": [
    {
      "d": "M50 5 L95 90 L5 90 Z",
      "fillRule": "evenOdd",
      "transform": "rotate(10 50 50)"
    }
  ]
}
```

A predefined shape document:

```json
{
  "type": "shape",
  "shape": "star",
  "parameters": {"points": 5, "innerRadius": 0.45}
}
```

The `doc/reveal_shape.schema.json` describes the structural contract;
the runtime additionally validates finite geometry and SVG path/transform syntax.
Limits are **1 MiB UTF-8 and 1–2000 paths**. Unknown fields and unsupported names
are errors. Lottie JSON is explicitly rejected: export a frame as PNG/SVG.

- Path root: required type=path and paths; optional viewBox.
- Each path: required non-blank d; fillRule is nonZero (default) or evenOdd;
  transform is an SVG transform string or six-number `[a,b,c,d,e,f]` affine array.
- Shape root: required type=shape and shape; optional parameters and viewBox.
- viewBox is `[x,y,positiveWidth,positiveHeight]`. It clips and frames geometry;
  a predefined shape is fitted inside that frame.
- circle, triangle, heart, diamond and hexagon have no parameters.
- ellipse/rectangle: aspectRatio (default 1.5), finite and positive.
- roundedRectangle: aspectRatio (1.5), cornerRadius (0.16), finite/non-negative
  normalized longest-side units, clamped to half the shortest side.
- star: integer points (default 5, range 2–512) and innerRadius (0.45, strictly
  between 0 and 1). polygon: integer sides (default 6, range 3–512).

Integer parameter tokens must decode as Dart int (use 5 rather than 5.0).
Optional viewBox/parameters/fillRule/transform and optional parameter values may
be null, using their absent/default behavior. Type, shape and path data cannot.

## 14. Custom Path

```dart
RevealShape diamondPath() => RevealShape.customPath(
  builder: (size) => Path()
    ..moveTo(size.width / 2, 0)
    ..lineTo(size.width, size.height / 2)
    ..lineTo(size.width / 2, size.height)
    ..lineTo(0, size.height / 2)
    ..close(),
);
```

The deterministic builder receives Size(100,100). Resolution centers geometry at
(0,0) and normalizes its longest bounds side to 1. Empty, non-finite and degenerate
paths throw RevealShapeException; the engine reports onError and uses the circle.
Compound paths and holes are supported, but may require dissolve completion.

**Low-level/internal-use guidance:** applications normally pass RevealShape to
the engine and do not resolve it themselves. resolve() is synchronous for vector
factories and SVG/JSON strings; resolveAsync() handles every source, including
icons, bytes and bundle assets. The engine chooses automatically before capture.
ResolvedShape and cache results expose geometry/warnings for advanced inspection;
returned results are cache-owned. Do not dispose a borrowed result. retain()
creates an independently owned raster handle; dispose that retained handle when
finished. Re-resolve an evicted/disposed raster result. The 12-entry shared LRU
disposes raster handles on eviction; active reveals retain their own handle.
clearCache() clears completed entries, not in-flight loads.

## 15. Mask completion strategies

| Strategy | Final interval | When to use |
| --- | --- | --- |
| auto | Preserve if sampled coverage succeeds; otherwise dissolve | Default |
| preserveShape | Continue expanding the same silhouette | Keep a coverable shape recognizable |
| morphToFullscreen | Union with a growing circle from completionStart | Smoothly fill gaps around the silhouette |
| expandAndDissolve | Expand while fading the remaining old frame | Complex/holed masks or an intentional fade |
| custom(builder) | Caller returns viewport-space cutout paths | Custom vector completion, still with terminal safety fade |

```dart
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
```

Morph is a growing-circle union, not point-by-point shape interpolation. Custom
builders receive placed shapePath, raw progress, viewport and origin; for raster
sources shapePath is the placement rectangle and the returned vector cutout
overrides the alpha mask.

The coverage solver tests an **11×11 sample grid** plus an anchor-hole check,
using final rotation and placement. It doubles then bisects the scale. This is
**not an exact proof of arbitrary-path coverage**: thin features or holes can
fall between samples. If coverage fails, it uses 1.5× the viewport diagonal and
switches to dissolve, even when another strategy was requested.

**The terminal old-frame fade is the real endpoint guarantee.** Simple masks
fade over the final 3% of raw progress; complex masks/custom strategies use 12%.
At progress 1 the painter draws no old frame or edge decoration, including an
incomplete custom cutout. Coverage sampling alone is not the guarantee.

## 16. Animation customization

0.1.0 implements outward reveals only; there is no inward-direction option.

```dart
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
```

Sizes are logical pixels, rotations radians, and feather a Gaussian sigma.
Contain preserves proportions; fill stretches bounds to viewport proportions
before rotation. Alignment anchors a point of the mask at the resolved origin.
Edge/glow/feather apply only to vector shapes.

copyWith replaces non-null fields; null color arguments retain the old colors.
Construct a new config to clear a nullable color. Negative durations are errors;
disabled, zero-duration and reduced-motion reveals apply instantly without a
snapshot. morphToFullscreen is a shortcut subject to non-coverable fallback.

Origins include buttonCenter, gesture, screenCenter, physical and RTL-aware
start/end corners, normalized/offset coordinates, and fromKey(GlobalKey). They
resolve through localToGlobal/globalToLocal for SafeArea, scrolling, transforms
and nested Navigators. Keyboard/semantic gestures fall back to the source center.
An unattached key reports an error and the engine applies the change instantly.

Repeat ignore returns false without invoking a new callback. queueLatest keeps
only the latest pending request; a superseded pending request returns false. Its
origin and state-changing callback are evaluated when it becomes active.
The viewport exposes the idle → preparing → capturing → applyingTheme → revealing
→ completing lifecycle as a ValueListenable. Metrics/lifecycle interruption aborts
instantly and releases the overlay/snapshot; dispose cancels pending requests.

## 17. Custom button

```dart
Widget customThemeTrigger(RevealThemeController controller) =>
    RevealThemeTrigger(
      controller: controller,
      animation: const RevealAnimationConfig(origin: RevealOrigin.gesture()),
      child: const Chip(
        avatar: Icon(Icons.contrast),
        label: Text('Change appearance'),
      ),
    );
```

The trigger owns pointer-down/tap, Enter/Space, focus and semantics; interactive
children are decorative to avoid duplicate activation. The button adds style,
tooltip, semanticLabel, enabled/busy state, press scale, and moon/sun animation.
A supplied logo preserves aspect ratio inside iconSize. Its none/scale/rotate/
fade animation is decorative and does not choose the reveal silhouette.

## 18. Cubit integration

External mode requires no state-management dependency. Drive MaterialApp.themeMode
from your Cubit/stream, set themeAnimationDuration to Duration.zero, and install
ThemeRevealViewport through MaterialApp.builder. Call the compiled adapter below
with your app-defined updateMode operation; this is not a package-provided Cubit
class or a claim about your application's method names.

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

Future<bool> revealCubitMode(
  BuildContext context, {
  required ThemeMode mode,
  required FutureOr<void> Function(ThemeMode) updateMode,
  RevealAnimationConfig config = const RevealAnimationConfig(),
}) => ThemeRevealViewport.of(context).reveal(
  from: context,
  shape: const RevealShape.circle(),
  config: config,
  onThemeChange: () => updateMode(mode),
);
```

**updateMode/onThemeChange must finish after emitting the new state**, not merely
after scheduling it. Both synchronous emitters and futures are accepted. The
engine waits two end-of-frames after the callback before animating. Do not also
apply the same state change outside the accepted callback: ignored requests must
not change the theme. The separate `example/lib/external_main.dart`
is the runnable controller-free reference and is covered by native pixel tests.

## 19. Custom storage

```dart
class SessionThemeStorage implements ThemeStorage {
  ThemeMode? _mode;

  @override
  Future<ThemeMode?> read() async => _mode;

  @override
  Future<void> write(ThemeMode mode) async => _mode = mode;
}

Future<RevealThemeController> sessionController() =>
    RevealThemeController.create(storage: SessionThemeStorage());
```

This sample is intentionally session-only. Implement read/write using your own
backend for durability; return null for invalid/absent data and let errors reach
the controller. MemoryThemeStorage provides the built-in in-memory alternative.
ThemePreferencesBackend injects the SharedPrefsThemeStorage platform boundary.
The full example's `example/lib/example_storage.dart` reuses
that implementation while exposing its real raw key to the persistence lab.

## 20. Programmatic transitions

Use a context below the installed viewport:

```dart
Future<bool> revealFromCenter(
  BuildContext context,
  RevealThemeController controller,
) => ThemeRevealViewport.of(context).toggleTheme(
  controller,
  from: context,
  shape: const RevealShape.circle(),
  config: const RevealAnimationConfig(origin: RevealOrigin.screenCenter()),
);
```

The viewport also exposes setThemeMode(controller, mode, …) and
reveal(from:, globalPosition:, shape:, config:, onThemeChange:, onError:).
A true result means the accepted change applied, including instant fallbacks;
false means ignored/superseded/disposed or a failed callback. The engine captures
at min(devicePixelRatio,3), installs the old overlay for one frame, invokes the
callback, waits two end-of-frames, animates dstOut, and releases resources in
finally. A capture override is available for GPU-free widget tests; it is a
visibleForTesting seam, not an application capture service.

## 21. Accessibility

```dart
Widget accessibleThemeButton(RevealThemeController controller) =>
    RevealThemeButton(
      controller: controller,
      tooltip: 'Change color theme',
      semanticLabel: 'Switch color theme',
      animation: const RevealAnimationConfig(
        reducedMotion: RevealReducedMotion.system,
      ),
    );
```

Default screen-reader labels switch with effective brightness. Supply localized
labels/tooltips for your app. Custom labels remain your responsibility when the
mode changes. Targets are at least 48px when parent constraints permit; do not
force smaller constraints. RTL, large text, high-contrast theme colors and
Enter/Space are covered by widget tests. busy disables activation, supplies a
semantic status and shows a static indicator when motion is reduced.

Reduced motion defaults to system (MediaQuery.disableAnimations). always forces
instant changes; never explicitly overrides that preference. These policies also
cover button press/icon/logo motion. **Live VoiceOver remains unverified**;
widget semantics tests do not certify a native screen-reader experience.

## 22. Performance considerations

**Profile-mode performance is unmeasured. No FPS numbers are claimed.** Measure
on your target devices with realistic content before shipping. Native pixel tests
prove observed compositing/cleanup, not release/profile throughput.

Snapshots scale with viewport area and pixel ratio squared (a 3× snapshot has
nine times the pixels of 1×); texture and intermediate-layer overhead is additional.
Resolution is cached in a bounded 12-entry LRU; raster masks decode to at most
256px on their longest side. Snapshot, temporary decode resources and retained
active-mask handles have explicit cleanup. Avoid unnecessary cache clearing and
load custom fonts before starting an icon-mask reveal.

## 23. Platform limitations

Only the captured Flutter subtree is represented. **Platform views, native
surfaces and system UI are not captured.** Video, maps, web views or other native
content may be absent from a snapshot; test those compositions in your app.
The package does not capture the native title bar, status/navigation bars or
other applications. A successful Flutter toImage call does not prove that a
platform view was included.

**Capture failure reports onError and falls back to an instant theme change.**
Unsupported shapes similarly report and fall back to circle. Metrics changes or
a non-resumed lifecycle abort the animation and clean up. Snapshot fidelity and
capture support depend on the Flutter renderer/platform; do not infer support
from the pure-Dart API or presence of an example host.

| Verification target | Status |
| --- | --- |
| macOS | Verified in debug native integration: real old/new pixels, 55 shape/strategy cases, cleanup, real persistence lab, Playground and external ValueNotifier entry |
| Android | Unverified; no device/emulator run |
| iOS | Unverified; no device/simulator run |
| Web | Unverified; host exists, browser runtime not checked |
| Windows / Linux | Unverified |
| VoiceOver | Unverified; widget semantics checks only |
| Profile-mode performance | Unmeasured; no FPS claim |

The native fixture enables semantics before its handle baseline. Desktop AX
inspection previously encountered a Flutter macOS accessibility-bridge crash;
a passing pixel suite does not certify VoiceOver. Keep the native test window
visible; hiding it pauses frame scheduling. Host-interrupted matrix cases retry
and must still complete successfully to count.

## 24. Troubleshooting

- **Instant change instead of animation:** install settings.builder above
  Navigator; check enabled, zero duration and reducedMotion/system preference.
  A button without a viewport toggles instantly; programmatic of(context) throws
  if the viewport is absent. Check onError for capture failures.
- **Wrong/empty custom icon:** register and load the font before use, provide its
  correct family/package/fallbacks, and enable Material Icons when used. An empty
  or missing-glyph mask falls back to circle. A fallback font with that glyph can
  render successfully; the package cannot certify the font family's identity.
- **PNG reveals a rectangle:** the input is opaque. Supply actual transparency;
  there is no background removal. Adjust alphaThreshold/trim if fine alpha edges
  disappear or unexpected margins remain.
- **SVG differs from the artwork:** consult the support matrix/warnings. Convert
  unsupported gradients, clipping, text, external resources or strokes to a
  transparent PNG or supported filled paths.
- **Lottie rejected:** export one frame as PNG/SVG. Playback/extraction is not
  implemented.
- **Native content missing:** platform views, native surfaces and system UI are
  outside the captured Flutter subtree. An instant fallback is safer than an
  unsupported compositing assumption.
- **Theme changes after the reveal starts:** onThemeChange completed too early.
  Await/emit the new state before returning, pass zero MaterialApp interpolation,
  and keep the state change inside the accepted callback.
- **Holed mask dissolves despite preserve/morph:** coverage failure deliberately
  chooses dissolve. The sampled grid is approximate; terminal fade clears the
  remaining old pixels.
- **Persistence does not update UI immediately from disk:** controller setters
  notify immediately, writes are queued. Await flush() before inspection and
  reloadFromStorage() after external edits. Invalid input uses defaultMode; it
  is not silently rewritten by a reload.

## 25. Full example app

`example/README.md` has responsive Material 3 Home, Playground,
Settings and Integrations tabs in a state-preserving IndexedStack. One
RevealPreferences notifier feeds all controls. Playground exposes every config
field, all 15 shapes, six presets, reset and a screen-center action. Settings
keeps its compact in-layout button, tri-state selector and real persistence lab.

Run from the example directory:

```sh
flutter pub get
flutter run -d macos
# Separate controller-free entry:
flutter run -d macos -t lib/external_main.dart
```

Release checks from the package root (run suites sequentially on low disk space):

```sh
dart format .
flutter analyze
flutter test --concurrency=2
cd example
flutter test --concurrency=1
flutter test integration_test/circular_reveal_test.dart -d macos
cd ..
flutter pub publish --dry-run
```

The last command validates without uploading. No publish command without
--dry-run is part of these checks. Supply the real repository/homepage URL before
release; the pubspec comment is deliberately not a fabricated link. The
`LICENSE` and `CHANGELOG.md` accompany this checkout.
