# M7 release report — 0.1.0

Date: 2026-11-09. Flutter 3.41.9 / Dart 3.11.5. No SDK or third-party dependency upgrade.
M7 is documentation, metadata, API documentation/export hygiene and starter
cleanup. No new package feature was added. Nothing was published.

## Release caveat

The real repository/homepage URL is not known. pubspec.yaml clearly marks its
repository placeholder as a comment, rather than inventing a reachable URL.
The publish dry-run returned **exit 65 with exactly one warning** requesting
homepage/repository metadata. Supply the real URL and repeat the dry-run before
publishing. User authorization for an actual publication was neither requested
nor used.

## Completed package capabilities

- Persistent light/dark/system preferences restored before the first frame;
  custom storage/backend seams, serialized writes, legacy bool migration and
  storage error reporting.
- Default circular reveal through a permanent MaterialApp.builder viewport,
  configurable origins, vector/alpha masks, completion strategies and resource
  cleanup, with instant failure/reduced-motion fallback.
- Bounded icon/PNG/bytes/SVG/JSON resolution, a 12-entry cache, vector edge/glow/
  feather, custom paths and custom completion callbacks.
- Accessible triggers/buttons, decorative logos, managed and external state,
  repeat policy, and the four-tab example with shared preferences.

These capabilities were implemented in M1–M6. M7 adds the 25-section README,
MIT license selected by Ahmed Elsapagh, 0.1.0 changelog/metadata, documentation
coverage checks, a structural JSON Schema and compiled documentation recipes.
Media previews remain pending; no missing GIF/screenshot is linked.

## Public API overview

One documented library, `package:theme_reveal_kit/theme_reveal_kit.dart`, exports
29 explicit top-level symbols:

- Controller/storage: RevealThemeController, ThemePersistenceErrorCallback,
  ThemeStorage, MemoryThemeStorage, ThemeModeCodec, SharedPrefsThemeStorage,
  ThemePreferencesBackend.
- Managed widgets: RevealThemeBuilder, RevealThemeSettings, RevealThemeButton,
  RevealButtonStyle, RevealLogoAnimation, RevealThemeTrigger.
- Engine/external mode: ThemeRevealViewport, ThemeRevealViewportState,
  RevealThemeChange, RevealTransitionState, RevealRepeatPolicy, RevealReducedMotion.
- Geometry/configuration: RevealShape, ResolvedShape, RevealOrigin,
  RevealAnimationConfig, RevealMaskFit, RevealCompletionStrategy, RevealCutoutBuilder.
- Errors: RevealException, RevealShapeException, RevealErrorCallback.

Viewport state exposes reveal, toggleTheme, setThemeMode and transitionState.
Resolution and cache ownership are documented as low-level engine/advanced-use
guidance: normal application controls choose resolve/resolveAsync automatically.
The raster-construction interop factory is internal/nodoc. All non-overriding
public declarations have dartdoc; Flutter overrides inherit framework docs.
Rendering/parser/decode helpers are not barrel exports. The generated Calculator
API and its test were removed.

## Exact checks and real results

Commands below ran from the package root unless a working directory is stated.
The no-pub flag reused the preceding successful pub get; concurrency limits
kept temporary compiler files within available disk space. No tests were skipped.

1. `flutter pub get` — exit 0: “Got dependencies!” and “Got dependencies in ./example.”
2. `dart format .` — exit 0: “Formatted 50 files (0 changed)”.
3. `flutter analyze --no-pub` — exit 0: “No issues found!”; includes
   public_member_api_docs. Log: `/private/tmp/theme-reveal-m7-analyze.log`.
4. `dart doc --validate-links` — exit 0: “Found 0 warnings and 0 errors”;
   “Documented 1 public library”. Generated doc/api is ignored/excluded from
   publication. Log: `/private/tmp/theme-reveal-m7-dartdoc.log`.
5. `flutter test --no-pub --concurrency=2 --reporter expanded` — exit 0:
   “+121: All tests passed!” Log: `/private/tmp/theme-reveal-m7-package.log`.
   The prior total was 122; exactly one generated Calculator test was removed.
