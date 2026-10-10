import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/card_battle.dart';

/// Original vector emblems. No images, card text or art copied from another game.
class BattleCardArt extends CustomPainter {
  const BattleCardArt(this.family, this.color);
  final CardFamily family;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(math.min(size.width, size.height) / 64);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final fill = Paint()..color = color;
    canvas.drawCircle(
      Offset.zero,
      27,
      line..color = color.withValues(alpha: .22),
    );
    canvas.drawCircle(
      Offset.zero,
      23,
      line..color = color.withValues(alpha: .12),
    );
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawCircle(
        Offset(math.cos(a) * 27, math.sin(a) * 27),
        1.4,
        fill..color = color.withValues(alpha: .5),
      );
    }
    fill.color = color;
    line.color = color;
    switch (family) {
      case CardFamily.blade:
        canvas.rotate(.4);
        final blade = Path()
          ..moveTo(0, -25)
          ..lineTo(7, -13)
          ..lineTo(4, 10)
          ..lineTo(-4, 10)
          ..lineTo(-7, -13)
          ..close();
        canvas.drawPath(blade, fill);
        canvas.drawLine(
          const Offset(0, -19),
          const Offset(0, 8),
          Paint()
            ..color = const Color(0xFFFFECC6)
            ..strokeWidth = 1.8,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-13, 9, 26, 5),
            const Radius.circular(2),
          ),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3, 14, 6, 12),
            const Radius.circular(2),
          ),
          fill,
        );
        canvas.drawCircle(const Offset(0, 27), 4, fill);
      case CardFamily.shield:
        final shield = Path()
          ..moveTo(0, -24)
          ..lineTo(19, -16)
          ..lineTo(16, 10)
          ..quadraticBezierTo(12, 19, 0, 27)
          ..quadraticBezierTo(-12, 19, -16, 10)
          ..lineTo(-19, -16)
          ..close();
        canvas.drawPath(shield, fill);
        canvas.drawPath(
          Path()
            ..moveTo(0, -17)
            ..lineTo(12, -11)
            ..lineTo(10, 8)
            ..lineTo(0, 19)
            ..lineTo(-10, 8)
            ..lineTo(-12, -11)
            ..close(),
          Paint()
            ..color = const Color(0xFFF2DBA3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        canvas.drawLine(
          const Offset(0, -10),
          const Offset(0, 12),
          Paint()
            ..color = const Color(0xFFF2DBA3)
            ..strokeWidth = 2,
        );
        canvas.drawLine(
          const Offset(-7, 0),
          const Offset(7, 0),
          Paint()
            ..color = const Color(0xFFF2DBA3)
            ..strokeWidth = 2,
        );
      case CardFamily.staff:
        canvas.rotate(.35);
        canvas.drawLine(
          const Offset(0, -8),
          const Offset(0, 26),
          Paint()
            ..color = color
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(const Offset(0, -15), 10, fill);
        canvas.drawCircle(
          const Offset(0, -15),
          5,
          Paint()..color = const Color(0xFFF2DBA3),
        );
        canvas.drawArc(
          const Rect.fromLTWH(-15, -30, 30, 30),
          .1,
          math.pi * .82,
          false,
          line..strokeWidth = 3,
        );
        canvas.drawLine(const Offset(-7, 7), const Offset(7, 7), line);
      case CardFamily.magic:
        final bottle = Path()
          ..moveTo(-5, -19)
          ..lineTo(5, -19)
          ..lineTo(5, -7)
          ..cubicTo(22, 3, 20, 23, 0, 25)
          ..cubicTo(-20, 23, -22, 3, -5, -7)
          ..close();
        canvas.drawPath(bottle, Paint()..color = color.withValues(alpha: .18));
        canvas.drawPath(bottle, line..strokeWidth = 2.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-8, -24, 16, 6),
            const Radius.circular(2),
          ),
          fill,
        );
        canvas.drawArc(
          const Rect.fromLTWH(-13, 0, 26, 20),
          0,
          math.pi,
          false,
          fill,
        );
        canvas.drawCircle(
          const Offset(-4, 7),
          2,
          Paint()..color = const Color(0xFFF2DBA3),
        );
        canvas.drawCircle(
          const Offset(4, 12),
          1.5,
          Paint()..color = const Color(0xFFF2DBA3),
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BattleCardArt oldDelegate) =>
      oldDelegate.family != family || oldDelegate.color != color;
}
