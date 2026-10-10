import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/spell_style.dart';
export '../../domain/models/spell_style.dart';

Color spellColor(String jobId) => switch (jobId) {
  'engineer' => const Color(0xFF42D8EA),
  'artist' => const Color(0xFFFF81C8),
  'scholar' => const Color(0xFF6789FF),
  'mentor' => const Color(0xFFB491FF),
  'hero' || 'president' => const Color(0xFFFFD45E),
  'warrior' => const Color(0xFFFF944F),
  'alchemist' || 'sage' => const Color(0xFF8EDDCF),
  'bard' || 'maestro' => const Color(0xFFFFBB79),
  'chef' || 'gourmet_master' => const Color(0xFFFF9562),
  'guardian' || 'warlord' => const Color(0xFF81C7FF),
  'dancer' || 'celestial_dancer' => const Color(0xFFF3A7EB),
  'beast_tamer' || 'dragon_tamer' => const Color(0xFFB7EC85),
  _ => const Color(0xFF6CE2AF),
};

/// Deterministic Canvas animation: charge [0,.25], travel [.25,.6], burst [.6,1].
class SpellEffect extends CustomPainter {
  const SpellEffect({
    required this.progress,
    required this.jobId,
    this.element,
    this.reducedEffects = false,
    this.fromEnemy = false,
  });
  final double progress;
  final String jobId;
  final String? element;
  final bool reducedEffects;
  final bool fromEnemy;
  void _glowPath(
    Canvas c,
    Path path,
    Color color, {
    double width = 2,
    double alpha = 1,
  }) {
    for (final scale in [4.0, 2.0, 1.0])
      c.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: alpha * (scale == 1 ? .85 : .12))
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * scale
          ..strokeCap = StrokeCap.round,
      );
  }

  void _sigil(
    Canvas c,
    Offset center,
    double radius,
    double angle,
    Color color,
    double opacity,
  ) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    final ink = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final scale in [.72, 1.0, 1.15])
      c.drawCircle(Offset.zero, radius * scale, ink);
    final star = Path();
    for (var i = 0; i <= 6; i++) {
      final a = i * math.pi * 4 / 6;
      final p = Offset(math.cos(a), math.sin(a)) * radius * .7;
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    c.drawPath(star, ink);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final p = Offset(math.cos(a), math.sin(a)) * radius;
      c.drawLine(p * .88, p * 1.06, ink);
      c.drawCircle(
        p * 1.15,
        1.8,
        Paint()..color = color.withValues(alpha: opacity),
      );
    }
    c.restore();
  }

  void _spectacle(
    Canvas c,
    Size size,
    double t,
    Offset start,
    Offset end,
    Color color,
    SpellVisual style,
  ) {
    // Fixed particle counts, deterministic trajectories, no random state in paint.
    final charge = (t / .6).clamp(0.0, 1.0).toDouble();
    if (t < .6) {
      final opacity = math.sin(charge * math.pi) * .7;
      c.drawCircle(
        start,
        70,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: opacity * .3),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: start, radius: 70)),
      );
      _sigil(c, start, 34 + charge * 12, t * 2, color, opacity);
      _sigil(c, start, 51 + charge * 8, -t * 1.5, Colors.white, opacity * .45);
      for (var i = 0; i < 16; i++) {
        final a = i * math.pi / 8 + t * 2, r = 85 * (1 - charge) + 12;
        final p = start + Offset(math.cos(a), math.sin(a)) * r;
        c.drawCircle(
          p,
          1.5 + (i % 3) * .4,
          Paint()..color = color.withValues(alpha: opacity),
        );
      }
    }
    if (t >= .25 && t < .6 && element != 'heal') {
      final q = (t - .25) / .35, point = Offset.lerp(start, end, q)!;
      for (var i = 0; i < 3; i++) {
        final path = Path()..moveTo(start.dx, start.dy);
        path.quadraticBezierTo(
          (start.dx + point.dx) / 2,
          start.dy + math.sin(q * 6 + i) * 24,
          point.dx,
          point.dy,
        );
        _glowPath(c, path, color, width: 1.2, alpha: .35);
      }
      c.drawCircle(
        point,
        25,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: .8),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: point, radius: 25)),
      );
    }
    if (t < .6) return;
    final b = ((t - .6) / .4).clamp(0.0, 1.0).toDouble(), fade = 1 - b;
    final envelope = math.sin(b * math.pi);
    _sigil(c, end, 32 + b * 55, -b * 1.2, color, fade * .55);
    c.drawCircle(
      end,
      90,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: envelope * .35),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: end, radius: 90)),
    );
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12 + .2, r = 20 + b * (60 + (i % 5) * 9);
      final p = end + Offset(math.cos(a), math.sin(a)) * r;
      final tail = end + Offset(math.cos(a), math.sin(a)) * (r - 8 - 12 * fade);
      _glowPath(
        c,
        Path()
          ..moveTo(tail.dx, tail.dy)
          ..lineTo(p.dx, p.dy),
        i.isEven ? color : Colors.white,
        width: 1.2,
        alpha: fade * .7,
      );
    }
    if (element == 'ice') {
      for (var i = 0; i < 7; i++) {
        final a = i * math.pi / 3.5,
            p = end + Offset(math.cos(a), math.sin(a)) * (20 + b * 55);
        final crystal = Path()
          ..moveTo(p.dx, p.dy - 18 * fade)
          ..lineTo(p.dx + 7 * fade, p.dy)
          ..lineTo(p.dx, p.dy + 13 * fade)
          ..lineTo(p.dx - 7 * fade, p.dy)
          ..close();
        c.drawPath(
          crystal,
          Paint()..color = color.withValues(alpha: fade * .75),
        );
      }
    } else if (element == 'heal') {
      for (var i = 0; i < 9; i++) {
        final p =
            end + Offset(math.sin(i * 2.4) * 44, 25 - b * 90 + (i % 3) * 12);
        final path = Path()
          ..moveTo(p.dx - 4, p.dy)
          ..lineTo(p.dx + 4, p.dy)
          ..moveTo(p.dx, p.dy - 4)
          ..lineTo(p.dx, p.dy + 4);
        _glowPath(c, path, color, width: 2, alpha: fade);
      }
    } else if (element == 'burst') {
      for (var i = 0; i < 6; i++) {
        final p = end + Offset((i - 2.5) * 19, (i % 2) * 18 - 12);
        final head = Offset.lerp(
          p - const Offset(60, 110),
          p,
          math.min(1.0, b * 2),
        )!;
        _glowPath(
          c,
          Path()
            ..moveTo(head.dx - 22 * fade, head.dy - 42 * fade)
            ..lineTo(head.dx, head.dy),
          color,
          width: 4,
          alpha: fade,
        );
      }
    } else if (style == SpellVisual.lightning) {
      for (var i = 0; i < 5; i++) {
        final path = Path()..moveTo(end.dx + (i - 2) * 18, end.dy - 90 * fade);
        for (var j = 1; j < 5; j++)
          path.lineTo(
            end.dx + (i - 2) * 14 + math.sin(i * 4 + j * 3 + b * 4) * 12,
            end.dy - 90 * fade + j * 25 * fade,
          );
        _glowPath(c, path, color, width: 1.8, alpha: fade);
      }
    } else if (style == SpellVisual.blade) {
      for (var i = 0; i < 3; i++)
        _glowPath(
          c,
          Path()
            ..moveTo(end.dx - 50, end.dy - 40 + i * 20)
            ..quadraticBezierTo(
              end.dx + 20,
              end.dy + 30,
              end.dx + 65,
              end.dy - 30 + i * 20,
            ),
          color,
          width: 3 * fade + .3,
          alpha: fade,
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    final start = Offset(
      size.width * (fromEnemy ? .78 : .25),
      size.height * .52,
    );
    final end = element == 'heal'
        ? start
        : Offset(size.width * (fromEnemy ? .25 : .78), size.height * .52);
    final color = element == 'ice'
        ? const Color(0xFF85E8FF)
        : element == 'heal'
        ? const Color(0xFF4CDD93)
        : element == 'burst'
        ? const Color(0xFFFFA7EE)
        : element == 'lightning'
        ? const Color(0xFFBC8CFF)
        : spellColor(jobId);
    final style = element == 'ice'
        ? SpellVisual.runes
        : element == 'heal'
        ? SpellVisual.orb
        : element == 'burst'
        ? SpellVisual.stars
        : element == 'lightning'
        ? SpellVisual.lightning
        : spellFor(jobId);
    if (reducedEffects) {
      if (t >= .6)
        canvas.drawCircle(
          end,
          24,
          Paint()..color = color.withValues(alpha: (1 - t) * .8),
        );
      return;
    }
    _spectacle(canvas, size, t, start, end, color, style);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    if (t < .6) {
      final r = 18 + math.sin(t * math.pi) * 16;
      canvas.drawCircle(start, r, paint);
      canvas.drawCircle(
        start,
        r + 8,
        paint..color = color.withValues(alpha: .5),
      );
      for (var i = 0; i < 6; i++) {
        final a = t * 6 + i * math.pi / 3;
        final pos = start + Offset(math.cos(a), math.sin(a)) * (r + 9);
        canvas.drawCircle(pos, 3, Paint()..color = color);
      }
    }
    if (t >= .25 && t < .6) {
      final travel = ((t - .25) / .35).clamp(0.0, 1.0).toDouble();
      final point = Offset.lerp(start, end, travel)!;
      paint
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      switch (style) {
        case SpellVisual.lightning:
          {
            final path = Path()..moveTo(start.dx, start.dy);
            for (var i = 1; i <= 12; i++) {
              final x = start.dx + (point.dx - start.dx) * i / 12;
              path.lineTo(
                x,
                start.dy + (i == 12 ? 0 : math.sin(i * 2.7 + t * 35) * 15),
              );
            }
            canvas.drawPath(
              path,
              paint
                ..strokeWidth = 9
                ..color = color.withValues(alpha: .3),
            );
            canvas.drawPath(
              path,
              paint
                ..strokeWidth = 3
                ..color = Colors.white,
            );
            break;
          }
        case SpellVisual.blade:
          {
            canvas.save();
            canvas.translate(point.dx, point.dy);
            canvas.rotate(-.6);
            canvas.drawArc(
              const Rect.fromLTWH(-30, -42, 60, 84),
              -1.2,
              2.4,
              false,
              paint..strokeWidth = 9,
            );
            canvas.restore();
            break;
          }
        case SpellVisual.runes:
          {
            canvas.save();
            canvas.translate(point.dx, point.dy);
            canvas.rotate(t * 10);
            final path = Path();
            for (var i = 0; i < 6; i++) {
              final a = i * math.pi / 3;
              final x = math.cos(a) * 25, y = math.sin(a) * 25;
              if (i == 0) {
                path.moveTo(x, y);
              } else {
                path.lineTo(x, y);
              }
            }
            path.close();
            canvas.drawPath(path, paint);
            canvas.drawCircle(Offset.zero, 14, paint);
            canvas.restore();
            break;
          }
        case SpellVisual.stars:
          {
            for (var i = 0; i < 5; i++) {
              final center = point - Offset(i * 13, math.sin(t * 12 + i) * 15);
              final path = Path();
              for (var k = 0; k < 10; k++) {
                final a = k * math.pi / 5 - math.pi / 2,
                    r = k.isEven ? 12.0 : 5.0;
                final q = center + Offset(math.cos(a) * r, math.sin(a) * r);
                if (k == 0) {
                  path.moveTo(q.dx, q.dy);
                } else {
                  path.lineTo(q.dx, q.dy);
                }
              }
              path.close();
              canvas.drawPath(
                path,
                Paint()..color = color.withValues(alpha: 1 - i * .13),
              );
            }
            break;
          }
        case SpellVisual.orb:
          {
            for (var i = 5; i >= 0; i--) {
              canvas.drawCircle(
                point - Offset(i * 10, 0),
                math.max(3, 15 - i * 2).toDouble(),
                Paint()..color = color.withValues(alpha: 1 - i * .14),
              );
            }
            canvas.drawCircle(point, 7, Paint()..color = Colors.white);
            break;
          }
      }
    }
    if (t >= .6) {
      final burst = (t - .6) / .4;
      canvas.drawCircle(
        end,
        12 + burst * 55,
        Paint()..color = color.withValues(alpha: (1 - burst) * .65),
      );
      canvas.drawCircle(
        end,
        16 + burst * 70,
        Paint()
          ..color = Colors.white.withValues(alpha: 1 - burst)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        final p = end + Offset(math.cos(a), math.sin(a)) * (15 + burst * 85);
        canvas.drawCircle(
          p,
          4 * (1 - burst) + 1,
          Paint()..color = color.withValues(alpha: 1 - burst),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpellEffect old) =>
      old.progress != progress ||
      old.jobId != jobId ||
      old.element != element ||
      old.reducedEffects != reducedEffects ||
      old.fromEnemy != fromEnemy;
}
