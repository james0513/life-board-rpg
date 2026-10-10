import 'dart:math' as math;

/// Pure geometry contract. Heights include readable text and 48px action targets;
/// arena gets the remaining space, never hidden behind a bottom navigation bar.
class BattleViewport {
  const BattleViewport._(
    this.canvasWidth,
    this.canvasHeight,
    this.handWidth,
    this.handHeight,
    this.statusHeight,
    this.messageHeight,
    this.sideBySide,
    this.needsScroll,
  );
  static const narrowHandWidth = 560.0;
  final double canvasWidth, canvasHeight, handWidth, handHeight;
  final double statusHeight, messageHeight;
  final bool sideBySide, needsScroll;
  double get arenaHeight =>
      canvasHeight -
      16 -
      statusHeight -
      8 -
      messageHeight -
      (sideBySide ? 0 : handHeight + 8);
  double get fieldWidth => canvasWidth - 16 - (sideBySide ? handWidth + 8 : 0);

  static BattleViewport plan(
    double width,
    double height, {
    double textScale = 1,
  }) {
    final scale = math.max(1.0, textScale);
    final canvasWidth = math.max(320.0, width);
    final side = canvasWidth >= 576 * scale + 344 && height < 620 * scale;
    final handWidth = side ? 576.0 * scale : canvasWidth - 16;
    final handHeight = (handWidth < narrowHandWidth ? 284.0 : 232.0) * scale;
    final statusHeight = 108.0 * scale;
    final messageHeight = 28.0 * scale;
    final minimumHeight = side
        ? math.max(handHeight + 16, statusHeight + messageHeight + 144)
        : statusHeight + messageHeight + handHeight + 152;
    final canvasHeight = math.max(minimumHeight, height);
    return BattleViewport._(
      canvasWidth,
      canvasHeight,
      handWidth,
      handHeight,
      statusHeight,
      messageHeight,
      side,
      width < canvasWidth || height < minimumHeight,
    );
  }
}
