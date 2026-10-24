import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/air_hockey_game.dart';
import '../game/config.dart';
import '../game/entities.dart';
import '../game/power_ups.dart';
import 'decor.dart';
import 'power_painting.dart';
import 'table_layout.dart';

/// Couleurs des équipes : [Side] → couleur par rang de joueur.
abstract final class TeamColors {
  static const List<Color> left = [Color(0xFF2E9BFF), Color(0xFF6FE3FF)];
  static const List<Color> right = [Color(0xFFFF4D5E), Color(0xFFFFA45C)];

  static Color of(Side side, [int index = 0]) =>
      (side == Side.left ? left : right)[index <= 0 ? 0 : 1];
}

class TablePainter extends CustomPainter {
  TablePainter(this.game) : super(repaint: game);

  final AirHockeyGame game;

  static const double _w = GameConfig.tableWidth;
  static const double _h = GameConfig.tableHeight;
  static const Color _background = Color(0xFF070B14);
  static const Color _jungleBackground = Color(0xFF0C2612);
  static const Color _railColor = Color(0xFF1B2433);
  static const Color _surface = Color(0xFF0E1A2B);
  static const Color _lines = Color(0x40FFFFFF);
  static const Color _puckColor = Color(0xFFFFD54F);

  /// Trous de la soufflerie, calculés une fois.
  static final List<Offset> _airHoles = [
    for (var x = 50.0; x < _w; x += 50)
      for (var y = 50.0; y < _h; y += 50) Offset(x, y),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final decor = Decor.table;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = decor == null ? _background : _jungleBackground,
    );

    final layout = TableLayout.fit(size);
    canvas
      ..save()
      ..translate(layout.origin.dx, layout.origin.dy)
      ..scale(layout.scale);

    if (decor != null) {
      _drawDecor(canvas, decor);
    } else {
      _drawPlainTable(canvas);
    }
    _drawMarkings(canvas, plain: decor == null);
    _drawScores(canvas);
    _drawPowerHud(canvas);
    for (final item in game.items) {
      PowerPainting.paintItem(canvas, item, game.time);
    }
    for (final burst in game.bursts) {
      PowerPainting.paintBurst(canvas, burst);
    }
    for (final m in game.mallets) {
      _drawMallet(canvas, m);
    }
    if (game.puckVisible) _drawPuck(canvas);
    PowerPainting.paintFog(canvas, game.fogLevel, game.time);
    _drawMessages(canvas);

