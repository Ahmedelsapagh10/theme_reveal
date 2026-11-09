# README and media presentation report

Documentation/media only. No file under lib/ changed. Nothing was pushed or
published. Repository supplied by the user:
https://github.com/Ahmedelsapagh10/theme_reveal; verified default branch: master.
Version badge is honestly unpublished: pub.dev API returned HTTP 404.

## Produced vs skipped

All 7 requested GIFs and 3 screenshots were produced from actual foreground
macOS window pixels. The test drove real taps/config changes and asserted the
app was resumed before/after clips. No accessibility APIs were inspected.
CoreGraphics supplied window bounds only. No mock-ups, synthesized reveal
frames or reversed animation were used.

All GIFs: 800×600, target export 15 fps, 96-color palettegen/paletteuse, infinitely
looping, each under 1,500,000 bytes. The six reveal demos return through actual
app actions; first/last mean channel differences were below 0.5/255. Persistence
has a deliberate labeled restart edit between recordings of two OS processes;
its loop restarts at the initial dark state. It is not falsely presented as an
uncut quit/relaunch screen recording. The first process saved light and quit;
a new process asserted light without writing it first.

No MP4/WebP alternatives shipped because the GIF quality was adequate. Raw MOVs,
contact sheets and local preview files stay outside the published archive.

## Tools and exact commands

Installed temporary tooling (no project dependency changes):

- `python3 -m pip install --target /private/tmp/theme-reveal-media-tools imageio-ffmpeg markdown-it-py`
  — exit 0; imageio-ffmpeg 0.6.0, markdown-it-py 3.0.0, mdurl 0.1.2.
- The wheel supplied ffmpeg 7.1 arm64. Existing tools: macOS screencapture,
  Swift/CoreGraphics, ImageMagick 7.1.2-13 and headless Google Chrome.

Capture commands:

- `swiftc tool/media_window.swift -o /private/tmp/theme-reveal-media-window` — exit 0.
- In example/: `flutter test integration_test/media_capture_test.dart -d macos --no-pub --dart-define=RECORD_MEDIA=true --reporter expanded`
  — passed, one native documentation-capture test.
- Host: `python3 tool/record_media.py <MEDIA_DIR> --delay 15 --output /private/tmp/theme-reveal-loop-recordings`
  — exit 0; the helper invoked `/usr/sbin/screencapture -v -V<seconds> -R<x,y,800,600>`
  for each actual window video and `screencapture -x -R...` for stills.
- Longer hold capture used the same test with `--dart-define=MEDIA_SHORT=true`
  — exit 0, +1 test passed, only shapes/strategies recorded for 10 seconds each.
- Separate process: same native fixture with `--dart-define=MEDIA_RESTORE=true`
  — exit 0, +1 test passed; stored light theme asserted before recording.
- `python3 tool/convert_media.py --ffmpeg <wheel-binary> --input /private/tmp/theme-reveal-loop-recordings --persistence-input /private/tmp/theme-reveal-recordings`
  — exit 0; fps=15, scale=800, palettegen/paletteuse and labeled persistence cut.

The initial capture fixture attempt could not write outside the app container.
It was corrected to use its own IPC temporary directory plus host screencapture.
Stale capture coordination was also corrected: the opt-in fixture clears its own
IPC session before waiting. The shipped assets come from successful capture
runs, not failed attempts. Final size data is in doc/media/manifest.json.

Quality gates:

- `dart format .` — exit 0: Formatted 53 files (0 changed).
- `flutter analyze --no-pub` — exit 0: No issues found! (ran in 1.5s).
- `flutter test --no-pub --concurrency=2 --reporter expanded` — exit 0:
  +121: All tests passed!
- In example/: `flutter test --no-pub --concurrency=1 --reporter expanded`
  — exit 0: +16: All tests passed! This imports all recipe files, checks every
  one of the 18 README Dart snippets matches source exactly, and enforces at most
  25 lines per code block. Existing example behavior tests also pass.
- `flutter pub publish --dry-run` in working tree — exit 65, one warning:
  tracked README/test/pubspec edits are uncommitted. Repository/screenshots
  accepted; no missing/unsupported screenshot warning.
- `flutter pub publish --dry-run --directory /private/tmp/theme-reveal-presentation-package`
  on the clean staged package content — exit 0: Total compressed archive size:
  4 MB. Package has 0 warnings. No upload occurred. Staging omitted .git and
  ignored generated/local preview/raw files; user commits were not changed.
- `python3 tool/check_readme_links.py --remote` — 43 targets; zero broken local
  paths/anchors. All non-pending remote URLs returned HTTP 200.

Logs are under /private/tmp/theme-reveal-presentation-*.log. Prior release-check
reports remain historical and do not describe this updated README structure.

## Local HTML preview

`PYTHONPATH=/private/tmp/theme-reveal-media-tools python3 tool/preview_readme.py`
and `--gallery` generated local HTML using markdown-it-py, with tables enabled.
It rendered 8 tables, 22 image instances and 25 code blocks. A temporary
`python3 -m http.server 8768 --bind 127.0.0.1` served local files.

