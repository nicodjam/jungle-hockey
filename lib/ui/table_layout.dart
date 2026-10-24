import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../game/config.dart';

/// Passage coordonnées écran ↔ coordonnées table.
///
/// La table (bandes comprises) est centrée et mise à l'échelle pour tenir
/// dans l'écran en conservant son ratio.
class TableLayout {
  const TableLayout._(this.scale, this.origin);

  /// Épaisseur des bandes (le décor de végétation), en unités table.
  static const double rail = 100;

  factory TableLayout.fit(Size size) {
    const totalWidth = GameConfig.tableWidth + 2 * rail;
    const totalHeight = GameConfig.tableHeight + 2 * rail;
    final scale = math.min(size.width / totalWidth, size.height / totalHeight);
    final origin = Offset(
      (size.width - GameConfig.tableWidth * scale) / 2,
      (size.height - GameConfig.tableHeight * scale) / 2,
    );
    return TableLayout._(scale, origin);
  }

  /// Pixels logiques par unité table.
  final double scale;

  /// Position écran du coin haut-gauche de la surface de jeu.
  final Offset origin;

  Offset toTable(Offset screen) => (screen - origin) / scale;
}