    canvas.restore();
  }

  /// Le décor de jungle : surface et bandes, en une image qui couvre toute
  /// la table, bandes comprises.
  void _drawDecor(Canvas canvas, ui.Image image) {
    const rail = TableLayout.rail;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      const Rect.fromLTRB(-rail, -rail, _w + rail, _h + rail),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  /// Table sans décor (image absente) : bandes unies, surface sombre.
  void _drawPlainTable(Canvas canvas) {
    const rail = TableLayout.rail;

    // Bandes
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-rail, -rail, _w + rail, _h + rail),
        const Radius.circular(70),
      ),
      Paint()..color = _railColor,
    );

    // Surface
    final surface = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, _w, _h),
      const Radius.circular(36),
    );
    canvas.drawRRect(
      surface,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(_w / 2, _h / 2),
          _w * 0.6,
          [const Color(0xFF16263D), _surface],
        ),
    );

    // Trous d'air
    canvas.drawPoints(
      ui.PointMode.points,
      _airHoles,
      Paint()
        ..color = const Color(0x14FFFFFF)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Lignes du terrain et buts (couleur de chaque équipe), par-dessus le
  /// décor. Avec le décor, l'ouverture des buts est déjà dessinée (un
  /// terrier sombre) : seule la couleur de l'équipe y est ajoutée.
  void _drawMarkings(Canvas canvas, {required bool plain}) {
    const rail = TableLayout.rail;
    final linePaint = Paint()
      ..color = _lines
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    // Ligne médiane et rond central
    canvas.drawLine(const Offset(_w / 2, 0), const Offset(_w / 2, _h), linePaint);
    canvas.drawCircle(const Offset(_w / 2, _h / 2), 130, linePaint);

    // Zones de but et ouvertures
    for (final side in Side.values) {
      final isLeft = side == Side.left;
      final color = TeamColors.of(side);
      final goalCenter = Offset(isLeft ? 0 : _w, _h / 2);

      canvas.drawArc(
        Rect.fromCircle(center: goalCenter, radius: 230),
        isLeft ? -math.pi / 2 : math.pi / 2,
        math.pi,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );

      // Largeur courante du but (agrandi ou rétréci par les pouvoirs).
      final halfGoal = game.goalWidthOf(side) / 2;
      final mouth = isLeft
          ? Rect.fromLTRB(-rail, _h / 2 - halfGoal, 0, _h / 2 + halfGoal)
          : Rect.fromLTRB(_w, _h / 2 - halfGoal, _w + rail, _h / 2 + halfGoal);
      if (plain) {
        canvas.drawRect(mouth, Paint()..color = const Color(0xFF000000));
      } else {
        _drawResizedGoal(canvas, side, halfGoal);
        // Lueur de l'équipe au fond du terrier.
        canvas.drawRect(
          mouth,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(isLeft ? mouth.left : mouth.right, 0),
              Offset(isLeft ? mouth.right : mouth.left, 0),
              [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
            ),
        );
      }
      canvas.drawRect(
        isLeft
            ? Rect.fromLTRB(mouth.left, mouth.top, mouth.left + 8, mouth.bottom)
            : Rect.fromLTRB(mouth.right - 8, mouth.top, mouth.right, mouth.bottom),
        Paint()..color = color,
      );
    }
  }

  // Palissade du décor (voir tool/generate_decor.py) : poteau de bambou
  // de 34 unités le long du bord, terrier sombre dans l'ouverture du but.
  static const double _bamboo = 34;
  static const List<Color> _bambooColors = [
    Color(0xFF5A4612), Color(0xFFA88C34), Color(0xFFECDC8C), Color(0xFFCDB45A), Color(0xFF6B5416),
  ];
  static const List<double> _bambooStops = [0, 0.18, 0.42, 0.62, 1];

  /// But agrandi ou rétréci par un pouvoir, par-dessus le décor (dessiné
  /// pour la largeur normale) : le terrier s'étend sur la palissade, ou du
  /// bambou referme l'ouverture ; deux bouts de bambou coupés marquent les
  /// nouveaux poteaux.
  void _drawResizedGoal(Canvas canvas, Side side, double halfGoal) {
    const base = GameConfig.goalWidth / 2;
    if ((halfGoal - base).abs() < 0.5) return;
    const rail = TableLayout.rail;
    final isLeft = side == Side.left;
    final edgeX = isLeft ? 0.0 : _w; // bord du terrain
    final outX = isLeft ? -rail : _w + rail; // bord de l'écran
    final poleOutX = isLeft ? -_bamboo : _w + _bamboo;

    if (halfGoal > base) {
      final hole = Rect.fromLTRB(math.min(edgeX, outX), _h / 2 - halfGoal, math.max(edgeX, outX), _h / 2 + halfGoal);
      canvas.drawRect(
        hole,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(edgeX, 0),
            Offset(outX, 0),
            const [Color(0xFF0D2412), Color(0xFF050D07), Color(0xFF000000)],
            const [0, 0.5, 1],
          ),
      );
    } else {
      final pole = Paint()
        ..shader = ui.Gradient.linear(
          Offset(poleOutX, 0),
          Offset(edgeX, 0),
          _bambooColors,
          _bambooStops,
        );
      final left = math.min(edgeX, poleOutX);
      final right = math.max(edgeX, poleOutX);
      // Jusqu'au-delà des anciens poteaux, pour les recouvrir.
      for (final sgn in const [-1.0, 1.0]) {
        final a = _h / 2 + sgn * halfGoal;
        final b = _h / 2 + sgn * (base + _bamboo + 4);
        canvas.drawRect(Rect.fromLTRB(left, math.min(a, b), right, math.max(a, b)), pole);
      }
    }

    // Nouveaux poteaux : bouts de bambou coupés.
    final postX = (edgeX + poleOutX) / 2;
    for (final sgn in const [-1.0, 1.0]) {
      final center = Offset(postX, _h / 2 + sgn * (halfGoal + _bamboo / 2 - 2));
      canvas.drawCircle(
        center + const Offset(0, 3),
        _bamboo / 2 + 2,
        Paint()
          ..color = const Color(0x88000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(center, _bamboo / 2 + 2, Paint()..color = const Color(0xFFC9AE55));
      canvas.drawCircle(
        center,
        _bamboo / 2 - 1,
        Paint()
          ..color = const Color(0xFFF3E39A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      canvas.drawCircle(center, _bamboo / 2 - 6, Paint()..color = const Color(0xFF3B2A0C));
    }
  }

  void _drawScores(Canvas canvas) {
    for (final side in Side.values) {
      final isLeft = side == Side.left;
      _drawRotatedText(
        canvas,
        '${game.scoreOf(side)}',
        center: Offset(isLeft ? _w * 0.22 : _w * 0.78, _h / 2),
        side: side,
        style: TextStyle(
          fontSize: 240,
          fontWeight: FontWeight.w900,
          color: TeamColors.of(side).withValues(alpha: 0.18),
        ),
      );

      // Mode équilibrage : effet sur les tirs, au-dessus du score (vu du
      // joueur), soit côté ligne médiane.
      final factor = game.balanceFactor(side);
      if ((factor - 1).abs() > 1e-6) {
        final percent = ((factor - 1) * 100).round();
        _drawRotatedText(
          canvas,
          'TIRS ${percent > 0 ? '+' : '−'}${percent.abs()} %',
          center: Offset(isLeft ? _w * 0.22 + 175 : _w * 0.78 - 175, _h / 2),
          side: side,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: (percent > 0 ? const Color(0xFF9CFF7A) : const Color(0xFFFFB15C))
                .withValues(alpha: 0.75),
          ),
        );
      }
    }
  }

  /// Pouvoirs en cours de chaque équipe, près de son bord : une ligne par
  /// pouvoir (pictogramme, nom, jauge du temps restant), tournée vers les
  /// joueurs. La première ligne est la plus proche d'eux.
  void _drawPowerHud(Canvas canvas) {
    for (final side in Side.values) {
      final powers = game.powersOf(side);
      if (powers.isEmpty) continue;
      final isLeft = side == Side.left;

      canvas
        ..save()
        ..translate(isLeft ? _w * 0.06 : _w * 0.94, _h / 2)
        ..rotate(isLeft ? math.pi / 2 : -math.pi / 2);

      // Dans ce repère, x suit le bord du joueur et y pointe vers lui.
      for (var row = 0; row < powers.length; row++) {
        _drawPowerRow(canvas, powers[row], dy: -row * 74.0);
      }
      canvas.restore();
    }
  }

  void _drawPowerRow(Canvas canvas, ActivePower power, {required double dy}) {
    final color = PowerPainting.colorOf(power.type);
    final label = TextPainter(
      text: TextSpan(
        text: power.type.label,
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: 3,
          color: color,
          shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 16)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const iconSize = 19.0;
    final totalWidth = iconSize * 2 + 12 + label.width;
    final left = -totalWidth / 2;
    PowerPainting.paintIcon(
      canvas,
      power.type,
      Offset(left + iconSize, dy - label.height / 2 - 6),
      iconSize,
      color,
    );
    label.paint(canvas, Offset(left + iconSize * 2 + 12, dy - label.height - 6));
    label.dispose();

    // Jauge
    const barHeight = 9.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, dy + 6, totalWidth, barHeight),
        const Radius.circular(barHeight / 2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, dy + 6, totalWidth * power.progress, barHeight),
        const Radius.circular(barHeight / 2),
      ),
      Paint()..color = color,
    );
  }

  void _drawMessages(Canvas canvas) {
    for (final side in Side.values) {
      final String? text = switch (game.phase) {
        GamePhase.goal => game.lastScorer == side ? 'BUT !' : 'Encaissé…',
        GamePhase.paused => 'PAUSE',
        GamePhase.finished => game.winner == side ? 'VICTOIRE' : 'DÉFAITE',
        GamePhase.playing => null,
      };
      if (text == null) continue;
      final isLeft = side == Side.left;
      _drawRotatedText(
        canvas,
        text,
        center: Offset(isLeft ? _w * 0.36 : _w * 0.64, _h / 2),
        side: side,
        style: TextStyle(
          fontSize: 76,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
          color: Colors.white,
          shadows: [Shadow(color: TeamColors.of(side), blurRadius: 24)],
        ),
      );
    }
  }

  /// Dessine un texte orienté vers le joueur assis du côté [side]
  /// (les joueurs se font face aux deux petits côtés de la tablette).
  void _drawRotatedText(
    Canvas canvas,
    String text, {
    required Offset center,
    required Side side,
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(side == Side.left ? math.pi / 2 : -math.pi / 2);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
    painter.dispose();
  }

  void _drawMallet(Canvas canvas, Mallet m) {
    final color = TeamColors.of(m.side, m.index);
    final r = m.radius;

    canvas.drawCircle(
      m.position + const Offset(6, 9),
      r,
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Auras de l'équipe : un anneau par pouvoir en cours.
    final powers = game.powersOf(m.side);
    for (var k = 0; k < powers.length; k++) {
      final pulse = 0.5 + 0.5 * math.sin(game.time * 8 + k);
      canvas.drawCircle(
        m.position,
        r + 12 + 11.0 * k + 3 * pulse,
        Paint()
          ..color = PowerPainting.colorOf(powers[k].type).withValues(alpha: 0.5 + 0.4 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    if (m.isGrabbed) {
      canvas.drawCircle(
        m.position,
        r * 1.25,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
    canvas.drawCircle(m.position, r, Paint()..color = color);
    canvas.drawCircle(
      m.position,
      r * 0.78,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.drawCircle(
      m.position,
      r * 0.42,
      Paint()..color = Color.lerp(color, Colors.white, 0.35)!,
    );
  }

  void _drawPuck(Canvas canvas) {
    final p = game.puck.position;
    final r = game.puck.radius;

    // Pouvoir agissant sur le tir en cours : halo et traînée colorés.
    final effect = game.puckEffect;
    final trailColor = effect == null ? _puckColor : PowerPainting.colorOf(effect);
    if (effect != null) {
      canvas.drawCircle(
        p,
        r * 1.9,
        Paint()
          ..color = trailColor.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Traînée proportionnelle à la vitesse
    final v = game.puck.velocity;
    final speed = v.distance;
    if (speed > 400) {
      final length = math.min(speed * (effect == null ? 0.05 : 0.08), r * (effect == null ? 4 : 7));
      final tail = p - v / speed * length;
      canvas.drawLine(
        tail,
        p,
        Paint()
          ..shader = ui.Gradient.linear(
            tail,
            p,
            [trailColor.withValues(alpha: 0), trailColor.withValues(alpha: effect == null ? 0.5 : 0.8)],
          )
          ..strokeWidth = r * 1.6
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(
      p + const Offset(4, 6),
      r,
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(p, r, Paint()..color = _puckColor);
    canvas.drawCircle(
      p,
      r * 0.65,
      Paint()
        ..color = const Color(0x55000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(TablePainter oldDelegate) => oldDelegate.game != game;
}
