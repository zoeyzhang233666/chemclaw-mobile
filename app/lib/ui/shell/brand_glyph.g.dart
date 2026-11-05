// ChemClaw Mobile vector master from chemclaw-bot/src/shared/brand.js.
// ChemClaw cloud silhouette (Apache-2.0); do not regenerate via upstream fish-tail script.
import 'dart:ui' show Offset, Path, Rect;

/// Shared cloud geometry used by the Flutter UI and the icon preview.
abstract final class BrandGlyph {
  static const box = Rect.fromLTRB(4, 6.5, 29, 23.5);
  static const aspect = 25.0 / 17.0;
  static const centroid = Offset(16.2988, 16.2311);
  static const tileBox = Rect.fromLTWH(0, 0, 34, 34);

  static final Path cloud = Path()
    ..moveTo(8.5, 23.5)
    ..lineTo(23.7, 23.5)
    ..cubicTo(26.6, 23.5, 29.0, 21.3, 29.0, 18.4)
    ..cubicTo(29.0, 15.7, 27.0, 13.5, 24.4, 13.2)
    ..cubicTo(23.8, 9.4, 20.5, 6.5, 16.5, 6.5)
    ..cubicTo(13.3, 6.5, 10.5, 8.4, 9.2, 11.1)
    ..cubicTo(6.6, 11.4, 4.0, 14.0, 4.0, 17.2)
    ..cubicTo(4.0, 20.7, 6.7, 23.5, 8.5, 23.5)
    ..close();

  // Compatibility aliases for legacy tests and UI surfaces.
  static final Path body = cloud;
  static final Path bubble = Path();
  static final Path fin = Path();
  static final Path belly = Path();
}
