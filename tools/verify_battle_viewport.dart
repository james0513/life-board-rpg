import '../lib/presentation/battle/battle_viewport.dart';

void verifyBattleViewport() {
  var checks = 0;
  void check(bool valid, String reason) {
    checks++;
    if (!valid) throw StateError('Battle viewport: $reason');
  }

  // Body heights exclude the 56px toolbar and a conservative 28px outer footer.
  for (final size in [
    (1917.0, 853.0),
    (1917.0, 471.0),
    (1280.0, 570.0),
    (1366.0, 768.0),
    (960.0, 720.0),
    (390.0, 844.0),
    (360.0, 740.0),
  ]) {
    final body = size.$2 - 84;
    final p = BattleViewport.plan(size.$1, body);
    check(!p.needsScroll, '$size unexpectedly scrolls');
    check(p.canvasHeight <= body, '$size body exceeds viewport');
    check(p.arenaHeight >= 120, '$size arena illegible');
    check(p.fieldWidth >= 300, '$size status columns too narrow');
  }
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final width in [280.0, 320.0, 390.0, 768.0, 1040.0, 1280.0, 1917.0]) {
      for (final height in [200.0, 320.0, 470.0, 640.0, 900.0]) {
        final p = BattleViewport.plan(width, height, textScale: scale);
        check(p.arenaHeight >= 120 - .001, 'arena lower bound');
        check(p.fieldWidth >= 300, 'field width lower bound');
        check(
          p.handHeight >=
              (p.handWidth < BattleViewport.narrowHandWidth ? 284 : 232) *
                  scale,
          'hand target/line budget',
        );
        check(
          p.needsScroll || (p.canvasWidth <= width && p.canvasHeight <= height),
          'unlabelled overflow',
        );
        check(
          !p.needsScroll || p.canvasWidth > width || p.canvasHeight > height,
          'unnecessary fallback',
        );
      }
    }
  }
  for (final size in [(1280.0, 570.0), (390.0, 844.0)]) {
    final p = BattleViewport.plan(size.$1, size.$2 - 84, textScale: 1.3);
    check(!p.needsScroll, '$size at 1.3x should fit');
    check(p.canvasWidth == size.$1, 'text scaling must not widen phone canvas');
  }
  final tiny = BattleViewport.plan(320, 300);
  check(tiny.needsScroll, 'tiny viewport must expose deliberate fallback');
  final wideShort = BattleViewport.plan(1917, 387);
  check(wideShort.sideBySide, 'short wide view must reflow sideways');
  final mobile = BattleViewport.plan(390, 760);
  check(!mobile.sideBySide, 'portrait view must retain card rail below arena');
  print(
    'PASS viewport: $checks pure geometry assertions; not Flutter render verification.',
  );
}

void main() => verifyBattleViewport();
