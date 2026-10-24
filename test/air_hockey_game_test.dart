import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:jungle_hockey/game/air_hockey_game.dart';
import 'package:jungle_hockey/game/config.dart';
import 'package:jungle_hockey/game/entities.dart';

const _w = GameConfig.tableWidth;
const _h = GameConfig.tableHeight;
const _r = GameConfig.puckRadius;

void _run(AirHockeyGame game, {int frames = 1, double dt = 1 / 60}) {
  for (var i = 0; i < frames; i++) {
    game.update(dt);
  }
}

void main() {
  group('bandes', () {
    test('le palet rebondit sur la bande haute', () {
      final game = AirHockeyGame();
      game.puck
        ..position = const Offset(_w / 2, _r + 10)
        ..velocity = const Offset(0, -1000);
      _run(game, frames: 3);
      expect(game.puck.velocity.dy, greaterThan(0));
      expect(game.puck.position.dy, greaterThanOrEqualTo(_r));
    });

    test('le palet rebondit sur le petit côté hors de la gorge du but', () {
      final game = AirHockeyGame();
      game.puck
        ..position = const Offset(_r + 5, 100)
        ..velocity = const Offset(-2000, 0);
      _run(game, frames: 3);
      expect(game.puck.velocity.dx, greaterThan(0));
      expect(game.scoreOf(Side.right), 0);
    });
  });

  group('buts', () {
    test('un palet dans le but gauche donne un point à droite', () {
      final events = <GameEvent>[];
      final game = AirHockeyGame(onEvent: (e, _) => events.add(e));
      game.puck
        ..position = const Offset(_r + 5, _h / 2)
        ..velocity = const Offset(-2000, 0);
      _run(game, frames: 5);
      expect(game.scoreOf(Side.right), 1);
      expect(game.scoreOf(Side.left), 0);
      expect(game.phase, GamePhase.goal);
      expect(events, contains(GameEvent.goal));
    });

    test('remise en jeu dans le camp de l\'équipe qui a encaissé', () {
      final game = AirHockeyGame();
      game.puck
        ..position = const Offset(_w - _r - 5, _h / 2)
        ..velocity = const Offset(2000, 0);
      _run(game, frames: 5);
      expect(game.scoreOf(Side.left), 1);
      _run(game, frames: 120); // > GameConfig.goalPause
      expect(game.phase, GamePhase.playing);
      expect(game.puck.position.dx, greaterThan(_w / 2));
    });

    test('la partie se termine au score cible', () {
      final game = AirHockeyGame(targetScore: 1);
      game.puck
        ..position = const Offset(_r + 5, _h / 2)
        ..velocity = const Offset(-2000, 0);
      _run(game, frames: 5);
      expect(game.phase, GamePhase.finished);
      expect(game.winner, Side.right);

      game.restart();
      expect(game.phase, GamePhase.playing);
      expect(game.scoreOf(Side.right), 0);
    });
  });

  group('maillets', () {
    test('il faut poser le doigt sur un maillet pour le saisir', () {
      final game = AirHockeyGame(playersPerSide: 2);
      final left = game.mallets.where((m) => m.side == Side.left).toList();

      // Doigt dans le camp gauche mais loin des maillets : rien.
      expect(game.pointerDown(1, const Offset(600, 500)), isFalse);
      expect(left.every((m) => !m.isGrabbed), isTrue);

      // Doigt sur le premier maillet (légèrement décentré).
      expect(game.pointerDown(2, left[0].position + const Offset(20, -15)), isTrue);
      expect(left[0].pointer, 2);
      expect(left[1].isGrabbed, isFalse);

      // Un second doigt sur le même maillet ne le vole pas.
      expect(game.pointerDown(3, left[0].position), isFalse);

      // Le second maillet se saisit séparément.
      expect(game.pointerDown(4, left[1].position), isTrue);
      expect(left[1].pointer, 4);
    });

    test('le maillet suit le doigt sans sauter sous lui', () {
      final game = AirHockeyGame();
      final mallet = game.mallets.firstWhere((m) => m.side == Side.left);
      final start = mallet.position;
      const offset = Offset(30, 10);
      game.pointerDown(1, start + offset);
      _run(game, frames: 5);
      expect(mallet.position, start); // le doigt n'a pas bougé

      game.pointerMove(1, start + offset + const Offset(100, 50));
      _run(game, frames: 30);
      expect((mallet.position - (start + const Offset(100, 50))).distance, lessThan(1e-6));
    });

    test('un maillet ne franchit pas la ligne médiane', () {
      final game = AirHockeyGame();
      final start = game.mallets.firstWhere((m) => m.side == Side.left).position;
      game.pointerDown(1, start);
      game.pointerMove(1, const Offset(1500, 500));
      _run(game, frames: 60);
      final mallet = game.mallets.firstWhere((m) => m.pointer == 1);
      expect(mallet.side, Side.left);
      expect(
        mallet.position.dx,
        lessThanOrEqualTo(_w / 2 - GameConfig.malletRadius + 1e-9),
      );
    });

    test('un maillet en mouvement propulse le palet', () {
      final events = <GameEvent>[];
      final game = AirHockeyGame(onEvent: (e, _) => events.add(e));
      game.puck
        ..position = const Offset(400, _h / 2)
        ..velocity = Offset.zero;
      final mallet = game.mallets.firstWhere((m) => m.side == Side.left);
      game.pointerDown(1, mallet.position);
      game.pointerMove(1, const Offset(700, _h / 2));
      _run(game, frames: 10);
      expect(game.puck.velocity.dx, greaterThan(500));
      expect(events, contains(GameEvent.malletHit));
    });

    test('la pause fige la simulation', () {
      final game = AirHockeyGame();
      game.puck.velocity = const Offset(800, 300);
      game.pause();
      final before = game.puck.position;
      _run(game, frames: 10);
      expect(game.puck.position, before);
      game.resume();
      _run(game, frames: 1);
      expect(game.puck.position, isNot(before));
    });
  });
}
