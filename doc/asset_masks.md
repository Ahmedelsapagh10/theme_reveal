# Asset masks

The default remains `RevealShape.circle()`. Asset masks are optional inputs to the
same viewport, affine placement, coverage solver, and completion strategies.
Button decoration, a displayed icon/logo, and the reveal mask are independent.

## Loading and ownership

Use `RevealShape.icon(IconData)`, `pngAsset`, `bytes`, `svgAsset`, `svgString`,
`jsonAsset`, or `jsonString`. Asset constructors accept `package` and `bundle`.
Package assets use Flutter's `packages/<package>/<asset>` path convention.
Declare application assets in the application's `pubspec.yaml`.

`resolve()` remains synchronous for vector descriptions, including SVG/JSON
strings. For icons, encoded bytes, or bundle assets, await `resolveAsync()`.
The engine handles this automatically **before capturing the old frame**.
Failures report `RevealShapeException` through `onError` and use the circle.

The shared 12-entry LRU keys built-ins/custom paths by identity and assets by
source plus options (including bundle, package, threshold and trim). Equal byte
contents share a result; byte constructors copy their input. Concurrent requests
for the same source share a pending load. Failed loads are not cached.

Resolved cache results are cache-owned. Call `retain()` if keeping a raster
result independently; call `dispose()` on that retained result when finished.
Vector retains need no extra native resource. Active reveals retain their image
handles, so cache eviction can dispose its handle without breaking the reveal.
`RevealShape.clearCache()` disposes completed cache entries. In-flight loads can
populate the cache afterward. Re-resolve an evicted/disposed raster result.

## PNG and encoded bytes

`pngAsset(asset, alphaThreshold: 1, trim: true)` and
`bytes(encodedBytes, alphaThreshold: 1, trim: true)` use `ImageDescriptor`.
Encoded input is limited to **8 MiB**, source dimensions to **16 megapixels**,
and decoded masks to a **256 px longest side**. Buffer, descriptor, codec,
decoded frame and intermediate pictures/images are disposed in `finally`.
The retained alpha image is released by cache eviction or its owner's disposal.

Pixels below `alphaThreshold` (1–255) become transparent. Surviving pixels keep
their original alpha, including partial transparency. `trim: true` crops to the
surviving pixels; `false` preserves the original canvas proportions and margins.
The normalized `containsUnit` test samples this bounded alpha array.

An entirely transparent/thresholded-away image is an error. A **fully opaque
image is a rectangle**, regardless of its colors. There is no background removal,
color segmentation, or promise to recover a logo silhouette from an opaque photo.
The byte decoder uses the first frame if its supported encoded input is animated;
it does not animate the mask. Small features can be lost at the resolution cap.

Raster masks use their alpha image with `dstOut`. **Edge, glow and feather are
vector-only and are ignored for raster sources**, even when configured.
Preserve/dissolve keep the alpha silhouette; morph adds the same growing circle
used by vectors. A custom completion callback receives the raster's placement
rectangle as `shapePath`; its returned vector path explicitly overrides the
raster cutout. The final old-frame fade still guarantees a transparent endpoint.

## Icons

Icons use `TextPainter` with the supplied font family/package/fallbacks, then
trim their alpha to tight bounds. Load custom fonts before resolving, and enable
`uses-material-design: true` in a Material Icons application. The mask uses the
upright LTR glyph; no font-outline parsing or automatic custom-font loading occurs.

Empty masks and masks matching the font's missing-glyph replacement are rejected.
Flutter does not expose a general font-family-availability query: a fallback font
that actually contains the requested glyph may render it. Verify custom font
loading rather than treating rasterization as proof of the font's identity.

## SVG support

Input is limited to **1 MiB UTF-8 and 2000 XML elements**. Parsing uses `xml` and
`path_drawing`; it has no script execution, network loading, CSS engine, or
`flutter_svg` dependency. DOCTYPE and ENTITY declarations are rejected.

Supported:

- `path`, `rect` (independent `rx`/`ry`), `circle`, `ellipse`, `polygon`, and filled
  `polyline`. Filled open contours close according to SVG fill semantics.
- Nested `g` transforms: `matrix`, `translate`, `scale`, `rotate` with optional
  center, `skewX`, and `skewY`, in SVG composition order.
- Inherited `fill` and `fill-rule`, inline style declarations, `fill="none"`, and
  `display:none`. Fill color does not select foreground/background regions.
- `viewBox` framing and clipping; numeric/px root width/height when no viewBox is
  supplied. Framing preserves intentional margins. Without a frame, content
  bounds normalize as ordinary vector paths.
- Geometry union with `Path.combine`, preserving even-odd holes within paths.

Skipped and collected in the immutable `ResolvedShape.warnings` list:

- Gradient/resource fills as geometry; definitions are never painted.
- `clipPath`, `mask`, `filter`, `use`, `text`, stroke-only geometry, nested SVG
  viewports, images, scripts, stylesheets, and other unsupported elements.
- Geometry affected by `clip-path`, `mask`, or `filter` is skipped completely,
  rather than silently painting its unclipped/unfiltered bounds.

Only the filled silhouette is used. CSS selectors, external resources, percentage
lengths, patterns, marker/stroke expansion, opacity/color rendering, and SVG
animation are not supported. Convert artwork requiring those features to a
transparent PNG first. A document with no supported filled geometry is an error.

## JSON schema

Input is limited to **1 MiB UTF-8 and 2000 paths**. Unknown fields, invalid types,
non-finite values, unsupported names, invalid path data and empty geometry are
errors. JSON is data only; it cannot contain executable builders.

Path document (`viewBox` is optional):

```json
{
  "type": "path",
  "viewBox": [0, 0, 100, 100],
  "paths": [
    {
      "d": "M50 5 L95 90 L5 90 Z",
      "fillRule": "nonZero",
      "transform": "rotate(10 50 50)"
    }
  ]
}
```

`paths` contains 1–2000 objects. Each requires a non-empty SVG `d` string.
`fillRule` is `nonZero` (default) or `evenOdd`. Optional `transform` is an SVG
transform string or a six-number affine array `[a,b,c,d,e,f]`. Elements union
with `Path.combine`. A viewBox is `[x,y,positiveWidth,positiveHeight]`; it clips
and frames the geometry before normalization.

Predefined document:

```json
{
  "type": "shape",
  "shape": "star",
  "parameters": {"points": 5, "innerRadius": 0.45},
  "viewBox": [0, 0, 100, 100]
}
```

`parameters` and `viewBox` are optional. The shape fits inside the viewBox when
provided. Names and parameter keys are:

- `circle`, `triangle`, `heart`, `diamond`, `hexagon`: no parameters.
- `ellipse`, `rectangle`: `aspectRatio` (default 1.5).
- `roundedRectangle`: `aspectRatio` (1.5), `cornerRadius` (0.16).
- `star`: integer `points` (5), `innerRadius` (0.45).
- `polygon`: integer `sides` (6).

Factory validation also applies: aspect ratio must be finite/positive, normalized
corner radius non-negative, star points 2–512 with 0 < innerRadius < 1, polygon
sides 3–512. SVG/JSON geometry normalizes so the longest framing side is 1 and
its center is (0,0).

Lottie documents are detected and rejected with a message to export a frame as
PNG/SVG. Lottie playback and frame extraction are not implemented in 0.1.0.
