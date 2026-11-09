/// Persistent Flutter theme management and shape-driven snapshot reveals.
///
/// Start with [RevealThemeController], [RevealThemeBuilder] and
/// [RevealThemeButton]. Use [ThemeRevealViewportState.reveal] for external state.
library;

export 'src/animation/reveal_animation_config.dart' show RevealAnimationConfig;
export 'src/animation/reveal_completion_strategy.dart'
    show RevealCompletionStrategy, RevealCutoutBuilder;
export 'src/animation/theme_reveal_viewport.dart'
    show ThemeRevealViewport, ThemeRevealViewportState, RevealThemeChange;
export 'src/animation/transition_state.dart'
    show RevealTransitionState, RevealRepeatPolicy, RevealReducedMotion;
export 'src/controller/reveal_theme_controller.dart'
    show RevealThemeController, ThemePersistenceErrorCallback;
export 'src/persistence/shared_prefs_theme_storage.dart'
    show SharedPrefsThemeStorage, ThemePreferencesBackend;
export 'src/persistence/theme_storage.dart'
    show ThemeStorage, ThemeModeCodec, MemoryThemeStorage;
export 'src/shapes/reveal_shape.dart'
    show RevealShape, RevealShapeException, ResolvedShape;
export 'src/shapes/reveal_mask_fit.dart' show RevealMaskFit;
export 'src/utils/reveal_exception.dart'
    show RevealException, RevealErrorCallback;
export 'src/utils/reveal_origin.dart' show RevealOrigin;
export 'src/widgets/reveal_theme_builder.dart'
    show RevealThemeBuilder, RevealThemeSettings;
export 'src/widgets/reveal_theme_button.dart'
    show RevealThemeButton, RevealButtonStyle, RevealLogoAnimation;
export 'src/widgets/reveal_theme_trigger.dart' show RevealThemeTrigger;
