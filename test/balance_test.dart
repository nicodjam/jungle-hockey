import 'dart:math' show Random;
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:jungle_hockey/game/air_hockey_game.dart';
import 'package:jungle_hockey/game/config.dart';
import 'package:jungle_hockey/game/entities.dart';
import 'package:jungle_hockey/game/power_ups.dart';

const _h = GameConfig.tableHeight;

AirHockeyGame _game({bool balance = true}) =>
    AirHockeyGame(random: Random(1), balanceEnabled: balance, powerUpsEnabled: false);

/// Vitesse du palet juste après une même frappe du maillet gauche.
double _leftShotSpeed(AirHockeyGame game) {
  game.puck
    ..position = const Offset(400, _h / 2)
    ..velocity = Offset.zero;
  final mallet = game.mallets.firstWhere((m) => m.side == Side.left);
  game.pointerDown(1, mallet.position);
  game.pointerMove(1, const Offset(700, _h / 2));
  for (var i = 0; i < 6; i++) {
    game.update(1 / 60);
  }
  expect(game.lastHitBy, Side.left);
  return game.puck.velocity.distance;
}

void main() {
  test('désactivé : aucun effet, quel que soit l\'écart', () {
    final game = _game(balance: false)..debugSetScore(Side.left, 5);
    expect(game.balanceFactor(Side.left), 1);
    expect(game.balanceFactor(Side.right), 1);
  });

  test('à égalité, aucun effet', () {
    final game = _game()
      ..debugSetScore(Side.left, 2)
      ..debugSetScore(Side.right, 2);
    expect(game.balanceFactor(Side.left), 1);
    expect(game.balanceFactor(Side.right), 1);
  });

  test('l\'effet grandit avec l\'écart, dans les deux sens', () {
    final game = _game()..debugSetScore(Side.left, 1);
    expect(game.balanceFactor(Side.left), closeTo(1 - GameConfig.balanceStep, 1e-9));
    expect(game.balanceFactor(Side.right), closeTo(1 + GameConfig.balanceStep, 1e-9));

    game.debugSetScore(Side.left, 3);
    expect(game.balanceFactor(Side.left), closeTo(1 - 3 * GameConfig.balanceStep, 1e-9));
    expect(game.balanceFactor(Side.right), closeTo(1 + 3 * GameConfig.balanceStep, 1e-9));
  });

  test('l\'effet est plafonné', () {
    final game = _game()..debugSetScore(Side.right, 9);
    expect(game.balanceFactor(Side.right), GameConfig.balanceMin);
    expect(game.balanceFactor(Side.left), GameConfig.balanceMax);
  });

  group('sur les tirs', () {
    // Les tirs sont plafonnés à la vitesse max multipliée par le même
    // facteur : le rapport des vitesses est celui du facteur, à
    // l'amortissement près.
    double normal() => _leftShotSpeed(_game(balance: false));

    test('l\'équipe qui mène tire moins vite', () {
      final game = _game()..debugSetScore(Side.left, 3);
      final f = game.balanceFactor(Side.left);
      final n = normal();
      expect(_leftShotSpeed(game), closeTo(n * f, n * 0.04));
    });

    test('l\'équipe menée tire plus vite (au-delà de la vitesse max normale)', () {
      final game = _game()..debugSetScore(Side.right, 3);
      final f = game.balanceFactor(Side.left);
      expect(f, greaterThan(1));
      final n = normal();
      expect(_leftShotSpeed(game), closeTo(n * f, n * 0.04));
    });

    test('se combine avec les pouvoirs', () {
      final game = _game()..debugSetScore(Side.left, 3);
      game.debugGrantPower(Side.left, PowerType.speedBoost);
      final f = game.balanceFactor(Side.left) * GameConfig.boostFactor;
      final n = normal();
      expect(_leftShotSpeed(game), closeTo(n * f, n * 0.04));
    });
  });
}
