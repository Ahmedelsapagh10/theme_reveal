/// Observable lifecycle of a reveal request.
enum RevealTransitionState {
  /// No request is active.
  idle,

  /// Resolving origin, geometry and motion policy.
  preparing,

  /// Waiting for paint and capturing the old Flutter subtree.
  capturing,

  /// Invoking the accepted callback and waiting for the new theme frames.
  applyingTheme,

  /// Animating the cutout through the old frame.
  revealing,

  /// Holding the transparent endpoint before resource cleanup.
  completing,
}

/// Acceptance policy for requests received while a reveal is busy.
enum RevealRepeatPolicy {
  /// Ignore a new request and return false without invoking its callback.
  ignore,

  /// Keep only the latest pending request; superseded pending requests return false.
  queueLatest,
}

/// Motion policy shared by the engine and the theme button.
enum RevealReducedMotion {
  /// Follow MediaQuery.disableAnimations.
  system,

  /// Always change themes instantly and suppress decorative motion.
  always,

  /// Explicitly animate even when the system requests reduced motion.
  never,
}
