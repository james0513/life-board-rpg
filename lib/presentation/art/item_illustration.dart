import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/shop_item.dart';

/// The emporium's hand-drawn catalog. These silhouettes are intentionally
/// independent from the character renderer: an item is an object, not a doll.
abstract final class AtelierPalette {
  static const ink = Color(0xFF203D34);
  static const forest = Color(0xFF183C32);
  static const paper = Color(0xFFF6F0E2);
  static const cream = Color(0xFFFFFBF1);
  static const gold = Color(0xFFAA813F);
  static const clay = Color(0xFFB56849);
  static const muted = Color(0xFF727365);
  static const line = Color(0xFFDDD3BE);
}

String itemEdition(ShopItem item) => item.unlockStage >= 6
    ? '傳說珍藏'
    : item.unlockStage >= 4
    ? '稀有工藝'
    : item.unlockStage >= 2
    ? '冒險精選'
    : item.kind == ShopKind.training
    ? '成長課程'
    : item.kind == ShopKind.item
    ? '旅途常備'
    : '工坊經典';

Color itemAccent(ShopItem item) => item.unlockStage >= 6
    ? const Color(0xFF9A7132)
    : item.unlockStage >= 4
    ? const Color(0xFF745783)
    : item.kind == ShopKind.item
    ? AtelierPalette.clay
    : AtelierPalette.forest;

class ItemIllustration extends StatelessWidget {
  final String itemId;
  final double width;
  final double height;
  final bool framed;
  const ItemIllustration({
    super.key,
    required this.itemId,
    this.width = 180,
    this.height = 180,
    this.framed = true,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: itemId == 'none' ? '空的裝備展示台' : '${shopById(itemId).name}插畫',
    child: RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _ItemPainter(
            itemId == 'none' ? itemId : shopById(itemId).visualId,
            framed,
          ),
        ),
      ),
    ),
  );
}

class _ItemPainter extends CustomPainter {
  final String id;
  final bool framed;
  const _ItemPainter(this.id, this.framed);
  static const dark = Color(0xFF3F4033);
  static const gold = Color(0xFFC39A52);
  static const lightGold = Color(0xFFEBD5A0);
  static const steel = Color(0xFFBCCCD0);
  static const teal = Color(0xFF487B73);
  static const ivory = Color(0xFFFFF3D5);

