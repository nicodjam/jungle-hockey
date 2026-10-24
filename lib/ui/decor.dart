import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Décor de la table (assets/decor/jungle.webp, dessiné par
/// tool/generate_decor.py) : la surface de jeu et les bandes de végétation,
/// en une seule image plein écran.
///
/// Chargé une fois au démarrage ([load]). S'il manque ou ne se décode pas,
/// [table] reste null et le plateau est dessiné sans décor.
abstract final class Decor {
  static const String asset = 'assets/decor/jungle.webp';

  static ui.Image? _table;
  static ui.Image? get table => _table;

  static Future<void> load() async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _table = (await codec.getNextFrame()).image;
    } catch (e) {
      debugPrint('Decor: cannot load $asset ($e), plain table instead');
    }
  }
}
