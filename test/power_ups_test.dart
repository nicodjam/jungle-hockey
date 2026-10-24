import 'dart:math' show Random;
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:jungle_hockey/game/air_hockey_game.dart';
import 'package:jungle_hockey/game/config.dart';
import 'package:jungle_hockey/game/entities.dart';
import 'package:jungle_hockey/game/power_ups.dart';

const _w = GameConfig.tableWidth;
const _h = GameConfig.tableHeight;

void _run(AirHockeyGame game, {int frames = 1, double dt = 1 / 60}) {
  for (var i = 0; i < frames; i++) {
    game.update(dt);
  }
}

AirHockeyGame _game({GameEventCallback? onEvent}) =>
    AirHockeyGame(random: Random(1), onEvent: onEvent);

/// Frappe du maillet gauche vers la droite sur un palet posé en (400, milieu).
void _leftStrike(AirHockeyGame game) {
  game.puck
    ..position = const Offset(400, _h / 2)
    ..velocity = Offset.zero;
  final mallet = game.mallets.firstWhere((m) => m.side == Side.left);
  game.pointerDown(1, mallet.position);
  game.pointerMove(1, const Offset(700, _h / 2));
}

void main() {
  group('ramassage', () {
    test('un tir direct sur un objet donne le pouvoir au tireur', () {
      final events = <GameEvent>[];
      final game = _game(onEvent: (e, _) => events.add(e));
      game.debugAddItem(PowerItem(type: PowerType.speedBoost, position: const Offset(800, 300)));
      game.puck.position = const Offset(500, 300);
      game.debugShoot(Side.left, const Offset(2000, 0));
      _run(game, frames: 15);

      expect(game.hasPower(Side.left, PowerType.speedBoost), isTrue);
      expect(game.powersOf(Side.right), isEmpty);
      expect(game.items, isEmpty);
      expect(events, contains(GameEvent.powerUp));
    });

    test('après un rebond sur une bande, le dernier tireur prend quand même l\'objet', () {
      final game = _game();
      game.debugAddItem(PowerItem(type: PowerType.homing, position: const Offset(660, 270)));
      game.puck.position = const Offset(500, 60);
      game.debugShoot(Side.left, const Offset(800, -1500));
      _run(game, frames: 20);

      expect(game.items, isEmpty);
      expect(game.hasPower(Side.left, PowerType.homing), isTrue);
    });

    test('un palet que personne n\'a frappé ne ramasse rien', () {
      final game = _game();
      game.debugAddItem(PowerItem(type: PowerType.homing, position: const Offset(800, 300)));
      game.puck
        ..position = const Offset(500, 300)
        ..velocity = const Offset(2000, 0);
      _run(game, frames: 15);

      expect(game.items, hasLength(1));
      expect(game.powersOf(Side.left), isEmpty);
      expect(game.powersOf(Side.right), isEmpty);
    });

    test('des objets apparaissent pendant la partie', () {
      final game = _game();
      _run(game, frames: 60 * 10);
      expect(game.items, isNotEmpty);
    });

    test('aucun objet si les pouvoirs sont désactivés', () {
      final game = AirHockeyGame(random: Random(1), powerUpsEnabled: false);
      _run(game, frames: 60 * 10);
      expect(game.items, isEmpty);
    });
  });

  test('un pouvoir dure 5 secondes', () {
    final game = _game();
    game.debugGrantPower(Side.left, PowerType.homing);
    _run(game, frames: 294); // 4,9 s
    expect(game.hasPower(Side.left, PowerType.homing), isTrue);
    _run(game, frames: 12);
    expect(game.powersOf(Side.left), isEmpty);
  });

  group('cumul', () {
    test('une équipe cumule des pouvoirs différents', () {
      final game = _game();
      game.debugGrantPower(Side.left, PowerType.fog);
      _run(game, frames: 60); // 1 s
      game.debugGrantPower(Side.left, PowerType.speedBoost);
      expect(game.powersOf(Side.left).map((p) => p.type),
          [PowerType.fog, PowerType.speedBoost]);

      // Brouillard actif ET tir turbo.
      _leftStrike(game);
      _run(game, frames: 6);
      expect(game.fogLevel, greaterThan(0.95));
      expect(game.puck.velocity.distance, greaterThan(GameConfig.maxPuckSpeed));

      // Palet immobilisé loin des buts : pas de pause de but qui figerait
      // les chronos pendant la suite.
      game.puck
        ..position = const Offset(_w / 2, 200)
        ..velocity = Offset.zero;

      // Chacun garde son propre chrono : le brouillard (3,9 s restantes)
      // expire avant le turbo (4,9 s restantes).
      _run(game, frames: 60 * 4);
      expect(game.hasPower(Side.left, PowerType.fog), isFalse);
      expect(game.hasPower(Side.left, PowerType.speedBoost), isTrue);
    });

    test('reprendre un pouvoir déjà actif remet son temps à zéro', () {
      final game = _game();
      game.debugGrantPower(Side.left, PowerType.fog);
      _run(game, frames: 60 * 3);
      game.debugGrantPower(Side.left, PowerType.fog);
      expect(game.powersOf(Side.left), hasLength(1));
      expect(game.powerOf(Side.left, PowerType.fog)!.remaining, GameConfig.powerDuration);
    });
  });

  group('effets', () {
    test('TURBO : le tir dépasse la vitesse max normale', () {
      final game = _game();
      game.debugGrantPower(Side.left, PowerType.speedBoost);
      _leftStrike(game);
      _run(game, frames: 6);
      expect(game.lastHitBy, Side.left);
      expect(game.puck.velocity.distance, greaterThan(GameConfig.maxPuckSpeed));
    });

    test('FREIN ADVERSE : le tir de l\'adversaire est ralenti', () {
      final game = _game();
      game.debugGrantPower(Side.right, PowerType.opponentSlow);
      _leftStrike(game);
      _run(game, frames: 6);
      expect(game.lastHitBy, Side.left);
      final speed = game.puck.velocity.distance;
      expect(speed, greaterThan(0));
      expect(speed, lessThanOrEqualTo(GameConfig.maxPuckSpeed * GameConfig.slowFactor + 1e-6));
    });

    test('TÊTE CHERCHEUSE : un tir parti à l\'opposé finit dans le but adverse', () {
      final game = _game();
      game.debugGrantPower(Side.left, PowerType.homing);

      // Le défenseur adverse s'écarte du but.
      final keeper = game.mallets.firstWhere((m) => m.side == Side.right);
      game.pointerDown(2, keeper.position);
      game.pointerMove(2, Offset(_w - 230, 120));

      game.puck.position = const Offset(500, 250);
      game.debugShoot(Side.left, const Offset(0, -1500)); // vers le haut
      _run(game, frames: 120);

      expect(game.scoreOf(Side.left), 1);
    });

    test('MAILLET GÉANT : les maillets de l\'équipe grossissent puis reprennent leur taille', () {
      final game = _game();
      const base = GameConfig.malletRadius;
      game.debugGrantPower(Side.right, PowerType.bigMallet);
      _run(game, frames: 60);
      for (final m in game.mallets) {
        final expected = m.side == Side.right ? base * GameConfig.bigMalletFactor : base;
        expect(m.radius, closeTo(expected, 0.5));
      }
      expect(game.puck.radius, GameConfig.puckRadius);

      _run(game, frames: 60 * 6); // pouvoir expiré + transition
      for (final m in game.mallets) {
        expect(m.radius, base);
      }
    });

    test('MAILLET GÉANT : un maillet agrandi reste dans son camp', () {
      final game = _game();
      final mallet = game.mallets.firstWhere((m) => m.side == Side.left);
      game.pointerDown(1, mallet.position);
      game.pointerMove(1, const Offset(_w, 500));
      _run(game, frames: 30);
      game.debugGrantPower(Side.left, PowerType.bigMallet);
      _run(game, frames: 60);
      expect(mallet.position.dx + mallet.radius, lessThanOrEqualTo(_w / 2 + 1e-6));
    });

    test('BROUILLARD : la brume monte puis se dissipe', () {
      final game = _game();
      expect(game.fogLevel, 0);
      game.debugGrantPower(Side.left, PowerType.fog);
      _run(game, frames: 60);
      expect(game.fogLevel, greaterThan(0.95));

      _run(game, frames: 60 * 6);
      expect(game.fogLevel, 0);
    });

    test('recommencer efface maillet géant et brouillard', () {
      final game = _game();
      game.debugGrantPower(Side.left, PowerType.fog);
      game.debugGrantPower(Side.right, PowerType.bigMallet);
      _run(game, frames: 60);
      game.restart();
      expect(game.fogLevel, 0);
      expect(game.powersOf(Side.left), isEmpty);
      for (final m in game.mallets) {
        expect(m.radius, GameConfig.malletRadius);
      }
    });

    group('cages', () {
      /// Tire le palet vers le but de [side] à la hauteur [y].
      void shootAt(AirHockeyGame game, Side side, double y) {
        final left = side == Side.left;
        game.puck
          ..position = Offset(left ? 150 : _w - 150, y)
          ..velocity = Offset(left ? -2000 : 2000, 0);
        _run(game, frames: 20);
      }

      test('CAGE ADVERSE GÉANTE : seul le but adverse s\'agrandit', () {
        final game = _game();
        game.debugGrantPower(Side.left, PowerType.bigOpponentGoal);
        _run(game, frames: 120); // transition terminée
        expect(game.goalWidthOf(Side.right),
            closeTo(GameConfig.goalWidth * GameConfig.bigGoalFactor, 0.5));
        expect(game.goalWidthOf(Side.left), GameConfig.goalWidth);
      });

      test('CAGE ADVERSE GÉANTE : un tir décentré marque', () {
        const y = _h / 2 + 220; // hors du but normal
        final control = _game();
        shootAt(control, Side.right, y);
        expect(control.scoreOf(Side.left), 0);

        final game = _game();
        game.debugGrantPower(Side.left, PowerType.bigOpponentGoal);
        _run(game, frames: 120); // transition terminée
        shootAt(game, Side.right, y);
        expect(game.scoreOf(Side.left), 1);
      });

      test('CAGE RÉTRÉCIE : le but de l\'équipe se referme et repousse le palet', () {
        const y = _h / 2 + 120; // dans le but normal
        final control = _game();
        shootAt(control, Side.left, y);
        expect(control.scoreOf(Side.right), 1);

        final game = _game();
        game.debugGrantPower(Side.left, PowerType.smallGoal);
        _run(game, frames: 120); // transition terminée
        expect(game.goalWidthOf(Side.left),
            closeTo(GameConfig.goalWidth * GameConfig.smallGoalFactor, 0.5));
        expect(game.goalWidthOf(Side.right), GameConfig.goalWidth);
        shootAt(game, Side.left, y);
        expect(game.scoreOf(Side.right), 0);
        expect(game.puck.velocity.dx, greaterThan(0));
      });

      test('les deux effets se cumulent sur un même but, puis tout revient', () {
        final game = _game();
        game.debugGrantPower(Side.left, PowerType.bigOpponentGoal);
        game.debugGrantPower(Side.right, PowerType.smallGoal);
        _run(game, frames: 120); // transition terminée
        expect(game.goalWidthOf(Side.right),
            closeTo(GameConfig.goalWidth * GameConfig.bigGoalFactor * GameConfig.smallGoalFactor, 0.5));

        game.puck
          ..position = const Offset(_w / 2, 200)
          ..velocity = Offset.zero;
        _run(game, frames: 60 * 6);
        expect(game.goalWidthOf(Side.right), GameConfig.goalWidth);
      });

      test('recommencer remet les buts à leur taille', () {
        final game = _game();
        game.debugGrantPower(Side.left, PowerType.bigOpponentGoal);
        _run(game, frames: 120); // transition terminée
        game.restart();
        expect(game.goalWidthOf(Side.right), GameConfig.goalWidth);
      });
    });
  });
}