  void line(Canvas c, Offset a, Offset b, Color color, [double w = 2]) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );

  void shape(Canvas c, Path p, Color color, {double stroke = 1.6}) {
    c.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, ivory, .2)!,
            color,
            Color.lerp(color, dark, .24)!,
          ],
        ).createShader(const Rect.fromLTWH(35, 25, 125, 155)),
    );
    c.drawPath(
      p,
      Paint()
        ..color = dark.withValues(alpha: .82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void gem(Canvas c, Offset o, double r, Color color) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r)
      ..lineTo(o.dx + r * .76, o.dy - r * .26)
      ..lineTo(o.dx + r * .63, o.dy + r * .6)
      ..lineTo(o.dx, o.dy + r)
      ..lineTo(o.dx - r * .63, o.dy + r * .6)
      ..lineTo(o.dx - r * .76, o.dy - r * .26)
      ..close();
    shape(c, p, color);
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - r)
        ..lineTo(o.dx, o.dy + r)
        ..lineTo(o.dx - r * .63, o.dy + r * .6)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .24),
    );
    line(
      c,
      Offset(o.dx - r * .32, o.dy - r * .4),
      Offset(o.dx - r * .08, o.dy - r * .65),
      ivory,
      2.5,
    );
  }

  void star(Canvas c, Offset o, double r, Color color, [int points = 4]) {
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final a = -math.pi / 2 + i * math.pi / points;
      final d = i.isEven ? r : r * .35;
      final x = o.dx + math.cos(a) * d, y = o.dy + math.sin(a) * d;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
    c.drawPath(p, Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 200;
    canvas.save();
    canvas.translate(
      (size.width - 200 * scale) / 2,
      (size.height - 200 * scale) / 2,
    );
    canvas.scale(scale);
    if (framed) {
      canvas.drawCircle(
        const Offset(100, 100),
        83,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFFDF8E8), Color(0xFFE9DFC8)],
          ).createShader(const Rect.fromLTWH(17, 17, 166, 166)),
      );
      canvas.drawCircle(
        const Offset(100, 100),
        84,
        Paint()
          ..color = gold.withValues(alpha: .36)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
      canvas.drawArc(
        const Rect.fromLTWH(10, 10, 180, 180),
        -.8,
        2.1,
        false,
        Paint()
          ..color = gold.withValues(alpha: .48)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.drawArc(
        const Rect.fromLTWH(10, 10, 180, 180),
        2.34,
        2.1,
        false,
        Paint()
          ..color = gold.withValues(alpha: .48)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      for (final o in [const Offset(27, 46), const Offset(173, 152)])
        star(canvas, o, 4, gold.withValues(alpha: .65));
      for (var i = 0; i < 9; i++) {
        final a = 2.25 + i * .1;
        final p = Offset(100 + math.cos(a) * 90, 100 + math.sin(a) * 90);
        line(
          canvas,
          p,
          p + Offset(math.cos(a - .6) * 6, math.sin(a - .6) * 6),
          gold.withValues(alpha: .48),
          1,
        );
      }
    }
    canvas.drawOval(
      const Rect.fromLTWH(56, 163, 90, 12),
      Paint()..color = dark.withValues(alpha: .09),
    );
    switch (id) {
      case 'sword':
        sword(canvas);
        break;
      case 'spellblade':
        sword(canvas, rune: true);
        break;
      case 'dawnblade':
        sword(canvas, dawn: true);
        break;
      case 'staff':
        staff(canvas);
        break;
      case 'astral_staff':
        staff(canvas, astral: true);
        break;
      case 'frost_wand':
        frost(canvas);
        break;
      case 'longbow':
        bow(canvas);
        break;
      case 'fate_bow':
        bow(canvas, fate: true);
        break;
      case 'ember_spear':
        spear(canvas);
        break;
      case 'thunder_hammer':
        hammer(canvas);
        break;
      case 'moon_blades':
        twinBlades(canvas);
        break;
      case 'coat':
        leather(canvas);
        break;
      case 'robe':
        robe(canvas);
        break;
      case 'plate':
        armor(canvas);
        break;
      case 'ranger_cloak':
        cloak(canvas);
        break;
      case 'scholar_coat':
        scholar(canvas);
        break;
      case 'flame_armor':
        armor(canvas, flame: true);
        break;
      case 'astral_robe':
        robe(canvas, astral: true);
        break;
      case 'ring':
        ring(canvas);
        break;
      case 'ruby_ring':
        ring(canvas, ruby: true);
        break;
      case 'pendant':
        pendant(canvas);
        break;
      case 'sapphire_pendant':
        pendant(canvas, sapphire: true);
        break;
      case 'charm':
        badge(canvas);
        break;
      case 'guardian_brooch':
        badge(canvas, guardian: true);
        break;
      case 'wing_charm':
        wings(canvas);
        break;
      case 'potion':
        bottle(canvas);
        break;
      case 'ether':
        bottle(canvas, ether: true);
        break;
      case 'train_stamina':
        training(canvas, 0);
        break;
      case 'train_intelligence':
        training(canvas, 1);
        break;
      case 'train_charm':
        training(canvas, 2);
        break;
      case 'train_morality':
        training(canvas, 3);
        break;
      default:
        star(canvas, const Offset(100, 96), 20, gold.withValues(alpha: .55));
    }
    canvas.restore();
  }

  void sword(Canvas c, {bool rune = false, bool dawn = false}) {
    c.save();
    c.translate(100, 100);
    c.rotate(.52);
    c.translate(-100, -100);
    final blade = Path()
      ..moveTo(100, 23)
      ..lineTo(dawn ? 119 : 111, 47)
      ..lineTo(dawn ? 114 : 108, 120)
      ..lineTo(100, 128)
      ..lineTo(dawn ? 86 : 92, 120)
      ..lineTo(dawn ? 81 : 89, 47)
      ..close();
    shape(
      c,
      blade,
      dawn
          ? lightGold
          : rune
          ? const Color(0xFFACA7CD)
          : steel,
    );
    line(c, const Offset(100, 29), const Offset(100, 121), ivory, 1.6);
    if (rune || dawn)
      for (var y = 55.0; y < 112; y += 17) {
        line(
          c,
          Offset(97, y),
          Offset(103, y + 5),
          rune ? const Color(0xFF77709A) : gold,
          1.5,
        );
        line(
          c,
          Offset(103, y + 5),
          Offset(97, y + 10),
          rune ? const Color(0xFF77709A) : gold,
          1.5,
        );
      }
    shape(
      c,
      Path()
        ..moveTo(73, 118)
        ..quadraticBezierTo(100, 125, 127, 118)
        ..lineTo(125, 131)
        ..quadraticBezierTo(100, 125, 75, 131)
        ..close(),
      gold,
    );
    shape(
      c,
      Path()
        ..moveTo(94, 129)
        ..lineTo(106, 129)
        ..lineTo(105, 161)
        ..lineTo(95, 161)
        ..close(),
      const Color(0xFF805345),
    );
    for (var y = 135.0; y < 160; y += 6)
      line(c, Offset(95, y), Offset(105, y - 3), lightGold, 1.4);
    gem(c, const Offset(100, 166), 7, dawn ? const Color(0xFFC27D39) : teal);
    if (dawn) {
      for (final sign in [-1, 1])
        shape(
          c,
          Path()
            ..moveTo(100 + sign * 11, 121)
            ..lineTo(100 + sign * 23, 105)
            ..lineTo(100 + sign * 21, 123)
            ..close(),
          lightGold,
        );
      star(c, const Offset(139, 53), 7, gold);
      star(c, const Offset(64, 76), 4, gold);
    }
    c.restore();
  }

  void staff(Canvas c, {bool astral = false}) {
    c.save();
    c.translate(100, 100);
    c.rotate(.26);
    c.translate(-100, -100);
    shape(
      c,
      Path()
        ..moveTo(96, 65)
        ..lineTo(104, 65)
        ..lineTo(102, 174)
        ..lineTo(96, 174)
        ..close(),
      astral ? gold : const Color(0xFF815F43),
    );
    for (var y = 84.0; y < 164; y += 14)
      line(c, Offset(97, y), Offset(103, y - 5), lightGold, 2);
    final fork = Path()
      ..moveTo(96, 79)
      ..cubicTo(63, 68, 69, 34, 83, 32)
      ..cubicTo(75, 52, 83, 68, 100, 68)
      ..cubicTo(117, 68, 125, 52, 117, 32)
      ..cubicTo(137, 44, 128, 69, 104, 79)
      ..close();
    shape(c, fork, gold);
    gem(
      c,
      const Offset(100, 45),
      astral ? 23 : 20,
      astral ? const Color(0xFF9081B3) : const Color(0xFF75B4B0),
    );
    if (astral) {
      c.drawOval(
        const Rect.fromLTWH(66, 38, 68, 23),
        Paint()
          ..color = lightGold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      star(c, const Offset(134, 34), 6, gold);
      star(c, const Offset(67, 71), 4, gold);
      gem(c, const Offset(100, 92), 7, const Color(0xFF9081B3));
    } else {
      line(c, const Offset(82, 72), const Offset(77, 98), gold, 1.4);
      gem(c, const Offset(77, 100), 5, teal);
    }
    c.restore();
  }

  void frost(Canvas c) {
    c.save();
    c.translate(100, 100);
    c.rotate(.32);
    c.translate(-100, -100);
    shape(
      c,
      Path()
        ..moveTo(96, 72)
        ..lineTo(103, 72)
        ..lineTo(106, 170)
        ..lineTo(98, 174)
        ..close(),
      const Color(0xFF87A8B7),
    );
    shape(
      c,
      Path()
        ..moveTo(92, 81)
        ..cubicTo(63, 62, 78, 28, 101, 25)
        ..cubicTo(80, 45, 90, 66, 113, 63)
        ..quadraticBezierTo(106, 77, 92, 81)
        ..close(),
      steel,
    );
    for (final o in [
      const Offset(100, 48),
      const Offset(119, 45),
      const Offset(110, 27),
    ]) {
      star(c, o, o.dx == 100 ? 14 : 6, const Color(0xFF87BBC5), 6);
    }
    line(c, const Offset(96, 86), const Offset(105, 89), gold, 5);
    for (var y = 125.0; y < 162; y += 8)
      line(c, Offset(99, y), Offset(105, y - 3), ivory, 2);
    c.restore();
  }

  void bow(Canvas c, {bool fate = false}) {
    c.save();
    c.translate(100, 100);
    c.rotate(.23);
    c.translate(-100, -100);
    final p = Path()
      ..moveTo(78, 27)
      ..cubicTo(150, 46, 151, 145, 78, 174)
      ..cubicTo(123, 132, 124, 66, 78, 27)
      ..close();
    shape(c, p, fate ? gold : teal);
    line(
      c,
      const Offset(78, 29),
      const Offset(78, 173),
      const Color(0xFFA68E68),
      1.4,
    );
    line(
      c,
      const Offset(52, 102),
      const Offset(149, 102),
      const Color(0xFF8A6745),
      3,
    );
    shape(
      c,
      Path()
        ..moveTo(159, 102)
        ..lineTo(143, 94)
        ..lineTo(145, 102)
        ..lineTo(143, 110)
        ..close(),
      fate ? gold : steel,
    );
    for (var x = 52.0; x < 67; x += 5)
      line(c, Offset(x, 102), Offset(x - 5, 94), ivory, 3);
    shape(
      c,
      Path()
        ..moveTo(120, 88)
        ..lineTo(129, 87)
        ..lineTo(129, 117)
        ..lineTo(120, 116)
        ..close(),
      const Color(0xFF735039),
    );
    for (var y = 94.0; y < 115; y += 6)
      line(c, Offset(120, y), Offset(129, y - 2), lightGold, 1.5);
    if (fate) {
      for (final y in [53.0, 145.0])
        gem(c, Offset(108, y), 7, const Color(0xFFAF85B7));
      star(c, const Offset(62, 59), 8, gold);
      star(c, const Offset(150, 138), 5, gold);
      for (final sign in [-1, 1])
        shape(
          c,
          Path()
            ..moveTo(109, 100 + sign * 42)
            ..lineTo(133, 100 + sign * 63)
            ..lineTo(126, 100 + sign * 40)
            ..close(),
          lightGold,
        );
    }
    c.restore();
  }

  void spear(Canvas c) {
    c.save();
    c.translate(100, 100);
    c.rotate(.39);
    c.translate(-100, -100);
    line(c, const Offset(100, 67), const Offset(100, 180), dark, 8);
    line(
      c,
      const Offset(99, 68),
      const Offset(99, 178),
      const Color(0xFF986D4E),
      4,
    );
    shape(
      c,
      Path()
        ..moveTo(100, 16)
        ..lineTo(115, 51)
        ..lineTo(105, 71)
        ..lineTo(95, 71)
        ..lineTo(84, 53)
        ..close(),
      const Color(0xFFD88C57),
    );
    line(c, const Offset(100, 23), const Offset(100, 63), lightGold, 2);
    shape(
      c,
      Path()
        ..moveTo(97, 77)
        ..quadraticBezierTo(68, 65, 68, 43)
        ..quadraticBezierTo(90, 54, 97, 77)
        ..close(),
      AtelierPalette.clay,
    );
    line(c, const Offset(98, 74), const Offset(76, 53), gold, 1.5);
    shape(
      c,
      Path()
        ..moveTo(105, 75)
        ..quadraticBezierTo(130, 76, 128, 99)
        ..quadraticBezierTo(115, 87, 105, 75)
        ..close(),
      const Color(0xFFC98253),
    );
    line(c, const Offset(91, 74), const Offset(109, 74), gold, 5);
    for (var y = 129.0; y < 162; y += 7)
      line(c, Offset(97, y), Offset(103, y - 3), lightGold, 2);
    c.restore();
  }

  void hammer(Canvas c) {
    c.save();
    c.translate(100, 100);
    c.rotate(.42);
    c.translate(-100, -100);
    shape(
      c,
      Path()
        ..moveTo(94, 72)
        ..lineTo(105, 72)
        ..lineTo(107, 168)
        ..lineTo(92, 168)
        ..close(),
      const Color(0xFF785240),
    );
    for (var y = 117.0; y < 159; y += 8)
      line(c, Offset(94, y), Offset(105, y - 4), gold, 2);
    shape(
      c,
      Path()
        ..moveTo(53, 39)
        ..lineTo(139, 39)
        ..lineTo(149, 47)
        ..lineTo(149, 80)
        ..lineTo(139, 87)
        ..lineTo(53, 87)
        ..lineTo(47, 77)
        ..lineTo(47, 50)
        ..close(),
      const Color(0xFF7C849D),
    );
    for (final x in [59.0, 129.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 37, 12, 53),
          const Radius.circular(3),
        ),
        Paint()..color = gold,
      );
      for (final y in [45.0, 81.0])
        c.drawCircle(Offset(x + 6, y), 2, Paint()..color = lightGold);
    }
    shape(
      c,
      Path()
        ..moveTo(102, 43)
        ..lineTo(87, 66)
        ..lineTo(101, 65)
        ..lineTo(93, 84)
        ..lineTo(118, 56)
        ..lineTo(103, 58)
        ..close(),
      ivory,
      stroke: 1,
    );
    gem(c, const Offset(99, 172), 8, gold);
    c.restore();
  }

  void twinBlades(Canvas c) {
    for (final sign in [-1.0, 1.0]) {
      c.save();
      c.translate(100 + sign * 24, 104);
      c.rotate(sign * .43);
      c.translate(-100, -100);
      shape(
        c,
        Path()
          ..moveTo(97, 27)
          ..cubicTo(128, 48, 127, 88, 106, 124)
          ..lineTo(97, 123)
          ..quadraticBezierTo(109, 76, 97, 27)
          ..close(),
        const Color(0xFFADB0CD),
      );
      line(c, const Offset(107, 61), const Offset(105, 110), ivory, 1.5);
      shape(
        c,
        Path()
          ..moveTo(83, 122)
          ..quadraticBezierTo(103, 133, 118, 118)
          ..lineTo(115, 131)
          ..lineTo(84, 134)
          ..close(),
        gold,
      );
      line(
        c,
        const Offset(100, 137),
        const Offset(100, 164),
        const Color(0xFF66516B),
        8,
      );
      for (var y = 142.0; y < 164; y += 7)
        line(c, Offset(96, y), Offset(104, y - 3), gold, 1.2);
      gem(c, const Offset(100, 168), 6, const Color(0xFF9980AA));
      c.restore();
    }
    star(c, const Offset(100, 37), 6, gold);
  }

  Path garment({bool long = false}) => Path()
    ..moveTo(76, 44)
    ..quadraticBezierTo(100, 53, 124, 44)
    ..lineTo(146, 60)
    ..lineTo(160, 99)
    ..lineTo(140, 108)
    ..lineTo(129, 86)
    ..lineTo(long ? 143 : 130, long ? 164 : 146)
    ..quadraticBezierTo(100, long ? 177 : 157, long ? 57 : 70, long ? 164 : 146)
    ..lineTo(71, 86)
    ..lineTo(60, 108)
    ..lineTo(40, 99)
    ..lineTo(54, 60)
    ..close();

  void leather(Canvas c) {
    shape(c, garment(), const Color(0xFFA77953));
    shape(
      c,
      Path()
        ..moveTo(77, 44)
        ..lineTo(99, 60)
        ..lineTo(82, 83)
        ..lineTo(65, 58)
        ..close(),
      const Color(0xFFE5CBA0),
    );
    shape(
      c,
      Path()
        ..moveTo(124, 44)
        ..lineTo(101, 60)
        ..lineTo(118, 83)
        ..lineTo(135, 58)
        ..close(),
      const Color(0xFFE5CBA0),
    );
    line(
      c,
      const Offset(100, 64),
      const Offset(100, 150),
      const Color(0xFF644A36),
      2,
    );
    for (var y = 84.0; y < 139; y += 12)
      c.drawCircle(Offset(104, y), 2.3, Paint()..color = gold);
    line(
      c,
      const Offset(73, 95),
      const Offset(128, 123),
      const Color(0xFF69513B),
      9,
    );
    line(
      c,
      const Offset(72, 129),
      const Offset(129, 129),
      const Color(0xFF624B36),
      8,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(93, 123, 15, 12),
        const Radius.circular(2),
      ),
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (final x in [77.0, 113.0])
      line(c, Offset(x, 137), Offset(x + 10, 137), lightGold, 1.2);
  }

  void robe(Canvas c, {bool astral = false}) {
    shape(
      c,
      garment(long: true),
      astral ? const Color(0xFF6E5D85) : const Color(0xFF5B718F),
    );
    shape(
      c,
      Path()
        ..moveTo(74, 44)
        ..lineTo(100, 59)
        ..lineTo(125, 44)
        ..lineTo(116, 75)
        ..lineTo(100, 91)
        ..lineTo(85, 75)
        ..close(),
      astral ? const Color(0xFFBFA6C2) : const Color(0xFFB4BFCC),
    );
    line(c, const Offset(100, 83), const Offset(100, 164), gold, 5);
    line(c, const Offset(73, 155), const Offset(127, 155), gold, 2);
    line(c, const Offset(78, 103), const Offset(122, 103), gold, 6);
    gem(
      c,
      const Offset(100, 103),
      8,
      astral ? const Color(0xFFA9BAD0) : const Color(0xFF6AABB2),
    );
    for (final p in [
      const Offset(77, 141),
      const Offset(120, 135),
      const Offset(65, 82),
      const Offset(136, 84),
    ])
      star(c, p, astral ? 6 : 4, lightGold);
    if (astral) {
      line(c, const Offset(77, 141), const Offset(89, 122), lightGold, 1);
      line(c, const Offset(89, 122), const Offset(120, 135), lightGold, 1);
      for (final x in [72.0, 128.0])
        line(c, Offset(x, 122), Offset(x - 7, 159), gold, 1);
      c.drawArc(
        const Rect.fromLTWH(90, 49, 20, 22),
        .2,
        math.pi * 1.5,
        false,
        Paint()
          ..color = lightGold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void cloak(Canvas c) {
    shape(
      c,
      Path()
        ..moveTo(87, 35)
        ..quadraticBezierTo(103, 26, 116, 39)
        ..lineTo(132, 73)
        ..lineTo(152, 155)
        ..quadraticBezierTo(128, 174, 100, 160)
        ..quadraticBezierTo(76, 176, 48, 154)
        ..lineTo(68, 73)
        ..close(),
      const Color(0xFF497261),
    );
    shape(
      c,
      Path()
        ..moveTo(88, 40)
        ..quadraticBezierTo(102, 27, 115, 42)
        ..lineTo(124, 66)
        ..quadraticBezierTo(102, 87, 77, 65)
        ..close(),
      const Color(0xFF749280),
    );
    shape(
      c,
      Path()
        ..moveTo(88, 46)
        ..quadraticBezierTo(101, 34, 112, 46)
        ..lineTo(113, 64)
        ..quadraticBezierTo(99, 72, 86, 62)
        ..close(),
      const Color(0xFF314E43),
    );
    line(c, const Offset(99, 79), const Offset(75, 160), gold, 2);
    line(c, const Offset(104, 79), const Offset(128, 160), gold, 2);
    for (final p in [
      const Offset(70, 133),
      const Offset(126, 125),
      const Offset(108, 105),
    ]) {
      shape(
        c,
        Path()
          ..moveTo(p.dx, p.dy - 7)
          ..quadraticBezierTo(p.dx + 13, p.dy, p.dx, p.dy + 8)
          ..quadraticBezierTo(p.dx - 6, p.dy, p.dx, p.dy - 7)
          ..close(),
        const Color(0xFF96A575),
        stroke: .8,
      );
    }
    gem(c, const Offset(101, 81), 7, lightGold);
  }

  void scholar(Canvas c) {
    shape(c, garment(long: true), const Color(0xFF476578));
    shape(
      c,
      Path()
        ..moveTo(75, 44)
        ..lineTo(98, 61)
        ..lineTo(89, 88)
        ..lineTo(68, 61)
        ..close(),
      const Color(0xFFD2BE92),
    );
    shape(
      c,
      Path()
        ..moveTo(124, 44)
        ..lineTo(102, 61)
        ..lineTo(111, 88)
        ..lineTo(134, 61)
        ..close(),
      const Color(0xFFD2BE92),
    );
    line(c, const Offset(91, 85), const Offset(85, 162), gold, 3);
    line(c, const Offset(109, 85), const Offset(115, 162), gold, 3);
    for (var y = 100.0; y < 149; y += 15)
      c.drawCircle(Offset(102, y), 2.5, Paint()..color = gold);
    shape(
      c,
      Path()
        ..moveTo(117, 95)
        ..lineTo(133, 95)
        ..lineTo(133, 117)
        ..lineTo(117, 121)
        ..close(),
      const Color(0xFF9D7856),
    );
    line(c, const Offset(119, 98), const Offset(129, 98), lightGold, 2);
    for (final x in [54.0, 145.0])
      line(c, Offset(x, 87), Offset(x + 1, 102), gold, 3);
    star(c, const Offset(80, 120), 6, lightGold);
  }

  void armor(Canvas c, {bool flame = false}) {
    final base = flame ? const Color(0xFFAA6654) : const Color(0xFF8FABB0);
    shape(
      c,
      Path()
        ..moveTo(72, 55)
        ..lineTo(128, 55)
        ..lineTo(137, 100)
        ..lineTo(128, 150)
        ..lineTo(100, 164)
        ..lineTo(72, 150)
        ..lineTo(63, 100)
        ..close(),
      base,
    );
    for (final sign in [-1.0, 1.0]) {
      shape(
        c,
        Path()
          ..moveTo(100 + sign * 23, 53)
          ..quadraticBezierTo(100 + sign * 43, 44, 100 + sign * 57, 64)
          ..lineTo(100 + sign * 50, 87)
          ..lineTo(100 + sign * 28, 79)
          ..close(),
        flame ? const Color(0xFFCD815D) : steel,
      );
      line(
        c,
        Offset(100 + sign * 31, 69),
        Offset(100 + sign * 50, 73),
        gold,
        3,
      );
      if (flame)
        shape(
          c,
          Path()
            ..moveTo(100 + sign * 38, 53)
            ..lineTo(100 + sign * 47, 32)
            ..lineTo(100 + sign * 51, 58)
            ..close(),
          gold,
        );
    }
    shape(
      c,
      Path()
        ..moveTo(77, 62)
        ..lineTo(100, 72)
        ..lineTo(123, 62)
        ..lineTo(120, 111)
        ..lineTo(100, 128)
        ..lineTo(80, 111)
        ..close(),
      flame ? const Color(0xFF8E4B43) : const Color(0xFF64858D),
    );
    line(c, const Offset(100, 75), const Offset(100, 121), lightGold, 2);
    for (var y = 130.0; y < 154; y += 9)
      line(c, Offset(75, y), Offset(125, y), gold, 3);
    if (flame)
      shape(
        c,
        Path()
          ..moveTo(100, 79)
          ..quadraticBezierTo(97, 97, 111, 96)
          ..quadraticBezierTo(117, 112, 101, 117)
          ..quadraticBezierTo(83, 110, 91, 95)
          ..quadraticBezierTo(94, 101, 100, 79)
          ..close(),
        lightGold,
        stroke: 1,
      );
    else
      star(c, const Offset(100, 96), 14, lightGold, 5);
    for (final x in [78.0, 123.0])
      c.drawCircle(Offset(x, 118), 2.2, Paint()..color = lightGold);
  }

  void ring(Canvas c, {bool ruby = false}) {
    c.save();
    c.translate(100, 111);
    c.rotate(-.25);
    c.translate(-100, -111);
    c.drawOval(
      const Rect.fromLTWH(65, 78, 70, 80),
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
    c.drawOval(
      const Rect.fromLTWH(65, 78, 70, 80),
      Paint()
        ..shader = const LinearGradient(
          colors: [lightGold, gold, Color(0xFF8B693B)],
        ).createShader(const Rect.fromLTWH(65, 78, 70, 80))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );
    c.drawArc(
      const Rect.fromLTWH(65, 78, 70, 80),
      2.2,
      1.8,
      false,
      Paint()
        ..color = ivory
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    shape(
      c,
      Path()
        ..moveTo(75, 73)
        ..lineTo(83, 53)
        ..lineTo(116, 53)
        ..lineTo(126, 74)
        ..lineTo(117, 95)
        ..lineTo(84, 95)
        ..close(),
      gold,
    );
    gem(
      c,
      const Offset(100, 71),
      ruby ? 23 : 20,
      ruby ? const Color(0xFFB86265) : const Color(0xFF79ABA9),
    );
    for (final x in [77.0, 123.0])
      c.drawCircle(Offset(x, 103), 3, Paint()..color = lightGold);
    c.restore();
    star(c, const Offset(146, 54), 7, gold);
  }

  void pendant(Canvas c, {bool sapphire = false}) {
    final p = Path()
      ..moveTo(64, 36)
      ..cubicTo(44, 83, 62, 110, 98, 128)
      ..cubicTo(136, 110, 155, 83, 135, 36);
    c.drawPath(
      p,
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4,
    );
    c.drawPath(
      p,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1,
    );
    for (var i = 0; i < 7; i++) {
      final t = i / 6.0;
      c.drawCircle(
        Offset(63 - 5 * math.sin(t * math.pi) + t * 35, 43 + t * 79),
        1.5,
        Paint()..color = lightGold,
      );
    }
    c.drawOval(
      const Rect.fromLTWH(94, 115, 12, 16),
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    if (sapphire) {
      shape(
        c,
        Path()
          ..moveTo(99, 124)
          ..cubicTo(67, 141, 77, 173, 103, 174)
          ..quadraticBezierTo(130, 170, 129, 148)
          ..quadraticBezierTo(107, 167, 102, 143)
          ..close(),
        lightGold,
      );
      gem(c, const Offset(102, 145), 19, const Color(0xFF598AA7));
    } else {
      shape(
        c,
        Path()
          ..moveTo(100, 121)
          ..lineTo(125, 145)
          ..lineTo(100, 174)
          ..lineTo(75, 145)
          ..close(),
        gold,
      );
      gem(c, const Offset(100, 147), 20, const Color(0xFFB46C60));
      for (final p in [
        const Offset(81, 145),
        const Offset(119, 145),
        const Offset(100, 168),
      ])
        c.drawCircle(p, 2, Paint()..color = lightGold);
    }
  }

  void badge(Canvas c, {bool guardian = false}) {
    for (final sign in [-1.0, 1.0])
      shape(
        c,
        Path()
          ..moveTo(100 + sign * 6, 119)
          ..lineTo(100 + sign * 27, 112)
          ..lineTo(100 + sign * 34, 167)
          ..lineTo(100 + sign * 18, 153)
          ..lineTo(100 + sign * 7, 170)
          ..close(),
        guardian ? teal : AtelierPalette.clay,
      );
    if (guardian) {
      shape(
        c,
        Path()
          ..moveTo(62, 58)
          ..quadraticBezierTo(100, 66, 138, 58)
          ..lineTo(132, 110)
          ..quadraticBezierTo(123, 137, 100, 148)
          ..quadraticBezierTo(76, 137, 68, 110)
          ..close(),
        gold,
      );
      shape(
        c,
        Path()
          ..moveTo(74, 73)
          ..quadraticBezierTo(100, 78, 126, 73)
          ..lineTo(122, 108)
          ..quadraticBezierTo(117, 124, 100, 135)
          ..quadraticBezierTo(83, 124, 78, 108)
          ..close(),
        teal,
      );
      star(c, const Offset(100, 100), 19, lightGold, 4);
    } else {
      c.drawCircle(const Offset(100, 96), 42, Paint()..color = dark);
      c.drawCircle(
        const Offset(100, 96),
        40,
        Paint()
          ..shader = const RadialGradient(colors: [lightGold, gold])
              .createShader(const Rect.fromLTWH(60, 56, 80, 80)),
      );
      c.drawCircle(
        const Offset(100, 96),
        32,
        Paint()
          ..color = ivory
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      star(c, const Offset(100, 96), 25, const Color(0xFF6B8570), 5);
      gem(c, const Offset(100, 95), 10, lightGold);
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        c.drawCircle(
          Offset(100 + math.cos(a) * 36, 96 + math.sin(a) * 36),
          1.5,
          Paint()..color = ivory,
        );
      }
    }
  }

  void wings(Canvas c) {
    c.drawOval(
      const Rect.fromLTWH(93, 42, 14, 24),
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (final sign in [-1.0, 1.0]) {
      shape(
        c,
        Path()
          ..moveTo(100, 98)
          ..quadraticBezierTo(100 + sign * 27, 82, 100 + sign * 61, 64)
          ..quadraticBezierTo(100 + sign * 65, 93, 100 + sign * 40, 112)
          ..quadraticBezierTo(100 + sign * 36, 136, 100 + sign * 11, 137)
          ..close(),
        lightGold,
      );
      for (var i = 0; i < 4; i++)
        line(
          c,
          Offset(100 + sign * (18 + i * 9), 105 - i * 7),
          Offset(100 + sign * (22 + i * 10), 124 - i * 12),
          gold,
          1.7,
        );
    }
    gem(c, const Offset(100, 110), 24, const Color(0xFF9C86AD));
    line(c, const Offset(100, 137), const Offset(100, 155), gold, 2);
    gem(c, const Offset(100, 157), 8, const Color(0xFF9C86AD));
    star(c, const Offset(53, 138), 5, gold);
    star(c, const Offset(142, 47), 7, gold);
  }

  void bottle(Canvas c, {bool ether = false}) {
    final glass = ether ? const Color(0xFF8BB9BE) : const Color(0xFFD9AAA0);
    final p = Path()
      ..moveTo(86, 52)
      ..lineTo(114, 52)
      ..lineTo(114, 74)
      ..cubicTo(116, 83, ether ? 137 : 146, 96, ether ? 132 : 145, 132)
      ..quadraticBezierTo(143, 166, 100, 166)
      ..quadraticBezierTo(57, 166, ether ? 68 : 55, 132)
      ..cubicTo(ether ? 64 : 54, 97, 84, 83, 86, 74)
      ..close();
    shape(c, p, Color.lerp(glass, ivory, .5)!);
    c.save();
    c.clipPath(p);
    c.drawPath(
      Path()
        ..moveTo(52, 113)
        ..quadraticBezierTo(75, 104, 100, 115)
        ..quadraticBezierTo(127, 124, 150, 109)
        ..lineTo(150, 174)
        ..lineTo(50, 174)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            glass,
            ether ? const Color(0xFF54878D) : const Color(0xFFAF6258),
          ],
        ).createShader(const Rect.fromLTWH(55, 108, 90, 65)),
    );
    for (final o in [
      const Offset(79, 129),
      const Offset(118, 144),
      const Offset(109, 126),
    ])
      c.drawCircle(o, 3, Paint()..color = ivory.withValues(alpha: .45));
    c.restore();
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(82, 47, 36, 13),
        const Radius.circular(4),
      ),
      Paint()..color = gold,
    );
    shape(
      c,
      Path()
        ..moveTo(87, 35)
        ..lineTo(113, 35)
        ..lineTo(110, 47)
        ..lineTo(90, 47)
        ..close(),
      const Color(0xFF94704B),
    );
    line(c, const Offset(91, 37), const Offset(90, 44), lightGold, 1.2);
    line(c, const Offset(72, 102), const Offset(67, 126), ivory, 4);
    shape(
      c,
      Path()
        ..moveTo(84, 113)
        ..lineTo(117, 113)
        ..lineTo(119, 143)
        ..lineTo(82, 143)
        ..close(),
      ivory,
      stroke: .8,
    );
    if (ether)
      star(c, const Offset(100, 128), 10, teal, 4);
    else {
      line(
        c,
        const Offset(100, 120),
        const Offset(100, 136),
        AtelierPalette.clay,
        4,
      );
      line(
        c,
        const Offset(92, 128),
        const Offset(108, 128),
        AtelierPalette.clay,
        4,
      );
    }
    line(c, const Offset(112, 68), const Offset(132, 84), gold, 1.2);
    shape(
      c,
      Path()
        ..moveTo(130, 79)
        ..lineTo(143, 91)
        ..lineTo(135, 104)
        ..lineTo(123, 91)
        ..close(),
      lightGold,
      stroke: .8,
    );
  }

  void training(Canvas c, int type) {
    if (type == 0) {
      c.save();
      c.translate(100, 103);
      c.rotate(-.32);
      c.translate(-100, -103);
      line(c, const Offset(61, 103), const Offset(139, 103), gold, 13);
      for (final x in [54.0, 132.0]) {
        shape(
          c,
          Path()
            ..moveTo(x, 76)
            ..lineTo(x + 15, 76)
            ..lineTo(x + 15, 130)
            ..lineTo(x, 130)
            ..close(),
          teal,
        );
        line(
          c,
          Offset(x + 3, 81),
          Offset(x + 3, 125),
          const Color(0xFF8CA496),
          2,
        );
      }
      for (final x in [45.0, 147.0])
        line(c, Offset(x, 89), Offset(x, 117), dark, 8);
      c.restore();
      for (var i = 0; i < 3; i++)
        line(
          c,
          Offset(89 + i * 12, 62 - i * 3),
          Offset(92 + i * 12, 51 - i * 3),
          gold,
          2,
        );
    } else if (type == 1) {
      shape(
        c,
        Path()
          ..moveTo(49, 66)
          ..quadraticBezierTo(72, 56, 100, 72)
          ..quadraticBezierTo(128, 56, 151, 66)
          ..lineTo(151, 146)
          ..quadraticBezierTo(126, 138, 100, 152)
          ..quadraticBezierTo(72, 138, 49, 146)
          ..close(),
        const Color(0xFF63796B),
      );
      shape(
        c,
        Path()
          ..moveTo(54, 61)
          ..quadraticBezierTo(78, 54, 100, 70)
          ..quadraticBezierTo(122, 54, 146, 61)
          ..lineTo(146, 138)
          ..quadraticBezierTo(122, 131, 100, 147)
          ..quadraticBezierTo(78, 131, 54, 138)
          ..close(),
        ivory,
      );
      line(c, const Offset(100, 73), const Offset(100, 142), gold, 1);
      for (var y = 84.0; y < 130; y += 10) {
        line(c, Offset(63, y), Offset(90, y + 2), const Color(0xFFB9AE90), 1.5);
        line(
          c,
          Offset(111, y + 2),
          Offset(137, y),
          const Color(0xFFB9AE90),
          1.5,
        );
      }
      shape(
        c,
        Path()
          ..moveTo(119, 65)
          ..quadraticBezierTo(135, 36, 151, 39)
          ..quadraticBezierTo(156, 59, 124, 80)
          ..close(),
        gold,
      );
      line(c, const Offset(117, 90), const Offset(147, 45), dark, 1.3);
    } else if (type == 2) {
      line(
        c,
        const Offset(105, 139),
        const Offset(136, 167),
        const Color(0xFF8B6449),
        6,
      );
      shape(
        c,
        Path()
          ..moveTo(60, 48)
          ..quadraticBezierTo(96, 32, 140, 52)
          ..lineTo(135, 100)
          ..quadraticBezierTo(131, 129, 102, 150)
          ..quadraticBezierTo(74, 140, 66, 106)
          ..close(),
        const Color(0xFFD4A16B),
      );
      shape(
        c,
        Path()
          ..moveTo(75, 76)
          ..quadraticBezierTo(85, 68, 96, 78)
          ..quadraticBezierTo(84, 92, 75, 76)
          ..close(),
        dark,
        stroke: .5,
      );
      shape(
        c,
        Path()
          ..moveTo(110, 78)
          ..quadraticBezierTo(122, 69, 132, 77)
          ..quadraticBezierTo(123, 90, 110, 78)
          ..close(),
        dark,
        stroke: .5,
      );
      c.drawPath(
        Path()
          ..moveTo(85, 113)
          ..quadraticBezierTo(105, 134, 125, 108),
        Paint()
          ..color = dark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      for (final p in [const Offset(61, 48), const Offset(143, 52)])
        star(c, p, 8, lightGold);
    } else {
      shape(
        c,
        Path()
          ..moveTo(46, 132)
          ..lineTo(68, 115)
          ..lineTo(99, 123)
          ..lineTo(124, 114)
          ..quadraticBezierTo(133, 112, 132, 122)
          ..lineTo(108, 138)
          ..lineTo(86, 147)
          ..lineTo(61, 150)
          ..close(),
        const Color(0xFFC8936A),
      );
      line(
        c,
        const Offset(100, 123),
        const Offset(113, 129),
        const Color(0xFF9C6B4B),
        1.5,
      );
      line(c, const Offset(104, 117), const Offset(105, 64), teal, 4);
      shape(
        c,
        Path()
          ..moveTo(104, 84)
          ..quadraticBezierTo(74, 82, 72, 55)
          ..quadraticBezierTo(99, 55, 104, 84)
          ..close(),
        const Color(0xFF6B9470),
      );
      shape(
        c,
        Path()
          ..moveTo(106, 99)
          ..quadraticBezierTo(137, 90, 139, 62)
          ..quadraticBezierTo(108, 64, 106, 99)
          ..close(),
        teal,
      );
      line(c, const Offset(107, 97), const Offset(130, 74), lightGold, 1);
      star(c, const Offset(77, 93), 6, gold);
      star(c, const Offset(129, 43), 5, gold);
    }
  }

  @override
  bool shouldRepaint(covariant _ItemPainter oldDelegate) =>
      oldDelegate.id != id || oldDelegate.framed != framed;
}

/// A little shopfront, drawn as a keepsake illustration rather than a logo.
class AtelierFrontage extends StatelessWidget {
  const AtelierFrontage({super.key});
  @override
  Widget build(BuildContext context) =>
      const ExcludeSemantics(child: CustomPaint(painter: _FrontagePainter()));
}

class _FrontagePainter extends CustomPainter {
  const _FrontagePainter();
  @override
  void paint(Canvas c, Size size) {
    final s = math.min(size.width / 280, size.height / 200);
    c.save();
    c.translate((size.width - 280 * s) / 2, (size.height - 200 * s) / 2);
    c.scale(s);
    const gold = Color(0xFFC8AA6C),
        paper = Color(0xFFDECAA1),
        wood = Color(0xFF91694A);
    final p = Paint();
    void rect(Rect r, Color color) {
      c.drawRect(r, p..color = color);
    }

    void line(Offset a, Offset b, Color color, double width) {
      c.drawLine(
        a,
        b,
        p
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    c.drawOval(
      const Rect.fromLTWH(24, 177, 241, 13),
      p..color = const Color(0xFF102B24),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(56, 51, 168, 130),
        const Radius.circular(3),
      ),
      p..color = paper,
    );
    final roof = Path()
      ..moveTo(43, 60)
      ..lineTo(137, 9)
      ..lineTo(236, 60)
      ..close();
    c.drawPath(roof, p..color = wood);
    for (var y = 32.0; y < 59; y += 10)
      line(
        Offset(112 - (y - 32) * 1.8, y),
        Offset(165 + (y - 32) * 1.8, y),
        gold.withValues(alpha: .5),
        1,
      );
    rect(const Rect.fromLTWH(62, 66, 156, 11), gold);
    rect(const Rect.fromLTWH(68, 98, 61, 71), wood);
    rect(const Rect.fromLTWH(75, 105, 47, 57), const Color(0xFF25493B));
    line(const Offset(98, 106), const Offset(98, 162), gold, 2);
    line(const Offset(76, 132), const Offset(120, 132), gold, 2);
    final door = Path()
      ..moveTo(150, 175)
      ..lineTo(150, 113)
      ..quadraticBezierTo(150, 86, 176, 86)
      ..quadraticBezierTo(202, 86, 202, 113)
      ..lineTo(202, 175)
      ..close();
    c.drawPath(door, p..color = wood);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(156, 118, 40, 53),
        const Radius.circular(2),
      ),
      p..color = const Color(0xFF315847),
    );
    c.drawCircle(const Offset(188, 145), 2.5, p..color = gold);
    for (var i = 0; i < 7; i++) {
      final x = 55 + i * 24.0;
      final awning = Path()
        ..moveTo(x, 76)
        ..lineTo(x + 24, 76)
        ..lineTo(x + 29, 99)
        ..quadraticBezierTo(x + 12, 110, x - 5, 99)
        ..close();
      c.drawPath(
        awning,
        p..color = i.isEven ? const Color(0xFF9B5140) : const Color(0xFFE6CF9E),
      );
    }
    rect(const Rect.fromLTWH(145, 177, 63, 5), gold);
    for (final x in [39.0, 227.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 151, 24, 29),
          const Radius.circular(6),
        ),
        p..color = const Color(0xFFB67550),
      );
      for (var i = 0; i < 5; i++) {
        final a = i * .7 - 1.4;
        line(
          Offset(x + 12, 154),
          Offset(x + 12 + math.sin(a) * 17, 124 + math.cos(a) * 7),
          const Color(0xFF7E9870),
          5,
        );
      }
    }
    line(const Offset(214, 54), const Offset(255, 54), gold, 3);
    line(const Offset(250, 54), const Offset(250, 67), gold, 2);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(235, 67, 29, 31),
        const Radius.circular(5),
      ),
      p..color = wood,
    );
    line(const Offset(245, 75), const Offset(255, 88), paper, 2);
    line(const Offset(254, 74), const Offset(244, 87), paper, 2);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _FrontagePainter oldDelegate) => false;
}
