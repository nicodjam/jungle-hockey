import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/power_ups.dart';

/// Rendu des objets, pictogrammes et effets liés aux pouvoirs.
abstract final class PowerPainting {
  static Color colorOf(PowerType type) => switch (type) {
        PowerType.speedBoost => const Color(0xFFFF9100),
        PowerType.opponentSlow => const Color(0xFF40C4FF),
        PowerType.homing => const Color(0xFFD17BFF),
        PowerType.bigMallet => const Color(0xFF69F0AE),
        PowerType.fog => const Color(0xFFCFD8DC),
        PowerType.bigOpponentGoal => const Color(0xFFFF4FA3),
        PowerType.smallGoal => const Color(0xFFFFE135),
      };

  /// Pictogramme du pouvoir, centré sur [c], dans un carré de demi-côté [s].
  static void paintIcon(Canvas canvas, PowerType type, Offset c, double s, Color color) {
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.16
      ..strokeCap = StrokeCap.round;

    Path poly(List<Offset> points) {
      final path = Path()..moveTo(c.dx + points[0].dx * s, c.dy + points[0].dy * s);
      for (final p in points.skip(1)) {
        path.lineTo(c.dx + p.dx * s, c.dy + p.dy * s);
      }
      return path..close();
    }

    switch (type) {
      case PowerType.speedBoost: // éclair
        canvas.drawPath(
          poly(const [
            Offset(0.2, -1),
            Offset(-0.55, 0.15),
            Offset(-0.05, 0.15),
            Offset(-0.25, 1),
            Offset(0.55, -0.2),
            Offset(0.05, -0.2),
          ]),
          fill,
        );
      case PowerType.opponentSlow: // sablier
        canvas.drawPath(
          poly(const [
            Offset(-0.55, -0.8),
            Offset(0.55, -0.8),
            Offset(0.08, 0),
            Offset(0.55, 0.8),
            Offset(-0.55, 0.8),
            Offset(-0.08, 0),
          ]),
          fill,
        );
        canvas.drawLine(c + Offset(-0.75 * s, -0.92 * s), c + Offset(0.75 * s, -0.92 * s), stroke);
        canvas.drawLine(c + Offset(-0.75 * s, 0.92 * s), c + Offset(0.75 * s, 0.92 * s), stroke);
      case PowerType.homing: // cible
        canvas.drawCircle(c, s * 0.85, stroke);
        canvas.drawCircle(c, s * 0.45, stroke);
        canvas.drawCircle(c, s * 0.16, fill);
      case PowerType.bigMallet: // maillet entouré de flèches vers l'extérieur
        canvas.drawCircle(c, s * 0.38, fill);
        for (var k = 0; k < 4; k++) {
          final a = math.pi / 4 + k * math.pi / 2;
          final dir = Offset(math.cos(a), math.sin(a));
          final tip = c + dir * (s * 0.95);
          canvas.drawLine(c + dir * (s * 0.55), tip, stroke);
          final side = Offset(-dir.dy, dir.dx);
          canvas.drawLine(tip, tip - dir * (s * 0.28) + side * (s * 0.2), stroke);
          canvas.drawLine(tip, tip - dir * (s * 0.28) - side * (s * 0.2), stroke);
        }
      case PowerType.fog: // trois volutes
        for (final y in const [-0.5, 0.0, 0.5]) {
          final path = Path()
            ..moveTo(c.dx - 0.85 * s, c.dy + y * s)
            ..quadraticBezierTo(c.dx - 0.42 * s, c.dy + (y - 0.25) * s, c.dx, c.dy + y * s)
            ..quadraticBezierTo(c.dx + 0.42 * s, c.dy + (y + 0.25) * s, c.dx + 0.85 * s, c.dy + y * s);
          canvas.drawPath(path, stroke);
        }
      case PowerType.bigOpponentGoal: // cage, flèches vers l'extérieur
        _paintGoalIcon(canvas, c, s, stroke, outward: true);
      case PowerType.smallGoal: // cage, flèches vers l'intérieur
        _paintGoalIcon(canvas, c, s, stroke, outward: false);
    }
  }