Headless Chrome with its own temporary profile rendered the top and a focused
gallery excerpt at 1100px wide. Visual inspection confirmed centered hero,
truthful badges, collapsed contents, correctly bordered/aligned gallery tables,
loaded real images, readable code blocks and no overflow. The gallery excerpt
was used after a transient macOS headless anchor-rendering blank screenshot;
that failed screenshot was not treated as successful preview evidence.

Preview images: /private/tmp/theme-reveal-readme-top.png and
/private/tmp/theme-reveal-readme-gallery.png. Preview CSS is local only; the
README itself contains no CSS/scripts/iframes, only minimal centering/details
HTML. No native app accessibility inspection was used for preview.

## Remaining remote URLs

The following are HTTP 404 until these new files are committed and pushed to
master. Every corresponding local file exists. Nothing was pushed in this task:

- https://github.com/Ahmedelsapagh10/theme_reveal/blob/master/doc/media/README.md
- https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/doc/media/hero.gif
- https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/doc/media/home_dark.png
- https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/doc/media/home_light.png
- https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/doc/media/logo_png.gif
- https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/doc/media/logo_svg.gif
- https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/doc/media/persistence.gif
- https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/doc/media/playground.gif
- https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/doc/media/settings_tab.png
- https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/doc/media/shapes.gif
- https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/doc/media/strategies.gif

Once pushed, repeat the remote link check. The four local pubspec screenshots
are packaged now and do not depend on GitHub hosting for the pub.dev carousel.
Android/iOS/web/Windows/Linux and VoiceOver remain unverified; profile-mode
performance is unmeasured. No FPS/throughput claim or false platform badge is made.
No publication is authorized or performed.

## Complete changed/created files with sizes

- [README.md](/Users/ahmedelsapagh/Downloads/theme_reveal/README.md) — 27,546 bytes
- [pubspec.yaml](/Users/ahmedelsapagh/Downloads/theme_reveal/pubspec.yaml) — 1,022 bytes
- [.pubignore](/Users/ahmedelsapagh/Downloads/theme_reveal/.pubignore) — 567 bytes
- [example/lib/presentation_quick_start.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/example/lib/presentation_quick_start.dart) — 800 bytes
- [example/lib/presentation_recipes.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/example/lib/presentation_recipes.dart) — 2,518 bytes
- [example/test/readme_snippets_test.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/example/test/readme_snippets_test.dart) — 9,626 bytes
- [example/integration_test/media_capture_test.dart](/Users/ahmedelsapagh/Downloads/theme_reveal/example/integration_test/media_capture_test.dart) — 10,135 bytes
- [tool/media_window.swift](/Users/ahmedelsapagh/Downloads/theme_reveal/tool/media_window.swift) — 728 bytes
- [tool/record_media.py](/Users/ahmedelsapagh/Downloads/theme_reveal/tool/record_media.py) — 1,772 bytes
- [tool/convert_media.py](/Users/ahmedelsapagh/Downloads/theme_reveal/tool/convert_media.py) — 2,805 bytes
- [tool/preview_readme.py](/Users/ahmedelsapagh/Downloads/theme_reveal/tool/preview_readme.py) — 1,813 bytes
- [tool/check_readme_links.py](/Users/ahmedelsapagh/Downloads/theme_reveal/tool/check_readme_links.py) — 1,790 bytes
- [doc/media/README.md](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/media/README.md) — 3,754 bytes
- [doc/media/manifest.json](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/media/manifest.json) — 1,002 bytes
- [doc/media/hero.gif](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/media/hero.gif) — 487,557 bytes
- [doc/media/shapes.gif](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/media/shapes.gif) — 689,778 bytes
- [doc/media/logo_svg.gif](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/media/logo_svg.gif) — 608,746 bytes
- [doc/media/logo_png.gif](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/media/logo_png.gif) — 698,374 bytes
- [doc/media/strategies.gif](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/media/strategies.gif) — 740,006 bytes
- [doc/media/playground.gif](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/media/playground.gif) — 1,115,532 bytes
- [doc/media/settings_tab.png](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/media/settings_tab.png) — 51,464 bytes
- [doc/media/home_light.png](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/media/home_light.png) — 63,448 bytes
- [doc/media/home_dark.png](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/media/home_dark.png) — 63,216 bytes
- [doc/media/persistence.gif](/Users/ahmedelsapagh/Downloads/theme_reveal/doc/media/persistence.gif) — 504,450 bytes

Total shipped GIF/PNG media: 5,022,571 bytes.

The local HTML preview files were copied to /private/tmp/theme-reveal-preview.html
and /private/tmp/theme-reveal-preview_gallery.html after QA, then removed from
the source media directory. Only actual distributable media remains there.

Report file size: 10,556 bytes (local, excluded from publication).
