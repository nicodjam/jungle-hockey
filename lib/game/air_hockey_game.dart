import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'config.dart';
import 'entities.dart';
import 'power_ups.dart';

enum GamePhase { playing, goal, paused, finished }

enum GameEvent { wallHit, malletHit, goal, victory, powerUp }

/// Callback d'événement de jeu. [intensity] est compris entre 0 et 1
/// (vitesse d'impact rapportée à la vitesse max) ; il vaut 1 pour un but.
typedef GameEventCallback = void Function(GameEvent event, double intensity);

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

/// État et physique d'une partie d'air hockey.
///
/// Toutes les coordonnées sont en unités table (voir [GameConfig]).
/// La classe ne dépend d'aucun widget : elle est pilotée par [update]
/// et par les méthodes `pointer*`, ce qui la rend testable en isolation.
class AirHockeyGame extends ChangeNotifier {
  AirHockeyGame({
    this.playersPerSide = 1,
    this.targetScore = GameConfig.defaultTargetScore,
    this.powerUpsEnabled = true,
    this.balanceEnabled = false,
    this.onEvent,
    math.Random? random,
  })  : assert(playersPerSide >= 1 && playersPerSide <= 2),
        _random = random ?? math.Random() {
    puck = Puck(position: center, radius: GameConfig.puckRadius);
    for (final side in Side.values) {
      for (var i = 0; i < playersPerSide; i++) {
        mallets.add(Mallet(
          side: side,
          index: i,
          home: homeFor(side, i, playersPerSide),
          baseRadius: GameConfig.malletRadius,
        ));
      }
    }
    _resetSpawnTimer();
  }

  static const double width = GameConfig.tableWidth;
  static const double height = GameConfig.tableHeight;
  static const Offset center = Offset(width / 2, height / 2);

  final int playersPerSide;
  final int targetScore;
  final bool powerUpsEnabled;

  /// Mode équilibrage : les tirs de l'équipe qui mène sont ralentis, ceux
  /// de l'équipe menée accélérés, d'autant plus que l'écart est grand.
  final bool balanceEnabled;
  GameEventCallback? onEvent;
  final math.Random _random;

  late final Puck puck;
  final List<Mallet> mallets = [];

  final Map<Side, int> _score = {Side.left: 0, Side.right: 0};
  int scoreOf(Side side) => _score[side]!;

  GamePhase _phase = GamePhase.playing;
  GamePhase get phase => _phase;
  GamePhase _phaseBeforePause = GamePhase.playing;

  Side? _winner;
  Side? get winner => _winner;

  Side? _lastScorer;
  Side? get lastScorer => _lastScorer;

  double _goalTimer = 0;
  Side _serveTo = Side.left;

  /// Temps de jeu écoulé (hors pause), pour les animations.
  double _time = 0;
  double get time => _time;

  /// Le palet n'est pas affiché entre un but et la remise en jeu.
  bool get puckVisible =>
      _phase != GamePhase.goal && _phase != GamePhase.finished;

  // --- Pouvoirs ---

  final List<PowerItem> _items = [];
  List<PowerItem> get items => List.unmodifiable(_items);

  final List<PickupBurst> _bursts = [];
  List<PickupBurst> get bursts => List.unmodifiable(_bursts);

  /// Pouvoirs en cours, par équipe. Ils se cumulent (un de chaque type au
  /// plus) ; reprendre un pouvoir déjà actif remet son temps à zéro.
  final Map<Side, List<ActivePower>> _powers = {Side.left: [], Side.right: []};

  /// Pouvoirs en cours de [side], dans l'ordre où ils ont été obtenus.
  List<ActivePower> powersOf(Side side) => List.unmodifiable(_powers[side]!);

  /// Pouvoir [type] de [side] s'il est actif, sinon null.
  ActivePower? powerOf(Side side, PowerType type) {
    for (final p in _powers[side]!) {
      if (p.type == type) return p;
    }
    return null;
  }

  bool hasPower(Side side, PowerType type) => powerOf(side, type) != null;

