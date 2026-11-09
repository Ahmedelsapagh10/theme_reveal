# Contributing

Keep changes scoped and follow the existing package and example patterns. Include
regression tests for behavior changes and report the platforms actually tested.

## Checks

Run from a clean checkout of the intended release contents:

```sh
dart format .
flutter analyze
flutter test --concurrency=2
cd example
flutter analyze
flutter test --concurrency=1
flutter test integration_test/circular_reveal_test.dart -d macos
cd ..
flutter pub publish --dry-run
```

A dry-run validates the package; it does not authorize publishing. Check the
version and CHANGELOG before preparing an archive. Never include credentials,
raw captures, local previews or verification logs in the package archive.

## README examples

Keep Dart blocks copied from compiled sources in `example/lib/` or `example/test/support/`. The checks in
`example/test/readme_snippets_test.dart` enforce matching snippets, a maximum of
commented direct-use bodies, local links, media files and release metadata.
Complete app examples include their imports and setup; compilation wrappers stay outside the displayed expression regions. The Cubit and ValueNotifier recipes are compiled and exercised by the example
widget tests; flutter_bloc is an example-only development dependency.

## Example

```sh
cd example
flutter pub get
flutter run -d macos
flutter run -d macos -t lib/external_main.dart
```

## Media recording

Use the real example app. Keep its window visible and foregrounded throughout
recording. Do not use accessibility inspection during native recording. The
persistence demo joins recordings from two processes with an explicit restart
edit. GIF export cadence is not an app performance measurement.

See [the media guide](doc/media/README.md) for capture, conversion and QA commands.
Keep raw MOV/MP4 files and local previews outside release contents. Check media
sizes against `doc/media/manifest.json`; each GIF must be at most 1.5 MB. Reuse of
a general reveal GIF in the cookbook demonstrates the visual effect, not proof
that the exact adjacent recipe was recorded. Push referenced media before relying
on remote README URLs. Publishing is a separate, explicitly authorized action.

macOS is verified. Android, iOS, web, Windows, Linux and live VoiceOver are
unverified. Profile-mode performance has not been measured.