  /// Cage vue de dessus (un crochet ouvert vers la droite) et deux flèches
  /// verticales qui l'ouvrent ou la referment.
  static void _paintGoalIcon(Canvas canvas, Offset c, double s, Paint stroke, {required bool outward}) {
    final cage = Path()
      ..moveTo(c.dx + 0.1 * s, c.dy - 0.42 * s)
      ..lineTo(c.dx - 0.55 * s, c.dy - 0.42 * s)
      ..lineTo(c.dx - 0.55 * s, c.dy + 0.42 * s)
      ..lineTo(c.dx + 0.1 * s, c.dy + 0.42 * s);
    canvas.drawPath(cage, stroke);
    final x = c.dx + 0.5 * s;
    for (final sgn in const [-1.0, 1.0]) {
      final inner = Offset(x, c.dy + sgn * 0.18 * s);
      final outer = Offset(x, c.dy + sgn * 0.95 * s);
      final tip = outward ? outer : inner;
      final back = outward ? -sgn : sgn;
      canvas.drawLine(inner, outer, stroke);
      canvas.drawLine(tip, tip + Offset(-0.24 * s, back * 0.24 * s), stroke);
      canvas.drawLine(tip, tip + Offset(0.24 * s, back * 0.24 * s), stroke);
    }
  }

  /// Brume sur la bande centrale du terrain, d'opacité [level] (0 à 1).
  /// Bords fondus, nappes plus claires qui dérivent lentement.
  static void paintFog(Canvas canvas, double level, double time) {
    if (level <= 0) return;
    const w = GameConfig.tableWidth;
    const h = GameConfig.tableHeight;
    const half = w * GameConfig.fogHalfWidth;
    const x0 = w / 2 - half;
    const x1 = w / 2 + half;
    const feather = 90.0;
    const span = x1 - x0 + 2 * feather;
    const edge = 2 * feather / span;
    const base = Color(0xFF9AA7B8);
    final opaque = base.withValues(alpha: 0.94 * level);
    final band = const Rect.fromLTRB(x0 - feather, 0, x1 + feather, h);

    canvas.drawRect(
      band,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(x0 - feather, 0),
          const Offset(x1 + feather, 0),
          [base.withValues(alpha: 0), opaque, opaque, base.withValues(alpha: 0)],
          const [0, edge, 1 - edge, 1],
        ),
    );

    canvas
      ..save()
      ..clipRect(band);
    final wisp = Paint()
      ..color = Colors.white.withValues(alpha: 0.28 * level)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    for (var k = 0; k < 8; k++) {
      final drift = time * (0.025 + 0.01 * (k % 3)) * (k.isEven ? 1 : -1);
      final fx = (k * 0.37 + drift) % 1.0;
      final fy = (k * 0.61 + time * 0.015) % 1.0;
      canvas.drawCircle(
        Offset(x0 + fx * (x1 - x0), fy * h),
        150 + 30.0 * (k % 3),
        wisp,
      );
    }
    canvas.restore();
  }

  /// Objet posé sur le terrain : apparaît en grossissant, pulse, et
  /// clignote pendant ses 2 dernières secondes.
  static void paintItem(Canvas canvas, PowerItem item, double time) {
    final color = colorOf(item.type);
    final appear = Curves.easeOutBack.transform(math.min(1.0, item.age / 0.35));
    final pulse = 1 + 0.07 * math.sin(time * 5 + item.position.dx * 0.01);
    final r = GameConfig.itemRadius * appear * pulse;
    final remaining = GameConfig.itemLifetime - item.age;
    final alpha = remaining < 2 ? 0.35 + 0.65 * (0.5 + 0.5 * math.cos(item.age * 14)) : 1.0;
    final c = item.position;

    canvas.drawCircle(
      c,
      r * 1.35,
      Paint()
        ..color = color.withValues(alpha: 0.35 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0B1220).withValues(alpha: 0.85 * alpha));

    // Anneau qui tourne doucement.
    final ring = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var k = 0; k < 3; k++) {
      canvas.drawArc(rect, time * 1.5 + k * 2 * math.pi / 3, 1.5, false, ring);
    }

    paintIcon(canvas, item.type, c, r * 0.55, color.withValues(alpha: alpha));
  }

  /// Onde qui s'élargit là où un objet vient d'être ramassé.
  static void paintBurst(Canvas canvas, PickupBurst burst) {
    final t = (burst.age / 0.6).clamp(0.0, 1.0);
    final color = colorOf(burst.type);
    canvas.drawCircle(
      burst.position,
      GameConfig.itemRadius * (1 + t * 4),
      Paint()
        ..color = color.withValues(alpha: 1 - t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * (1 - t) + 1,
    );
  }
}
