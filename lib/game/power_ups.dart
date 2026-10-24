import 'dart:ui' show Offset;

import 'entities.dart';

/// Pouvoirs obtenus en touchant un objet du terrain par un tir direct.
enum PowerType {
  /// Les tirs du joueur partent plus vite (et la vitesse max est relevée).
  speedBoost('TURBO'),

  /// Les tirs de l'adversaire sont ralentis.
  opponentSlow('FREIN ADVERSE'),

  /// Après un tir du joueur, le palet s'oriente vers le milieu du but adverse.
  homing('TÊTE CHERCHEUSE'),

  /// Les maillets de l'équipe grossissent.
  bigMallet('MAILLET GÉANT'),

  /// Le centre du terrain se couvre de brume : le palet y devient
  /// presque invisible, pour tout le monde.
  fog('BROUILLARD'),

  /// La cage de l'adversaire s'agrandit.
  bigOpponentGoal('CAGE ADVERSE GÉANTE'),

  /// La cage de l'équipe rétrécit.
  smallGoal('CAGE RÉTRÉCIE');

  const PowerType(this.label);

  final String label;
}

/// Objet posé sur le terrain, en attente d'être touché.
class PowerItem {
  PowerItem({required this.type, required this.position});

  final PowerType type;
  final Offset position;

  /// Temps écoulé depuis son apparition, en secondes.
  double age = 0;
}

/// Pouvoir en cours pour une équipe.
class ActivePower {
  ActivePower(this.type, this.remaining) : duration = remaining;

  final PowerType type;
  final double duration;

  /// Temps restant, en secondes.
  double remaining;

  double get progress => duration <= 0 ? 0 : (remaining / duration).clamp(0.0, 1.0);
}

/// Onde visuelle laissée par un objet ramassé.
class PickupBurst {
  PickupBurst({required this.type, required this.position, required this.side});

  final PowerType type;
  final Offset position;
  final Side side;
  double age = 0;
}
