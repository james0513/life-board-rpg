import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The whole adventure shares one printed-folio palette and tactile controls.
class GameDesign {
  static const ink = Color(0xFF223F39);
  static const forest = Color(0xFF315E51);
  static const paper = Color(0xFFF5EFDF);
  static const ivory = Color(0xFFFFFBF0);
  static const gold = Color(0xFFB98B45);
  static const line = Color(0xFFD5C6A6);
  static const muted = Color(0xFF736D5C);
  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(seedColor: forest,
      brightness: Brightness.light, surface: ivory, primary: forest,
      secondary: const Color(0xFF9B6548));
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: paper,
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(backgroundColor: ivory,
        foregroundColor: ink, surfaceTintColor: Colors.transparent,
        centerTitle: false, elevation: 0, scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w700,
          letterSpacing: .8, color: ink)),
      cardTheme: CardThemeData(color: ivory, surfaceTintColor: Colors.transparent,
        elevation: 0, margin: const EdgeInsets.symmetric(vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line))),
      dividerTheme: const DividerThemeData(color: line, space: 24, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
          letterSpacing: .4))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: forest, side: const BorderSide(color: line),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      chipTheme: base.chipTheme.copyWith(backgroundColor: ivory,
        selectedColor: const Color(0xFFDCE7D6), side: const BorderSide(color: line),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600)),
      dialogTheme: DialogThemeData(backgroundColor: ivory,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: line))),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: ivory,
        surfaceTintColor: Colors.transparent, showDragHandle: true),
      snackBarTheme: SnackBarThemeData(backgroundColor: ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: forest,
        linearTrackColor: Color(0xFFE5DDC9), borderRadius: BorderRadius.all(Radius.circular(8))),
      tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 450)),
    );
  }
}

/// Quiet compass engraving; no animated noise behind text or interaction.
class FolioEngraving extends CustomPainter {
  const FolioEngraving({this.color = GameDesign.gold});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .48);
    final r = math.min(size.width, size.height) * .4;
    final pen = Paint()..color = color.withValues(alpha: .2)
      ..style = PaintingStyle.stroke..strokeWidth = 1;
    for (final scale in [1.0, .93, .62]) canvas.drawCircle(center, r * scale, pen);
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      final long = i % 3 == 0;
      canvas.drawLine(center + Offset(math.cos(a), math.sin(a)) * r * (long ? .84 : .9),
        center + Offset(math.cos(a), math.sin(a)) * r, pen);
    }
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      final side = Offset(-dir.dy, dir.dx);
      final path = Path()..moveTo((center + dir*r*.58).dx, (center + dir*r*.58).dy)
        ..lineTo((center + side*r*.07).dx, (center + side*r*.07).dy)
        ..lineTo((center - side*r*.07).dx, (center - side*r*.07).dy)..close();
      canvas.drawPath(path, pen);
    }
    canvas.drawCircle(center, r*.08, pen);
  }
  @override bool shouldRepaint(covariant FolioEngraving oldDelegate) => oldDelegate.color != color;
}
