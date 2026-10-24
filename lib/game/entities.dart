import 'dart:ui' show Offset;

/// Camp d'un joueur : gauche ou droite de la table (tablette en paysage).
enum Side {
  left,
  right;

  Side get opponent => this == Side.left ? Side.right : Side.left;
}

class Puck {
  Puck({required this.position, required this.radius});

  Offset position;
  Offset velocity = Offset.zero;
  final double radius;
}

class Mallet {
  Mallet({
    required this.side,
    required this.index,
    required this.home,
    required this.baseRadius,
  })  : radius = baseRadius,
        position = home,
        target = home;

  final Side side;

  /// Rang du joueur dans son équipe (0 ou 1 en 2 contre 2).
  final int index;

  /// Position de départ.
  final Offset home;

  /// Rayon normal du maillet.
  final double baseRadius;

  /// Rayon courant (agrandi par le pouvoir MAILLET GÉANT).
  double radius;

  Offset position;

  /// Position visée (le doigt du joueur). Le maillet la rejoint à vitesse
  /// bornée, ce qui donne une vitesse exploitable pour les chocs.
  Offset target;

  /// Vitesse instantanée, calculée à chaque sous-pas.
  Offset velocity = Offset.zero;

  /// Identifiant du doigt qui tient ce maillet, ou null s'il est libre.
  int? pointer;

  /// Écart doigt → centre du maillet au moment de la saisie : le maillet
  /// garde cet écart et ne « saute » pas sous le doigt.
  Offset grabOffset = Offset.zero;

  bool get isGrabbed => pointer != null;

  void reset() {
    radius = baseRadius;
    position = home;
    target = home;
    velocity = Offset.zero;
    pointer = null;
    grabOffset = Offset.zero;
  }
}
