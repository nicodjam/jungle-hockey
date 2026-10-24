/// Constantes du jeu, exprimées en unités « table ».
///
/// Le rendu met la table à l'échelle de l'écran : toute la physique est
/// indépendante de la résolution.
abstract final class GameConfig {
  /// Surface de jeu de 1720 × 1000 unités : avec les bandes (100 de chaque
  /// côté, voir TableLayout.rail) l'ensemble fait 1920 × 1200, soit
  /// exactement 16:10, le format de la Galaxy Tab S11. Le plateau remplit
  /// donc tout l'écran, sans bandes noires.
  static const double tableWidth = 1720;
  static const double tableHeight = 1000;

  /// Largeur de l'ouverture des buts (sur les petits côtés).
  static const double goalWidth = 360;

  static const double puckRadius = 30;
  static const double malletRadius = 52;

  /// Un doigt saisit un maillet s'il se pose à moins de
  /// malletRadius × malletGrabTolerance de son centre : un peu de marge
  /// autour du disque, la pulpe du doigt cachant le maillet.
  static const double malletGrabTolerance = 1.25;

  /// Coefficient de restitution palet / bandes.
  static const double wallRestitution = 0.9;

  /// Coefficient de restitution palet / maillet.
  static const double malletRestitution = 0.95;

  /// Amortissement exponentiel de la vitesse du palet (par seconde).
  /// 0.3 → le palet perd environ 26 % de sa vitesse par seconde.
  static const double puckDamping = 0.3;

  static const double maxPuckSpeed = 3400;
  static const double maxMalletSpeed = 4200;

  /// Sous-pas de simulation par image, pour éviter que le palet
  /// traverse un maillet à grande vitesse.
  static const int substeps = 6;

  /// Pas de temps maximal accepté pour une image (évite les sauts
  /// après une mise en arrière-plan).
  static const double maxFrameDt = 1 / 20;

  /// Durée de la pause après un but, en secondes.
  static const double goalPause = 1.2;

  static const int defaultTargetScore = 7;

  // --- Pouvoirs -------------------------------------------------------------

  /// Durée d'un pouvoir, en secondes.
  static const double powerDuration = 5;

  static const double itemRadius = 42;

  /// Nombre maximal d'objets présents en même temps sur le terrain.
  static const int maxItems = 2;

  /// Délai entre deux apparitions d'objet (tiré au hasard dans cet intervalle).
  static const double itemSpawnMin = 4;
  static const double itemSpawnMax = 8;

  /// Un objet non ramassé disparaît au bout de ce temps.
  static const double itemLifetime = 14;

  /// TURBO : vitesse des tirs et vitesse max multipliées.
  static const double boostFactor = 1.5;

  /// FREIN ADVERSE : vitesse des tirs adverses et vitesse max multipliées.
  static const double slowFactor = 0.5;

  /// TÊTE CHERCHEUSE : vitesse de rotation vers le but (par seconde)
  /// et vitesse minimale du palet guidé.
  static const double homingTurnRate = 8;
  static const double homingMinSpeed = 1200;

  /// MAILLET GÉANT : rayon des maillets de l'équipe multiplié.
  static const double bigMalletFactor = 1.6;

  /// CAGE ADVERSE GÉANTE / CAGE RÉTRÉCIE : largeur du but multipliée.
  /// Les deux se cumulent sur un même but (360 × 1,6 × 0,55 ≈ 317).
  static const double bigGoalFactor = 1.6;
  static const double smallGoalFactor = 0.55;

  /// Mode ÉQUILIBRAGE : par point d'avance, les tirs de l'équipe qui mène
  /// perdent balanceStep de leur vitesse (jusqu'à balanceMin) et ceux de
  /// l'équipe menée en gagnent autant (jusqu'à balanceMax).
  static const double balanceStep = 0.08;
  static const double balanceMin = 0.6;
  static const double balanceMax = 1.4;

  /// BROUILLARD : bande centrale couverte, en fraction de la largeur
  /// (de 0.5 - fogHalfWidth à 0.5 + fogHalfWidth).
  static const double fogHalfWidth = 0.2;

  /// Vitesse des transitions (croissance des maillets, arrivée de la brume),
  /// par seconde.
  static const double powerTransitionRate = 4;
}
