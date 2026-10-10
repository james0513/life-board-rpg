import 'package:flutter/material.dart';

class DiceDisplay extends StatelessWidget {
  const DiceDisplay({super.key, required this.value, required this.rolling});
  final int? value;
  final bool rolling;
  @override
  Widget build(BuildContext context) => Semantics(
    label: rolling ? '擲骰中' : '骰子點數 ${value ?? "未擲骰"}',
    child: AnimatedRotation(turns: rolling ? (value ?? 1) / 12 : 0,
      duration: const Duration(milliseconds: 80),
      child: AnimatedContainer(duration: const Duration(milliseconds: 90),
        width: 46, height: 46, padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: rolling ? const Color(0xFFF5D586) : Colors.white,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBDA77B))),
        child: value == null ? const Icon(Icons.casino_outlined)
          : CustomPaint(painter: _Pips(value!)),
      )));
}
class _Pips extends CustomPainter {
  _Pips(this.value);
  final int value;
  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[];
    if (value.isOdd) points.add(const Offset(.5, .5));
    if (value >= 2) points.addAll([const Offset(.17,.17), const Offset(.83,.83)]);
    if (value >= 4) points.addAll([const Offset(.83,.17), const Offset(.17,.83)]);
    if (value == 6) points.addAll([const Offset(.17,.5), const Offset(.83,.5)]);
    for (final p in points) canvas.drawCircle(Offset(p.dx*size.width,p.dy*size.height),
      size.width * .085, Paint()..color = const Color(0xFF2B584E));
  }
  @override
  bool shouldRepaint(covariant _Pips oldDelegate) => value != oldDelegate.value;
}