  /// Équipe qui a frappé le palet en dernier (null après une remise en jeu).
  Side? _lastHitBy;
  Side? get lastHitBy => _lastHitBy;

  double _spawnTimer = 0;

  bool _hasPower(Side side, PowerType type) => hasPower(side, type);

  /// Pouvoir actif chez l'une ou l'autre équipe (effets qui touchent tout
  /// le monde : brouillard).
  bool _anyPower(PowerType type) =>
      _hasPower(Side.left, type) || _hasPower(Side.right, type);

  /// Densité du brouillard central, de 0 (absent) à 1 (opaque).
  double _fogLevel = 0;
  double get fogLevel => _fogLevel;

  /// Largeur courante du but de chaque équipe (le but qu'elle défend).
  final Map<Side, double> _goalWidth = {
    Side.left: GameConfig.goalWidth,
    Side.right: GameConfig.goalWidth,
  };
  double goalWidthOf(Side side) => _goalWidth[side]!;

  /// Largeur visée pour le but de [side] : agrandi si l'adversaire a
  /// CAGE ADVERSE GÉANTE, rétréci si [side] a CAGE RÉTRÉCIE.
  double _targetGoalWidth(Side side) {
    var w = GameConfig.goalWidth;
    if (_hasPower(side.opponent, PowerType.bigOpponentGoal)) w *= GameConfig.bigGoalFactor;
    if (_hasPower(side, PowerType.smallGoal)) w *= GameConfig.smallGoalFactor;
    return w;
  }

  /// Effet visible sur le palet en ce moment (pour le rendu), ou null.
  PowerType? get puckEffect {
    final shooter = _lastHitBy;
    if (shooter == null) return null;
    if (_hasPower(shooter, PowerType.homing)) return PowerType.homing;
    if (_hasPower(shooter, PowerType.speedBoost)) return PowerType.speedBoost;
    if (_hasPower(shooter.opponent, PowerType.opponentSlow)) {
      return PowerType.opponentSlow;
    }
    return null;
  }

  /// Multiplicateur de l'équilibrage pour les tirs de [side] : 1 sans
  /// écart (ou mode désactivé), moins de 1 si [side] mène, plus de 1 s'il
  /// est mené.
  double balanceFactor(Side side) {
    if (!balanceEnabled) return 1;
    final lead = scoreOf(side) - scoreOf(side.opponent);
    final f = 1 - GameConfig.balanceStep * lead;
    return f.clamp(GameConfig.balanceMin, GameConfig.balanceMax);
  }

  /// Multiplicateur appliqué aux tirs de [shooter] (vitesse et plafond) :
  /// équilibrage et pouvoirs se multiplient.
  double _shotFactor(Side shooter) {
    var f = balanceFactor(shooter);
    if (_hasPower(shooter, PowerType.speedBoost)) f *= GameConfig.boostFactor;
    if (_hasPower(shooter.opponent, PowerType.opponentSlow)) {
      f *= GameConfig.slowFactor;
    }
    return f;
  }

  // ---------------------------------------------------------------------------
  // Géométrie
  // ---------------------------------------------------------------------------

  static Offset homeFor(Side side, int index, int perSide) {
    final y = perSide == 1 ? height / 2 : (index == 0 ? height * 0.3 : height * 0.7);
    const x = width * 0.14;
    return side == Side.left ? Offset(x, y) : Offset(width - x, y);
  }

  /// Contraint un maillet à son demi-terrain.
  static Offset clampToHalf(Side side, double radius, Offset p) {
    final minX = side == Side.left ? radius : width / 2 + radius;
    final maxX = side == Side.left ? width / 2 - radius : width - radius;
    return Offset(
      p.dx.clamp(minX, maxX),
      p.dy.clamp(radius, height - radius),
    );
  }

  /// Milieu du but attaqué par [side].
  static Offset targetGoalOf(Side side) =>
      Offset(side == Side.left ? width : 0, height / 2);

  // ---------------------------------------------------------------------------
  // Entrées tactiles (coordonnées table)
  // ---------------------------------------------------------------------------