6. In `example/`: `flutter test test/readme_snippets_test.dart --no-pub --concurrency=1 --reporter expanded`
   — exit 0: “+5: All tests passed!” It compiles both recipe modules and checks
   all **16 README Dart blocks**, exact source matches, 25 sections, JSON examples,
   assets, managed state, custom storage and async external-state emission.
7. In `example/`: `flutter test --no-pub --concurrency=1 --reporter expanded`
   — exit 0: “+15: All tests passed!”
   Log: `/private/tmp/theme-reveal-m7-example.log`.
8. In `example/`: `flutter test integration_test/circular_reveal_test.dart -d macos --no-pub --reporter expanded`
   — final exit 0: “+5: All tests passed!” Includes actual old/new pixel checks,
   **55 shape/strategy cases**, cleanup, decorative logo, Playground center
   origin, real raw-preference corruption/reload, and the external ValueNotifier
   app with retained state. Log: `/private/tmp/theme-reveal-m7-native-final.log`.
9. `flutter pub publish --dry-run` — exit 65. “Total compressed archive size:
   305 KB.” “Package has 1 warning”: strongly recommended homepage/repository
   field. No license, SDK, asset or dependency validation error was reported.
   Log: `/private/tmp/theme-reveal-m7-publish.log`. No upload/publication occurred.

The first M7 native attempt crashed in Flutter's macOS AccessibilityBridge
(CreateRemoveReparentedNodesUpdate) after desktop AX inspection. The final run
avoided that inspection and completed after the user kept the window visible.
Host visibility interruptions caused retries; only successfully completed
matrix cases counted. This is not a clean native VoiceOver certification.

## Run instructions

From `example/`, run `flutter pub get`, then `flutter run -d macos`.
For the controller-free entry, use
`flutter run -d macos -t lib/external_main.dart` instead.
The minimal compiled tutorial can also run with `-t lib/readme_snippets.dart`.
No migration, Android/iOS configuration or platform source changes are required.
The normal preference key stays theme_reveal_kit.mode. The persistence lab
intentionally edits that key when manually used; native tests use dedicated keys.

## Known limitations / unverified

- Android, iOS, web, Windows and Linux runtime checks were not performed.
- Live VoiceOver remains unverified; native AX inspection hit an SDK bridge crash.
- Profile-mode performance, FPS and minimum-SDK execution are unmeasured/unverified.
- GIFs/screenshots for publication are pending; no preview assets are fabricated.
- Platform views, native surfaces and system UI are outside the captured Flutter
  subtree. Successful toImage is not proof those surfaces were included.
  Capture failure reports onError and applies the theme instantly.
- The coverage solver uses an 11×11 sampled grid and an anchor-hole check;
  arbitrary fine geometry can evade those samples. The terminal fade is the
  real guarantee that no old pixels remain at progress 1.
- SVG supports filled geometry only with its documented subset; it never loads
  external resources or executes scripts. JSON Schema is structural; runtime
  parsing enforces actual SVG syntax, finite geometry and limits.
- Opaque PNGs are rectangles; raster effects ignore vector edge/glow/feather.
  Custom/fallback font identity must be verified by the application.
- There is no inward reveal direction or Lottie playback/frame extraction in 0.1.0.
- Asset/runtime behavior was checked on the current SDK, not every supported
  codec/font/renderer combination.

## Complete source / metadata file manifest

Generated build/cache files are not source changes. The generated doc/api tree
is excluded from publication. The generated local root lockfile is listed
separately for clarity; its versions were not upgraded.

