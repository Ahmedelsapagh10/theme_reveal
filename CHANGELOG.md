## 0.1.1

- Document direct widget and callback usage, with standalone managed, Cubit and
  ValueNotifier app examples.
- Expand managed and external usage recipes, including Cubit and
  ValueNotifier state, screen placement, shapes, animation and programmatic control.
- Add three-state selection, custom storage, migration and troubleshooting guidance.
- Add API reference usage examples and keep README recipes compiled and checked.
- No library behavior or dependency changes.

## 0.1.0

- Persistent light, dark and system modes, restored before the first frame;
  injectable storage, serialized writes, legacy bool migration and error reporting.
- A default circular reveal over the real live app, installed through
  `MaterialApp.builder`, with snapshot cleanup and instant capture-failure fallback.
- Vector and custom Path shapes, icon/PNG alpha masks, bounded SVG/JSON parsing,
  cached resolution, placement, rotation and completion strategies.
- Accessible triggers and compact buttons, decorative logos, configurable styling,
  reduced motion, repeat policies and controller-independent external mode.
- A four-tab Material 3 example, shared live preferences, persistence lab and
  separate ValueNotifier entry point.
- Compiled README examples, explicit public exports and API documentation.
- macOS native pixel checks; Android, iOS, web and VoiceOver remain unverified.
  Profile-mode performance is unmeasured; no FPS claim is made.
- Removed the generated Calculator scaffold. Import `theme_reveal_kit.dart`.
