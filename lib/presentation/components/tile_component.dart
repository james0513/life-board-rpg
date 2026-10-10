import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../../domain/models/board_tile.dart';

class TileComponent extends PositionComponent {
  final BoardTile tile;
  TileComponent({required this.tile, required Vector2 center})
      : super(position: center, size: Vector2(132, 78), anchor: Anchor.center,
          priority: center.y.round());
  static const colors = [Color(0xFF8ED29A), Color(0xFFEB8C88),
    Color(0xFFF0CF70), Color(0xFF83B7E8), Color(0xFFC2A0E0), Color(0xFFFFB66C)];
  static const labels = ['幸運', '懲罰', '打工', '戰鬥', '命運', '商店街'];
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final top = Path()..moveTo(66, 3)..lineTo(130, 35)..lineTo(66, 67)..lineTo(2, 35)..close();
    final base = Path()..moveTo(2,35)..lineTo(66,67)..lineTo(130,35)
      ..lineTo(130,44)..lineTo(66,76)..lineTo(2,44)..close();
    canvas.drawShadow(top, const Color(0xCC29231F), 5, false);
    canvas.drawPath(base, Paint()..color = const Color(0xFF8B806E));
    canvas.drawPath(top, Paint()..shader = ui.Gradient.linear(const Offset(0,0), const Offset(0,70), [const Color(0xFFFFFCF3), colors[tile.kind.index]]));
    canvas.drawPath(top, Paint()..color = const Color(0xFF726651)
      ..style = PaintingStyle.stroke..strokeWidth = 2.2);
    if (tile.kind == TileKind.shop) {
      // Small storefront on the tile, independent of font emoji support.
      canvas.drawRect(const Rect.fromLTWH(49, 20, 34, 19), Paint()..color = const Color(0xFFFFF4DB));
      canvas.drawRect(const Rect.fromLTWH(46, 16, 40, 8), Paint()..color = const Color(0xFFB85C38));
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(Rect.fromLTWH(46 + i * 10.0, 16, 5, 8), Paint()..color = const Color(0xFFFFE4B0));
      }
      canvas.drawRect(const Rect.fromLTWH(62, 27, 9, 12), Paint()..color = const Color(0xFF695044));
    }
    final text = TextPainter(text: TextSpan(text: '${tile.index + 1} · ${labels[tile.kind.index]}',
      style: const TextStyle(color: Color(0xFF302D2A), fontSize: 15,
        fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
    text.paint(canvas, Offset((132 - text.width) / 2, 41));
  }
}