  /// Un doigt se pose : il saisit le maillet libre sur lequel il est posé
  /// (le plus proche si deux se touchent). Un doigt posé ailleurs ne fait
  /// rien. Retourne true si un maillet a été saisi.
  bool pointerDown(int pointer, Offset p) {
    if (_phase == GamePhase.finished) return false;
    Mallet? best;
    var bestDistance = double.infinity;
    for (final m in mallets) {
      if (m.isGrabbed) continue;
      final reach = m.radius * GameConfig.malletGrabTolerance;
      final d = (m.position - p).distanceSquared;
      if (d <= reach * reach && d < bestDistance) {
        bestDistance = d;
        best = m;
      }
    }
    if (best == null) return false;
    best
      ..pointer = pointer
      ..grabOffset = best.position - p
      ..target = best.position;
    return true;
  }

  void pointerMove(int pointer, Offset p) {
    final m = _malletFor(pointer);
    if (m == null) return;
    m.target = clampToHalf(m.side, m.radius, p + m.grabOffset);
  }

  /// Le doigt se lève : le maillet reste où il est.
  void pointerUp(int pointer) {
    final m = _malletFor(pointer);
    if (m == null) return;
    m.pointer = null;
    m.target = m.position;
  }

  Mallet? _malletFor(int pointer) {
    for (final m in mallets) {
      if (m.pointer == pointer) return m;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Contrôle de partie
  // ---------------------------------------------------------------------------

  void pause() {
    if (_phase == GamePhase.paused || _phase == GamePhase.finished) return;
    _phaseBeforePause = _phase;
    _phase = GamePhase.paused;
    notifyListeners();
  }

  void resume() {
    if (_phase != GamePhase.paused) return;
    _phase = _phaseBeforePause;
    notifyListeners();
  }

  void restart() {
    _score[Side.left] = 0;
    _score[Side.right] = 0;
    _winner = null;
    _lastScorer = null;
    _goalTimer = 0;
    for (final m in mallets) {
      m.reset();
    }
    puck
      ..position = center
      ..velocity = Offset.zero;
    _items.clear();
    _bursts.clear();
    _powers[Side.left]!.clear();
    _powers[Side.right]!.clear();
    _lastHitBy = null;
    _fogLevel = 0;
    _goalWidth[Side.left] = GameConfig.goalWidth;
    _goalWidth[Side.right] = GameConfig.goalWidth;
    _resetSpawnTimer();
    _phase = GamePhase.playing;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Simulation
  // ---------------------------------------------------------------------------

  /// Avance la simulation de [dt] secondes.
  void update(double dt) {
    if (dt <= 0) return;
    if (_phase == GamePhase.paused || _phase == GamePhase.finished) return;
    dt = math.min(dt, GameConfig.maxFrameDt);
    _time += dt;

    if (_phase == GamePhase.goal) {
      _goalTimer -= dt;
      if (_goalTimer <= 0) {
        _servePuck();
        _phase = GamePhase.playing;
      }
    }

    if (_phase == GamePhase.playing) _updatePowerUps(dt);
    _updateBursts(dt);
    _updateTransitions(dt);

    final h = dt / GameConfig.substeps;
    for (var i = 0; i < GameConfig.substeps; i++) {
      _stepMallets(h);
      if (_phase == GamePhase.playing) _stepPuck(h);
    }
    notifyListeners();
  }

  void _stepMallets(double h) {
    final previous = [for (final m in mallets) m.position];
    final maxStep = GameConfig.maxMalletSpeed * h;

    for (final m in mallets) {
      final delta = m.target - m.position;
      final distance = delta.distance;
      final move = distance <= maxStep ? delta : delta * (maxStep / distance);
      m.position = clampToHalf(m.side, m.radius, m.position + move);
    }

    _separateTeammates();

    for (var i = 0; i < mallets.length; i++) {
      mallets[i].velocity = (mallets[i].position - previous[i]) / h;
    }
  }

  /// En 2 contre 2, empêche deux maillets d'une même équipe de se chevaucher.
  void _separateTeammates() {
    for (var i = 0; i < mallets.length; i++) {
      for (var j = i + 1; j < mallets.length; j++) {
        final a = mallets[i];
        final b = mallets[j];
        if (a.side != b.side) continue;
        final d = b.position - a.position;
        final minDistance = a.radius + b.radius;
        final distance = d.distance;
        if (distance >= minDistance) continue;
        final n = distance > 1e-6 ? d / distance : const Offset(0, 1);
        final push = (minDistance - distance) / 2;
        a.position = clampToHalf(a.side, a.radius, a.position - n * push);
        b.position = clampToHalf(b.side, b.radius, b.position + n * push);
      }
    }
  }

  void _stepPuck(double h) {
    final r = puck.radius;
    final previous = puck.position;
    var v = puck.velocity * math.exp(-GameConfig.puckDamping * h);

    // --- TÊTE CHERCHEUSE : le palet s'oriente vers le but adverse ---
    final shooter = _lastHitBy;
    if (shooter != null && _hasPower(shooter, PowerType.homing)) {
      final toGoal = targetGoalOf(shooter) - previous;
      final distance = toGoal.distance;
      if (distance > 1) {
        final speed = math.max(v.distance, GameConfig.homingMinSpeed);
        final desired = toGoal * (speed / distance);
        final t = math.min(1.0, GameConfig.homingTurnRate * h);
        final steered = Offset.lerp(v, desired, t)!;
        final steeredSpeed = steered.distance;
        v = steeredSpeed > 1e-6 ? steered * (speed / steeredSpeed) : desired;
      }
    }

    var p = previous + v * h;

    // --- Chocs avec les maillets (masse infinie) ---
    for (final m in mallets) {
      final d = p - m.position;
      final minDistance = r + m.radius;
      final d2 = d.distanceSquared;
      if (d2 >= minDistance * minDistance) continue;
      final distance = math.sqrt(d2);
      final n = distance > 1e-6
          ? d / distance
          : Offset(m.side == Side.left ? 1 : -1, 0);
      p = m.position + n * minDistance;
      final vn = _dot(v - m.velocity, n);
      if (vn < 0) {
        v -= n * ((1 + GameConfig.malletRestitution) * vn);
        v = v * _shotFactor(m.side);
        _lastHitBy = m.side;
        _emit(GameEvent.malletHit, -vn / GameConfig.maxPuckSpeed);
      }
    }

    // --- Bandes haute et basse ---
    if (p.dy < r) {
      p = Offset(p.dx, r);
      if (v.dy < 0) {
        _emit(GameEvent.wallHit, -v.dy / GameConfig.maxPuckSpeed);
        v = Offset(v.dx, -v.dy * GameConfig.wallRestitution);
      }
    } else if (p.dy > height - r) {
      p = Offset(p.dx, height - r);
      if (v.dy > 0) {
        _emit(GameEvent.wallHit, v.dy / GameConfig.maxPuckSpeed);
        v = Offset(v.dx, -v.dy * GameConfig.wallRestitution);
      }
    }

    // --- Petits côtés, avec l'ouverture des buts (largeur propre à
    // chaque but, modifiée par les pouvoirs) ---
    for (final side in Side.values) {
      final isLeft = side == Side.left;
      final pastLine = isLeft ? p.dx < r : p.dx > width - r;
      if (!pastLine) continue;
      final mouthHalf = math.max(0.0, _goalWidth[side]! / 2 - r);
      final mouthTop = height / 2 - mouthHalf;
      final mouthBottom = height / 2 + mouthHalf;
      final inMouth = p.dy >= mouthTop && p.dy <= mouthBottom;
      final wasInSlot = isLeft ? previous.dx < r : previous.dx > width - r;

      if (inMouth || wasInSlot) {
        // Le palet est engagé dans la gorge du but : les poteaux le guident.
        if (p.dy < mouthTop) {
          p = Offset(p.dx, mouthTop);
          if (v.dy < 0) v = Offset(v.dx, -v.dy * GameConfig.wallRestitution);
        } else if (p.dy > mouthBottom) {
          p = Offset(p.dx, mouthBottom);
          if (v.dy > 0) v = Offset(v.dx, -v.dy * GameConfig.wallRestitution);
        }
        final scored = isLeft ? p.dx < -r : p.dx > width + r;
        if (scored) {
          _scoreGoal(side.opponent);
          return;
        }
      } else {
        // Rebond sur la bande.
        p = Offset(isLeft ? r : width - r, p.dy);
        final outward = isLeft ? v.dx < 0 : v.dx > 0;
        if (outward) {
          _emit(GameEvent.wallHit, v.dx.abs() / GameConfig.maxPuckSpeed);
          v = Offset(-v.dx * GameConfig.wallRestitution, v.dy);
        }
      }
    }

    // --- Vitesse maximale (modifiée par les pouvoirs du tireur) ---
    final maxSpeed = GameConfig.maxPuckSpeed *
        (_lastHitBy == null ? 1.0 : _shotFactor(_lastHitBy!));
    final speed = v.distance;
    if (speed > maxSpeed) {
      v = v * (maxSpeed / speed);
    }

    puck
      ..position = p
      ..velocity = v;

    _collectItems();

    // Si une bande a repoussé le palet dans un maillet, c'est le maillet
    // qui recule : le palet ne peut pas être écrasé dans le décor.
    for (final m in mallets) {
      final d = p - m.position;
      final minDistance = r + m.radius;
      final distance = d.distance;
      if (distance >= minDistance || distance < 1e-6) continue;
      final n = d / distance;
      m.position = clampToHalf(m.side, m.radius, p - n * minDistance);
    }
  }

  void _scoreGoal(Side scorer) {
    _score[scorer] = _score[scorer]! + 1;
    _lastScorer = scorer;
    _serveTo = scorer.opponent;
    puck.velocity = Offset.zero;
    _lastHitBy = null;
    _emit(GameEvent.goal, 1);

    if (_score[scorer]! >= targetScore) {
      _winner = scorer;
      _phase = GamePhase.finished;
      for (final m in mallets) {
        m.pointer = null;
        m.target = m.position;
      }
      _emit(GameEvent.victory, 1);
    } else {
      _phase = GamePhase.goal;
      _goalTimer = GameConfig.goalPause;
    }
  }

  /// Remet le palet en jeu dans le camp de l'équipe qui vient d'encaisser.
  void _servePuck() {
    final x = _serveTo == Side.left ? width * 0.3 : width * 0.7;
    puck
      ..position = Offset(x, height / 2)
      ..velocity = Offset.zero;
    _lastHitBy = null;
  }

  // ---------------------------------------------------------------------------
  // Pouvoirs
  // ---------------------------------------------------------------------------

  void _updatePowerUps(double dt) {
    for (final list in _powers.values) {
      for (final power in list) {
        power.remaining -= dt;
      }
      list.removeWhere((power) => power.remaining <= 0);
    }

    if (!powerUpsEnabled) return;

    for (final item in _items) {
      item.age += dt;
    }
    _items.removeWhere((item) => item.age >= GameConfig.itemLifetime);

    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      if (_items.length < GameConfig.maxItems) _spawnItem();
      _resetSpawnTimer();
    }
  }

  /// Maillets qui grossissent ou dégonflent, brume qui arrive ou se lève,
  /// buts qui s'ouvrent ou se ferment : en douceur plutôt que d'un coup.
  void _updateTransitions(double dt) {
    final step = math.min(1.0, GameConfig.powerTransitionRate * dt);
    for (final m in mallets) {
      final target = m.baseRadius *
          (_hasPower(m.side, PowerType.bigMallet) ? GameConfig.bigMalletFactor : 1);
      m.radius += (target - m.radius) * step;
      if ((m.radius - target).abs() < 0.05) m.radius = target;
      m.position = clampToHalf(m.side, m.radius, m.position);
      m.target = clampToHalf(m.side, m.radius, m.target);
    }

    for (final side in Side.values) {
      final target = _targetGoalWidth(side);
      final w = _goalWidth[side]!;
      _goalWidth[side] = (target - w).abs() < 0.1 ? target : w + (target - w) * step;
    }

    final targetFog = _anyPower(PowerType.fog) ? 1.0 : 0.0;
    _fogLevel += (targetFog - _fogLevel) * step;
    if ((_fogLevel - targetFog).abs() < 0.005) _fogLevel = targetFog;
  }

  void _updateBursts(double dt) {
    for (final b in _bursts) {
      b.age += dt;
    }
    _bursts.removeWhere((b) => b.age > 0.6);
  }

  void _resetSpawnTimer() {
    _spawnTimer = GameConfig.itemSpawnMin +
        _random.nextDouble() * (GameConfig.itemSpawnMax - GameConfig.itemSpawnMin);
  }

  /// Pose un objet au hasard, loin des buts, des maillets, du palet et
  /// des autres objets. Abandonne (jusqu'au prochain tirage) s'il ne
  /// trouve pas de place.
  void _spawnItem() {
    const ir = GameConfig.itemRadius;
    const margin = ir + 30;
    for (var attempt = 0; attempt < 30; attempt++) {
      final p = Offset(
        margin + _random.nextDouble() * (width - 2 * margin),
        margin + _random.nextDouble() * (height - 2 * margin),
      );
      if (!_isFreeSpot(p)) continue;
      final type = PowerType.values[_random.nextInt(PowerType.values.length)];
      _items.add(PowerItem(type: type, position: p));
      return;
    }
  }

  bool _isFreeSpot(Offset p) {
    const ir = GameConfig.itemRadius;
    for (final goal in const [Offset(0, height / 2), Offset(width, height / 2)]) {
      if ((p - goal).distance < 280) return false;
    }
    if ((p - puck.position).distance < ir + puck.radius + 80) return false;
    for (final m in mallets) {
      if ((p - m.position).distance < ir + m.radius + 60) return false;
    }
    for (final item in _items) {
      if ((p - item.position).distance < 2 * ir + 120) return false;
    }
    return true;
  }

  /// Quand le palet touche un objet, l'équipe qui l'a frappé en dernier
  /// (rebonds compris) obtient le pouvoir ; l'objet disparaît. Un palet
  /// que personne n'a encore frappé passe dessus sans effet.
  void _collectItems() {
    final shooter = _lastHitBy;
    if (shooter == null) return;
    final reach = GameConfig.itemRadius + puck.radius;
    for (var i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      if ((puck.position - item.position).distanceSquared > reach * reach) {
        continue;
      }
      _items.removeAt(i);
      _grantPower(shooter, item.type, item.position);
    }
  }

  void _grantPower(Side side, PowerType type, Offset at) {
    _addPower(side, type);
    _bursts.add(PickupBurst(type: type, position: at, side: side));
    _emit(GameEvent.powerUp, 1);
  }

  // --- Points d'entrée pour les tests ---

  @visibleForTesting
  void debugAddItem(PowerItem item) => _items.add(item);

  @visibleForTesting
  void debugGrantPower(Side side, PowerType type) => _addPower(side, type);

  @visibleForTesting
  void debugSetScore(Side side, int score) => _score[side] = score;

  /// Simule un tir de [side] : le palet part à [velocity].
  @visibleForTesting
  void debugShoot(Side side, Offset velocity) {
    puck.velocity = velocity;
    _lastHitBy = side;
  }

  /// Ajoute le pouvoir, ou remet à plein le temps d'un pouvoir déjà actif.
  void _addPower(Side side, PowerType type) {
    final existing = powerOf(side, type);
    if (existing != null) {
      existing.remaining = existing.duration;
    } else {
      _powers[side]!.add(ActivePower(type, GameConfig.powerDuration));
    }
  }

  void _emit(GameEvent event, double intensity) {
    onEvent?.call(event, intensity.clamp(0.0, 1.0));
  }
}
