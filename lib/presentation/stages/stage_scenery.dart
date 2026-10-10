import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Resolution-independent chapter illustration, also used if art is unavailable.
/// The scenic edges leave the board/arena's middle deliberately uncluttered.
class StageScenery extends CustomPainter {
  final int stage;
  const StageScenery(this.stage);

  static const colors = [
    Color(0xFFE0E4CA),
    Color(0xFFECD4AD),
    Color(0xFFCBDAD6),
    Color(0xFFE4CFD2),
    Color(0xFFE8CAAA),
    Color(0xFFD8D3E8),
  ];
  static const _roofs = [
    Color(0xFF557A68),
    Color(0xFFA66347),
    Color(0xFF477C7E),
    Color(0xFF79516F),
    Color(0xFFA15D48),
    Color(0xFF726D9C),
  ];
  static const _ink = Color(0xFF544B43);
  static const _gold = Color(0xFFC9A361);
  static const _paper = Color(0xFFF5ECD9);

  @override
  void paint(Canvas canvas, Size size) {
    final chapter = stage.clamp(1, 6).toInt();
    final ground = colors[chapter - 1], roof = _roofs[chapter - 1];
    canvas.save();
    canvas.scale(size.width / 900, size.height / 560);
    const bounds = Rect.fromLTWH(0, 0, 900, 560);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(ground, _paper, .55)!,
            ground,
            Color.lerp(ground, roof, .12)!,
          ],
          stops: const [0, .6, 1],
        ).createShader(bounds),
    );
    _sky(canvas, chapter, roof);
    if (chapter == 4) {
      _theatre(canvas, roof);
    } else {
      _hills(canvas, roof);
      _city(canvas, chapter, roof);
    }
    _courtyard(canvas, ground, roof);
    if (chapter == 1) {
      _tree(canvas, 54, 356, 1.3, const Color(0xFFCE9CA1));
      _tree(canvas, 847, 328, 1.2, const Color(0xFFD2A2A4));
    } else if (chapter == 3) {
      _gear(canvas, const Offset(93, 227), 46, _gold);
      _gear(canvas, const Offset(822, 296), 26, _gold);
    } else if (chapter == 6) {
      _orrery(canvas, const Offset(450, 116), roof);
    }
    _foreground(canvas, chapter, roof);
    canvas.restore();
  }

  void _sky(Canvas c, int chapter, Color roof) {
    if (chapter == 6) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 900, 200),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4E5478), Color(0xFFD4CEE2)],
          ).createShader(const Rect.fromLTWH(0, 0, 900, 200)),
      );
      for (var i = 0; i < 46; i++) {
        final p = Offset(
          (i * 137 % 900).toDouble(),
          12 + (i * 59 % 160).toDouble(),
        );
        c.drawCircle(
          p,
          i % 5 == 0 ? 1.6 : .8,
          Paint()..color = _paper.withValues(alpha: .8),
        );
      }
    } else {
      c.drawCircle(
        const Offset(651, 79),
        38,
        Paint()..color = const Color(0x40FFFFE7),
      );
      c.drawCircle(
        const Offset(651, 79),
        26,
        Paint()..color = const Color(0x55FFFFEF),
      );
      for (var i = 0; i < 6; i++) {
        final x = i * 180.0 - 28, y = 50 + (i % 3) * 22.0;
        c.drawOval(
          Rect.fromLTWH(x, y, 128, 20),
          Paint()..color = _paper.withValues(alpha: .6),
        );
        c.drawOval(
          Rect.fromLTWH(x + 28, y - 10, 64, 25),
          Paint()..color = _paper.withValues(alpha: .6),
        );
      }
    }
  }

  void _hills(Canvas c, Color roof) {
    for (var layer = 0; layer < 3; layer++) {
      final y = 140 + layer * 27.0;
      final p = Path()..moveTo(0, y + 40);
      for (var x = 0; x < 900; x += 150) {
        p.quadraticBezierTo(
          x + 60.0,
          y - 25 - ((x + layer * 13) % 50),
          x + 150.0,
          y + 25,
        );
      }
      p.lineTo(900, 280);
      p.lineTo(0, 280);
      p.close();
      c.drawPath(
        p,
        Paint()..color = roof.withValues(alpha: .07 + layer * .035),
      );
    }
  }

  void _city(Canvas c, int chapter, Color roof) {
    // Small distant silhouettes and two larger wings frame an open central view.
    for (var i = 0; i < 9; i++) {
      final x = 218 + i * 53.0, height = 34.0 + (i * 19 % 39);
      _building(
        c,
        Rect.fromLTWH(x, 198 - height, 37, height),
        roof.withValues(alpha: .38),
        chapter,
        distant: true,
      );
    }
    _building(c, const Rect.fromLTWH(-25, 92, 162, 226), roof, chapter);
    _building(c, const Rect.fromLTWH(109, 143, 84, 145), roof, chapter);
    _building(c, const Rect.fromLTWH(763, 87, 163, 231), roof, chapter);
    _building(c, const Rect.fromLTWH(702, 149, 74, 137), roof, chapter);
    if (chapter == 1 || chapter == 2) {
      c.drawLine(
        const Offset(44, 50),
        const Offset(856, 50),
        Paint()
          ..color = _gold.withValues(alpha: .7)
          ..strokeWidth = 1,
      );
      for (var i = 0; i < 13; i++) {
        final x = 72 + i * 63.0, y = 47 + 18 * math.sin(i / 12 * math.pi);
        c.drawLine(
          Offset(x, 50),
          Offset(x, y + 14),
          Paint()
            ..color = _gold
            ..strokeWidth = 1,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 3, y + 10, 6, 10),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFFFD993),
        );
      }
    }
  }

  void _building(
    Canvas c,
    Rect r,
    Color roof,
    int chapter, {
    bool distant = false,
  }) {
    final wall = Color.lerp(_paper, roof, distant ? .22 : .14)!;
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      Paint()..color = wall,
    );
    c.drawRect(
      Rect.fromLTWH(r.right - r.width * .16, r.top, r.width * .16, r.height),
      Paint()..color = roof.withValues(alpha: .15),
    );
    final cap = Path()
      ..moveTo(r.left - 7, r.top)
      ..lineTo(r.center.dx, r.top - r.width * .4)
      ..lineTo(r.right + 7, r.top)
      ..close();
    c.drawPath(cap, Paint()..color = roof);
    c.drawLine(
      Offset(r.left - 6, r.top),
      Offset(r.right + 6, r.top),
      Paint()
        ..color = _gold
        ..strokeWidth = distant ? 1 : 3,
    );
    if (distant) return;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final x = r.left + r.width * (.16 + col * .26),
            y = r.top + 23 + row * (r.height - 42) / 3;
        final window = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, r.width * .13, 28),
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
        );
        c.drawRRect(window, Paint()..color = roof.withValues(alpha: .8));
        c.drawRRect(
          window.deflate(3),
          Paint()..color = const Color(0xFFE5CA91),
        );
        c.drawLine(
          Offset(x + r.width * .065, y + 3),
          Offset(x + r.width * .065, y + 26),
          Paint()
            ..color = roof
            ..strokeWidth = 1.4,
        );
      }
    }
    for (var row = 1; row < 4; row++) {
      c.drawLine(
        Offset(r.left, r.top + row * r.height / 4),
        Offset(r.right, r.top + row * r.height / 4),
        Paint()
          ..color = _gold.withValues(alpha: .3)
          ..strokeWidth = 2,
      );
    }
    if (chapter == 2) {
      for (var i = 0; i < 7; i++) {
        c.drawRect(
          Rect.fromLTWH(
            r.left - 5 + i * (r.width + 10) / 7,
            r.bottom - 36,
            (r.width + 10) / 7,
            18,
          ),
          Paint()..color = i.isEven ? roof : _paper,
        );
      }
    } else if (chapter == 3) {
      c.drawRect(
        Rect.fromLTWH(r.left + 14, r.top - 56, 15, 49),
        Paint()..color = _gold,
      );
      c.drawOval(
        Rect.fromLTWH(r.left - 3, r.top - 82, 39, 17),
        Paint()..color = _paper.withValues(alpha: .7),
      );
    } else if (chapter == 5) {
      for (var i = 0; i < 5; i++) {
        c.drawRect(
          Rect.fromLTWH(r.left + i * r.width / 5, r.top - 11, r.width / 9, 17),
          Paint()..color = wall,
        );
      }
      final banner = Path()
        ..moveTo(r.center.dx - 11, r.top + 34)
        ..lineTo(r.center.dx + 11, r.top + 34)
        ..lineTo(r.center.dx + 11, r.top + 100)
        ..lineTo(r.center.dx, r.top + 110)
        ..lineTo(r.center.dx - 11, r.top + 100)
        ..close();
      c.drawPath(banner, Paint()..color = roof);
      c.drawCircle(Offset(r.center.dx, r.top + 57), 6, Paint()..color = _gold);
    }
  }

  void _theatre(Canvas c, Color roof) {
    c.drawRect(
      const Rect.fromLTWH(0, 0, 900, 198),
      Paint()..color = roof.withValues(alpha: .28),
    );
    c.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(275, 62, 350, 150),
        topLeft: const Radius.circular(130),
        topRight: const Radius.circular(130),
      ),
      Paint()..color = _paper.withValues(alpha: .6),
    );
    for (final x in [38.0, 822.0]) {
      c.drawRect(Rect.fromLTWH(x, 0, 40, 319), Paint()..color = _gold);
      c.drawRect(Rect.fromLTWH(x + 7, 0, 26, 319), Paint()..color = _paper);
    }
    for (final mirror in [false, true]) {
      c.save();
      if (mirror) {
        c.translate(900, 0);
        c.scale(-1, 1);
      }
      final curtain = Path()
        ..moveTo(0, 0)
        ..lineTo(198, 0)
        ..cubicTo(167, 113, 62, 178, 101, 359)
        ..lineTo(0, 391)
        ..close();
      c.drawPath(curtain, Paint()..color = roof);
      for (var i = 0; i < 5; i++) {
        final pleat = Path()
          ..moveTo(23 + i * 30.0, 0)
          ..cubicTo(26 + i * 25.0, 123, 19 + i * 12.0, 220, 17 + i * 16.0, 366);
        c.drawPath(
          pleat,
          Paint()
            ..color = _paper.withValues(alpha: .12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9,
        );
      }
      c.drawLine(
        const Offset(38, 219),
        const Offset(102, 203),
        Paint()
          ..color = _gold
          ..strokeWidth = 7,
      );
      c.restore();
    }
    c.drawLine(
      const Offset(450, 0),
      const Offset(450, 53),
      Paint()
        ..color = _gold
        ..strokeWidth = 3,
    );
    c.drawOval(
      const Rect.fromLTWH(402, 40, 96, 34),
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    for (var i = 0; i < 7; i++)
      c.drawCircle(
        Offset(408 + i * 14.0, 59 + 12 * math.sin(i / 6 * math.pi)),
        4,
        Paint()..color = const Color(0xFFFFE9B8),
      );
  }

  void _courtyard(Canvas c, Color ground, Color roof) {
    final p = Path()
      ..moveTo(180, 254)
      ..quadraticBezierTo(450, 214, 720, 254)
      ..lineTo(900, 560)
      ..lineTo(0, 560)
      ..close();
    c.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ground, Color.lerp(ground, _paper, .25)!],
        ).createShader(const Rect.fromLTWH(0, 220, 900, 340)),
    );
    final line = Paint()
      ..color = roof.withValues(alpha: .075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final y in [308.0, 379.0, 477.0])
      c.drawArc(
        Rect.fromCenter(center: Offset(450, y), width: 1200, height: 100),
        0,
        math.pi,
        false,
        line,
      );
    for (final x in [-180.0, 60.0, 300.0, 600.0, 840.0, 1080.0])
      c.drawLine(const Offset(450, 210), Offset(x, 560), line);
  }

  void _tree(Canvas c, double x, double y, double scale, Color bloom) {
    c.save();
    c.translate(x, y);
    c.scale(scale);
    c.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(3, -114)
        ..moveTo(1, -54)
        ..lineTo(-25, -89)
        ..moveTo(2, -72)
        ..lineTo(33, -113),
      Paint()
        ..color = const Color(0xFF8B7760)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 17; i++) {
      final a = i * 2.4, radius = 8.0 + (i % 5) * 8;
      c.drawCircle(
        Offset(math.cos(a) * radius, -112 + math.sin(a) * radius * .7),
        13 + (i % 3) * 3.0,
        Paint()..color = Color.lerp(bloom, _paper, (i % 4) * .12)!,
      );
    }
    c.restore();
  }

  void _gear(Canvas c, Offset center, double radius, Color color) {
    c.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    c.drawCircle(center, radius * .24, Paint()..color = color);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6, p = Offset(math.cos(a), math.sin(a));
      c.drawLine(
        center + p * radius * .15,
        center + p * radius * 1.14,
        Paint()
          ..color = color
          ..strokeWidth = 5,
      );
    }
  }

  void _orrery(Canvas c, Offset center, Color roof) {
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(i * math.pi / 3);
      c.drawOval(
        const Rect.fromLTWH(-48, -18, 96, 36),
        Paint()
          ..color = _gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      c.restore();
    }
    c.drawCircle(center, 10, Paint()..color = _paper);
  }

  void _foreground(Canvas c, int chapter, Color roof) {
    for (final x in [30.0, 854.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 17, 452, 48, 88),
          const Radius.circular(3),
        ),
        Paint()..color = Color.lerp(_paper, roof, .3)!,
      );
      c.drawRect(Rect.fromLTWH(x - 22, 448, 58, 9), Paint()..color = _paper);
      c.drawRect(Rect.fromLTWH(x - 4, 424, 22, 25), Paint()..color = _gold);
      c.drawRect(
        Rect.fromLTWH(x, 428, 14, 17),
        Paint()..color = const Color(0xFFFFE6AC),
      );
      c.drawPath(
        Path()
          ..moveTo(x - 9, 424)
          ..lineTo(x + 7, 413)
          ..lineTo(x + 23, 424)
          ..close(),
        Paint()..color = _ink,
      );
    }
    for (var i = 0; i < 22; i++) {
      final left = i.isEven,
          x = left
              ? (i * 17 % 120).toDouble()
              : 900 - (i * 19 % 125).toDouble();
      final y = 509 + (i * 23 % 52).toDouble();
      c.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 19, height: 8),
        Paint()..color = const Color(0xFF6C8261).withValues(alpha: .65),
      );
      if (i % 3 == 0)
        c.drawCircle(
          Offset(x + 3, y - 5),
          4,
          Paint()..color = chapter == 6 ? _paper : const Color(0xFFD4A09C),
        );
    }
  }

  @override
  bool shouldRepaint(covariant StageScenery old) => old.stage != stage;
}
