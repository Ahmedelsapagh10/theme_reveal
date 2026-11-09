# Theme Reveal Kit example (M6)

Home, Playground, Settings and Integrations retain their state. Wide windows use
a navigation rail; narrow windows use bottom navigation. The compact Settings button reveals the
live new theme from its actual center. Light, dark, and system preferences use
SharedPreferencesAsync; restoration finishes before runApp.

From this directory:

```sh
flutter pub get
flutter run -d macos
# Separate ValueNotifier-driven external-mode app:
flutter run -d macos -t lib/external_main.dart
```

Open Settings, tap the moon/sun button, then quit and relaunch the app. The chosen
theme should return. The example also includes a web host (`flutter run -d chrome`).

Settings keeps its compact in-layout button, mode selector and shape/strategy
pickers. Playground adds all 15 shape options, controls for every animation
config field, six presets, reset, a live theme button and a screen-center action.
One RevealPreferences notifier feeds every theme control, including Integrations.
The bundled SVG, PNG and custom Path have center holes and demonstrate automatic
dissolve; JSON is a filled star. The default remains Circle + Auto.

The persistence lab reads the same raw key used by the main app. “Write invalid
value” deliberately replaces it; “Reload saved theme” applies the controller's
configured fallback (dark in main.dart). Selecting another mode saves a valid
value again. Storage errors are displayed. The custom ThemeStorage adapter and
its backend are injectable, so widget tests use memory without platform channels.

The managed wiring is in `lib/app.dart`: pass all three settings
(`themeMode`, `themeAnimationDuration`, `builder`) from RevealThemeBuilder to
MaterialApp. External state can use `ThemeRevealViewport.of(context).reveal`;
its onThemeChange callback must finish after emitting the new state.

Checks from this directory:

```sh
flutter analyze
flutter test
flutter test integration_test/circular_reveal_test.dart -d macos
flutter test integration_test/circular_reveal_test.dart -d macos --dart-define=VERIFY_PERSISTED_THEME=true
```

Keep the macOS test window visible: hiding it pauses native frame scheduling.
The matrix retries a case only when a host event interrupted it.

Run the two integration commands in order. The first uses real scene capture,
checks old/new pixels and cleanup, and saves light mode under a dedicated test
key. The second launches a new process and verifies restoration without writing
the key first. It does not change the example's normal preference key.

The native test includes an 11 × 5 picker matrix plus the decorative-logo check,
Playground screen-center pixel checks, a real-storage invalid-value demo, and
the external ValueNotifier app with retained state. It samples the completed overlay
against the live tree before removing the overlay, checks the SVG/PNG holes
during expansion, verifies retained-mask disposal, and checks failed-decode
fallback. It also retains the default-circle pixel check.

The API also includes ellipse, diamond, hexagon, and polygon masks. Custom path
builders receive `Size(100, 100)`; resolution normalizes their bounds so the
longest side is 1 and the center is (0, 0). Builders should be deterministic:
resolved geometry is cached by shape identity in a 12-entry LRU cache.
`roundedRectangle.cornerRadius` uses normalized longest-side units.

`RevealMaskFit.contain` preserves proportions; `fill` stretches bounds to the
viewport proportions before rotation. Alignment chooses which point of the mask
is anchored at the reveal origin. Coverage uses the final rotation and an 11×11
sample grid, doubling then bisecting the scale. Fine path features can fall
between samples: the terminal fade guarantees that no old pixels remain anyway.
An uncovered anchor hole or a failed coverage search uses a 1.5× diagonal size
and dissolve. Invalid paths report `RevealShapeException` and use the circle.

Auto preserves a coverable shape. Preserve keeps its silhouette. Morph unions it
with a growing circle during the final interval (starting at 0.7 by default);
it is a continuous blend, not point-wise morphing. Dissolve fades the remainder
over that interval. Custom receives the placed path, raw progress, viewport,
and origin, and returns a cutout path. Its terminal frame is fully transparent
even when the callback returns an incomplete cutout. Simple shapes use a final
3% safety fade; complex shapes and custom strategies use 12%.

Vector edge stroke, glow, and feather are available through
`RevealAnimationConfig`. Feather is a Gaussian sigma in logical pixels. Shapes,
completion strategies, and these effects are independent of button decoration.

Asset support, limits, SVG warnings, JSON schema, font loading, and image ownership
are documented in [asset_masks.md](../doc/asset_masks.md). Raster masks ignore
edge, glow and feather. Opaque images are rectangles; no background removal is
performed. Only the source alpha defines a raster silhouette.

Platform views, native surfaces, and
system UI are outside the captured Flutter subtree. Capture failure reports
onError and applies the change instantly. Reduced motion defaults to the system
preference; disabled reveals skip capture. No mobile-device performance or web
runtime verification is implied by the macOS checks.
