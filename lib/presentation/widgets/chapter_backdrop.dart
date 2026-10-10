import 'package:flutter/material.dart';

import '../stages/stage_scenery.dart';

/// Chapter art is independent of progression and never changes board geometry.
String chapterBackgroundAsset(int stage) =>
    'assets/images/backgrounds/stage_${stage.clamp(1, 6).toString().padLeft(2, '0')}_v27.png';

class ChapterBackdrop extends StatelessWidget {
  final int stage;
  const ChapterBackdrop({super.key, required this.stage});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 650),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: SizedBox.expand(
            key: ValueKey(stage.clamp(1, 6)),
            child: Image.asset(
              chapterBackgroundAsset(stage),
              fit: BoxFit.cover,
              alignment: const Alignment(0, .12),
              cacheWidth: 1536,
              excludeFromSemantics: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => CustomPaint(
                painter: StageScenery(stage),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        // Quiet the distant detail without losing the illustrated chapter.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, .16),
              radius: .84,
              colors: [Color(0x0AFFF3D8), Color(0x00392F29), Color(0x44312827)],
              stops: [0, .56, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x10352E31), Color(0x00FFF4D9), Color(0x38332A29)],
              stops: [0, .53, 1],
            ),
          ),
        ),
      ],
    ),
  );
}