- [.pubignore](/Users/ahmedelsapagh/Downloads/theme_reveal/.pubignore): Exclude generated builds, documentation output, editor state and local release report from the publish archive.
- [CHANGELOG.md](/Users/ahmedelsapagh/Downloads/theme_reveal/CHANGELOG.md): Added the factual 0.1.0 release notes and unresolved repository metadata note.
- [LICENSE](/Users/ahmedelsapagh/Downloads/theme_reveal/LICENSE): Replaced placeholder with MIT, copyright 2026 Ahmed Elsapagh, as explicitly chosen by the user.
- [M7_RELEASE_REPORT.md](/Users/ahmedelsapagh/Downloads/theme_reveal/M7_RELEASE_REPORT.md): Local release evidence, exact commands, API overview and this complete source-file manifest; excluded from publication.
- [README.md](/Users/ahmedelsapagh/Downloads/theme_reveal/README.md): Replaced starter text with the 25-section guide, verified code blocks, support matrices, verification status and limitations.
- [analysis_options.yaml](/Users/ahmedelsapagh/Downloads/theme_reveal/analysis_options.yaml): Enabled public_member_api_docs alongside flutter_lints.
- [doc/asset_masks.md](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/asset_masks.md): Removed milestone-only wording and made Lottie exclusion explicitly apply to 0.1.0.
- [doc/reveal_shape.schema.json](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/reveal_shape.schema.json): Added the structural JSON Schema matching supported path/shape document forms; runtime checks geometry and SVG syntax.
- [doc/widgets_and_external_mode.md](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/widgets_and_external_mode.md): Replaced a contextual pseudo-snippet with the compiled external adapter.
- [example/lib/readme_external.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/example/lib/readme_external.dart): Compilable FutureOr external-state/Cubit callback adapter used by the README and guide.
- [example/lib/readme_snippets.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/example/lib/readme_snippets.dart): Compilable source for managed startup and widget/storage/configuration recipes shown verbatim in the README.
- [example/pubspec.lock](/Users/ahmedelsapagh/Downloads/theme_reveal/example/pubspec.lock): Refreshed the local package reference to 0.1.0; no dependency upgrade.
- [example/test/readme_snippets_test.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/example/test/readme_snippets_test.dart): Checks all 16 Dart blocks against compiled sources, 25 sections, JSON examples/assets/metadata and managed/external/storage behavior.
- [lib/src/animation/reveal_animation_config.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/animation/reveal_animation_config.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/animation/reveal_completion_strategy.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/animation/reveal_completion_strategy.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/animation/theme_reveal_viewport.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/animation/theme_reveal_viewport.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/animation/transition_state.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/animation/transition_state.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/controller/reveal_theme_controller.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/controller/reveal_theme_controller.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/persistence/shared_prefs_theme_storage.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/persistence/shared_prefs_theme_storage.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/persistence/theme_storage.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/persistence/theme_storage.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/rendering/reveal_composition.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/rendering/reveal_composition.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/rendering/reveal_geometry.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/rendering/reveal_geometry.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/rendering/reveal_painter.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/rendering/reveal_painter.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/rendering/scene_capture.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/rendering/scene_capture.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/shapes/raster_mask_resolver.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/shapes/raster_mask_resolver.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/shapes/reveal_mask_fit.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/shapes/reveal_mask_fit.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/shapes/reveal_shape.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/shapes/reveal_shape.dart): Added factory/resolution/cache ownership docs and marked the raster-construction interop factory internal/nodoc; no engine behavior change.
- [lib/src/shapes/vector_asset_parser.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/shapes/vector_asset_parser.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/utils/reveal_exception.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/utils/reveal_exception.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/utils/reveal_origin.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/utils/reveal_origin.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/widgets/reveal_theme_builder.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/widgets/reveal_theme_builder.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/widgets/reveal_theme_button.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/widgets/reveal_theme_button.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/src/widgets/reveal_theme_trigger.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/src/widgets/reveal_theme_trigger.dart): Added dartdoc for existing declarations; no runtime behavior change.
- [lib/theme_reveal_kit.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/lib/theme_reveal_kit.dart): Documented the entry library and restricted exports to the intended 29 top-level API symbols.
- [pubspec.lock](/Users/ahmedelsapagh/Downloads/theme_reveal/pubspec.lock): Generated local lockfile refreshed by pub get; ignored for publication.
- [pubspec.yaml](/Users/ahmedelsapagh/Downloads/theme_reveal/pubspec.yaml): Set version 0.1.0, description/topics, Dart 3.11.0 / Flutter 3.41.0 minima and an explicit repository placeholder; retained dependency versions.

Removed starter files:

- `lib/theme_reveal.dart`: generated Calculator implementation.
- `test/theme_reveal_test.dart`: its generated addOne test.
