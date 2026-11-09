/// How normalized mask bounds are placed before rotation and coverage sizing.
enum RevealMaskFit {
  /// Preserve aspect ratio; size denotes the longest target side.
  contain,

  /// Stretch bounds to viewport proportions before rotation.
  fill,
}
