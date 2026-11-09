# Real macOS example media

These files show actual foreground pixels from `theme_reveal_kit_example`.
No library behavior, simulated reveal, mock-up or accessibility inspection was
used. `media_capture_test.dart` drives the real example and reports a failure
if it is not resumed before/after a recording. Keep the window visible for the
entire session. Do not run computer-control accessibility inspection.

The shapes and strategies are identified by the actual Settings picker labels.
Playground is filmed changing duration, curve and origin before revealing.
Persistence is an explicit edit between captures from two real OS processes:
light is saved, the first test process quits, then another process restores light
without writing it first. Its transition is labeled; it is not a single uncut
screen recording. The persistence loop has an intentional restart edit.

## Tools used

- macOS `/usr/sbin/screencapture -v -V… -R…` (video) and `-x -R…` (stills).
- CoreGraphics window geometry via `tool/media_window.swift`; no AX API.
- ffmpeg 7.1 from the PyPI `imageio-ffmpeg` 0.6.0 macOS arm64 wheel.
- ImageMagick 7.1.2-13 to resize/strip real PNG stills.
- `markdown-it-py` 3.0.0 for the local README HTML preview.

The temporary tools were installed outside the project:

```sh
python3 -m pip install --target /private/tmp/theme-reveal-media-tools imageio-ffmpeg markdown-it-py
```

Set FFMPEG_BIN to a compatible local ffmpeg binary. This helper prints the
installed wheel's binary path:

```sh
PYTHONPATH=/private/tmp/theme-reveal-media-tools python3 -c 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())'
```

## Repeatable capture

Compile the window-geometry helper from the repository root:

```sh
swiftc tool/media_window.swift -o /private/tmp/theme-reveal-media-window
```

From example/, start the opt-in fixture (it is skipped during ordinary tests):

```sh
flutter test integration_test/media_capture_test.dart -d macos --no-pub --dart-define=RECORD_MEDIA=true --reporter expanded
```

It prints `MEDIA_DIR=…` and waits. Bring the window to the foreground. From the
repository root, start the host recorder with that exact IPC folder:

```sh
python3 tool/record_media.py '<MEDIA_DIR>' --delay 15 --output /private/tmp/theme-reveal-recordings
```

Return to the app during the 15-second lead-in and keep it in front. The helper
crops the native title bar using read-only CoreGraphics coordinates. Raw MOVs
stay outside the repo. For persistence, let the first process fully exit, then
run the same test in a second process with `--dart-define=MEDIA_RESTORE=true`.
Use its new `MEDIA_DIR` with the host recorder. The restore case asserts the
saved light mode before recording.

## Conversion and QA

```sh
python3 tool/convert_media.py --ffmpeg "$FFMPEG_BIN" --input /private/tmp/theme-reveal-recordings
```

Conversion uses fps=15, Lanczos scaling, palettegen and paletteuse. It starts at
800px and 96 colors and reduces only if necessary to meet 1,500,000 bytes. There
are no synthetic reveal frames or reversed animations. Real return toggles are
recorded for the looping demos. GIF export cadence is not app performance.

`manifest.json` records actual bytes and export settings. All seven GIFs must be
at most 1.5 MB; screenshots must exist before being declared in pubspec.yaml.
The local preview HTML/screenshot, raw recordings and local report are excluded
from publication. MP4/WebP alternatives were not shipped because GIF quality
was adequate for these UI recordings.

The README uses the supplied repository's `master` branch URLs. Files must be
committed/pushed there for those remote URLs to resolve; this task did not push
or publish. pub.dev's screenshot carousel receives its declared local files.
