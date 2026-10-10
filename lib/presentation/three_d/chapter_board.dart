import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/board_tile.dart';
import '../components/tile_component.dart';
import 'scene_3d.dart';

class ChapterPalette {
  final Color stone, edge, metal, roof, glow;
  const ChapterPalette(this.stone, this.edge, this.metal, this.roof, this.glow);
  static const all = [
    ChapterPalette(
      Color(0xFFD4D8BC),
      Color(0xFF4C685B),
      Color(0xFFCDA765),
      Color(0xFF547F6E),
      Color(0xFFE9B7B8),
    ),
    ChapterPalette(
      Color(0xFFE2C9A6),
      Color(0xFF795541),
      Color(0xFFD6AD68),
      Color(0xFFAE6A4C),
      Color(0xFFFFDCA3),
    ),
    ChapterPalette(
      Color(0xFFB2C3BB),
      Color(0xFF3D6164),
      Color(0xFFC99761),
      Color(0xFF537F7D),
      Color(0xFFB5DDCD),
    ),
    ChapterPalette(
      Color(0xFFD2B9BE),
      Color(0xFF644B5D),
      Color(0xFFCFA568),
      Color(0xFF8F5873),
      Color(0xFFF0C6D0),
    ),
    ChapterPalette(
      Color(0xFFD3AF91),
      Color(0xFF765648),
      Color(0xFFD1A365),
      Color(0xFFA9614B),
      Color(0xFFFFCF93),
    ),
    ChapterPalette(
      Color(0xFFC8C5D9),
      Color(0xFF5A557B),
      Color(0xFFD8BC83),
      Color(0xFF8880A6),
      Color(0xFFD6E5F0),
    ),
  ];
  static ChapterPalette forStage(int stage) =>
      all[stage.clamp(1, 6).toInt() - 1];
}

/// Cached mesh construction only. Board rules/centers never change here.
class ChapterBoard {
  static void _shell(Scene3D s, V3 center, V3 size, Color color) {
    s.box(center, size, color);
    // Camera remains above the board: only sides are needed below the tiled deck.
    s.faces.removeLast();
    s.faces.removeLast();
  }

  static void floor(Scene3D s, int stage) {
    final p = ChapterPalette.forStage(stage);
    _shell(s, const V3(0, -.48, 0), const V3(7.05, .24, 7.05), p.edge);
    _shell(s, const V3(0, -.34, 0), const V3(7.12, .055, 7.12), p.metal);
    _shell(s, const V3(0, -.24, 0), const V3(7, .16, 7), p.edge);
    // Small individual faces remove the single huge top-face depth artifact.
    for (var x = 0; x < 14; x++)
      for (var z = 0; z < 14; z++) {
        final a = -3.5 + x * .5, b = -3.5 + z * .5;
        final tint = ((x * 13 + z * 7) % 5) * .018;
        final c = Color.lerp(p.stone, Colors.white, tint)!;
        s.face([
          V3(a + .012, -.15, b + .012),
          V3(a + .488, -.15, b + .012),
          V3(a + .488, -.15, b + .488),
          V3(a + .012, -.15, b + .488),
        ], c);
      }
    for (final sign in [-1.0, 1.0]) {
      s.box(V3(sign * 3.46, -.1, 0), const V3(.035, .065, 6.88), p.metal);
      s.box(V3(0, -.1, sign * 3.46), const V3(6.88, .065, .035), p.metal);
    }
    // Inlaid corner diamonds and brass rivets belong to the frame, never the path.
    for (final x in [-3.28, 3.28])
      for (final z in [-3.28, 3.28]) {
        s.face([
          V3(x - .12, -.095, z),
          V3(x, -.095, z - .12),
          V3(x + .12, -.095, z),
          V3(x, -.095, z + .12),
        ], p.metal);
      }
    for (final sign in [-1.0, 1.0])
      for (var i = 0; i < 7; i++) {
        final a = -2.7 + i * .9;
        s.box(V3(a, -.23, sign * 3.51), const V3(.05, .035, .025), p.metal);
        s.box(V3(sign * 3.51, -.23, a), const V3(.025, .035, .05), p.metal);
      }
  }

  static void tile(Scene3D s, V3 center, TileKind kind, int stage) {
    final p = ChapterPalette.forStage(stage),
        base = TileComponent.colors[kind.index];
    s.box(center + const V3(0, -.06, 0), const V3(.95, .19, .95), p.edge);
    s.box(center + const V3(0, .039, 0), const V3(.91, .025, .91), p.metal);
    const edge = .435, cut = .075;
    final ring = [
      const V3(-edge + cut, .105, -edge),
      const V3(edge - cut, .105, -edge),
      const V3(edge, .105, -edge + cut),
      const V3(edge, .105, edge - cut),
      const V3(edge - cut, .105, edge),
      const V3(-edge + cut, .105, edge),
      const V3(-edge, .105, edge - cut),
      const V3(-edge, .105, -edge + cut),
    ];
    final top = ring.map((v) => center + v).toList();
    s.face(top, p.metal);
    final inset = ring
        .map((v) => center + V3(v.x * .925, .108, v.z * .925))
        .toList();
    s.face(inset, Color.lerp(base, p.stone, .15)!);
    for (var i = 0; i < 8; i++) {
      final a = top[i], b = top[(i + 1) % 8];
      s.face([a, b, b + const V3(0, -.05, 0), a + const V3(0, -.05, 0)], base);
    }
    // Enamel inlay, rather than an unframed flat colour square.
    for (final sign in [-1.0, 1.0])
      s.box(
        center + V3(sign * .36, .11, 0),
        const V3(.012, .006, .58),
        Color.lerp(base, Colors.white, .52)!,
      );
    if (kind != TileKind.shop)
      _tileStamp(
        s,
        center + const V3(0, .118, -.075),
        kind,
        Color.lerp(base, p.edge, .57)!,
      );
  }

  /// Small embossed symbols remain below the pawn and separate from its label.
  static void _tileStamp(Scene3D s, V3 c, TileKind kind, Color ink) {
    void polygon(List<List<double>> points) {
      s.face([for (final p in points) c + V3(p[0], 0, p[1])], ink);
    }

    switch (kind) {
      case TileKind.luck:
        for (final sign in [-1.0, 1.0]) {
          polygon([
            [0, 0],
            [sign * .07, -.15],
            [sign * .17, -.09],
            [sign * .1, .015],
          ]);
          polygon([
            [0, 0],
            [sign * .07, .15],
            [sign * .17, .09],
            [sign * .1, -.015],
          ]);
        }
        break;
      case TileKind.penalty:
        polygon([
          [-.035, -.19],
          [.13, -.19],
          [.045, -.04],
          [.13, -.04],
          [-.085, .19],
          [-.03, .03],
          [-.13, .03],
        ]);
        break;
      case TileKind.work:
        polygon([
          [-.17, -.1],
          [.17, -.1],
          [.17, .13],
          [-.17, .13],
        ]);
        s.box(c + const V3(0, .005, -.125), const V3(.13, .006, .045), ink);
        s.box(
          c + const V3(0, .008, .015),
          const V3(.31, .006, .018),
          const Color(0xFFEEDCA9),
        );
        break;
      case TileKind.battle:
        polygon([
          [-.17, -.18],
          [-.09, -.15],
          [.17, .14],
          [.125, .18],
          [-.15, -.095],
        ]);
        polygon([
          [.17, -.18],
          [.09, -.15],
          [-.17, .14],
          [-.125, .18],
          [.15, -.095],
        ]);
        break;
      case TileKind.career:
        polygon([
          [0, -.2],
          [.045, -.05],
          [.18, 0],
          [.045, .05],
          [0, .2],
          [-.045, .05],
          [-.18, 0],
          [-.045, -.05],
        ]);
        break;
      case TileKind.shop:
        break;
    }
  }

  static void shop(Scene3D s, V3 pos, int stage) {
    final p = ChapterPalette.forStage(stage);
    s.box(pos + const V3(0, .3, -.19), const V3(.47, .42, .33), p.stone);
    s.box(pos + const V3(0, .52, -.19), const V3(.56, .055, .4), p.metal);
    for (var i = 0; i < 5; i++)
      s.box(
        pos + V3(-.22 + i * .11, .43, .025),
        const V3(.105, .04, .2),
        i.isEven ? p.roof : const Color(0xFFFFEAC3),
      );
    s.box(pos + const V3(0, .28, .025), const V3(.33, .16, .025), p.edge);
    s.orb(
      pos + const V3(.18, .47, .12),
      const V3(.035, .05, .03),
      p.glow,
      slices: 6,
      rings: 3,
    );
    s.box(pos + const V3(-.25, .22, .035), const V3(.025, .35, .025), p.metal);
    s.box(pos + const V3(.25, .22, .035), const V3(.025, .35, .025), p.metal);
    s.box(pos + const V3(0, .16, .055), const V3(.35, .018, .05), p.metal);
  }

  static void _tree(Scene3D s, double x, double z, Color leaves) {
    s.box(V3(x, .17, z), const V3(.1, .6, .1), const Color(0xFF866B52));
    s.orb(V3(x, .56, z), const V3(.27, .32, .25), leaves, slices: 7, rings: 4);
    s.orb(
      V3(x - .16, .43, z + .06),
      const V3(.21, .24, .22),
      Color.lerp(leaves, Colors.white, .13)!,
      slices: 6,
      rings: 3,
    );
  }

  static void _lamp(Scene3D s, double x, double z, ChapterPalette p) {
    s.box(V3(x, .25, z), const V3(.035, .75, .035), p.metal);
    s.box(V3(x, .65, z), const V3(.14, .19, .14), p.glow);
    s.pyramid(V3(x, .75, z), .13, .09, p.edge);
  }

  static void _windows(
    Scene3D s,
    double x,
    double y,
    double z,
    int n,
    ChapterPalette p,
  ) {
    for (var i = 0; i < n; i++) {
      s.box(V3(x + i * .28, y, z), const V3(.14, .24, .028), p.edge);
      s.box(V3(x + i * .28, y, z + .018), const V3(.09, .17, .01), p.glow);
    }
  }

  static void scenery(Scene3D s, int stage) {
    final p = ChapterPalette.forStage(stage);
    // Central precinct stays inside the 20-cell path.

    for (final x in [-3.22, 3.22])
      for (final z in [-3.22, 3.22]) {
        s.box(V3(x, -.03, z), const V3(.25, .22, .25), p.edge);
        s.orb(
          V3(x, .14, z),
          const V3(.1, .13, .1),
          p.metal,
          slices: 6,
          rings: 3,
        );
      }
    switch (stage) {
      case 1:
        s.box(
          const V3(0, .38, -.55),
          const V3(2, .82, .7),
          const Color(0xFFE3DBBF),
        );
        s.pyramid(const V3(0, .8, -.55), 1.17, .4, p.roof);
        _windows(s, -.7, .46, -.18, 6, p);
        s.box(const V3(0, .7, -.55), const V3(.45, 1.5, .48), p.stone);
        s.pyramid(const V3(0, 1.45, -.55), .4, .4, p.roof);
        s.orb(
          const V3(0, 1.17, -.292),
          const V3(.14, .14, .03),
          p.metal,
          slices: 12,
          rings: 2,
        );
        for (final x in [-1.3, 1.3]) _tree(s, x, .65, p.glow);
        s.orb(
          const V3(0, .02, .94),
          const V3(.51, .08, .44),
          p.metal,
          slices: 12,
          rings: 3,
        );
        s.orb(
          const V3(0, .07, .94),
          const V3(.42, .04, .35),
          const Color(0xFF8DC8C3),
          slices: 12,
          rings: 2,
        );
        s.orb(
          const V3(0, .2, .94),
          const V3(.075, .2, .075),
          p.stone,
          slices: 6,
          rings: 3,
        );
        break;
      case 2:
        for (var i = 0; i < 3; i++) {
          final x = -1.08 + i * 1.08;
          s.box(
            V3(x, .42, -.55),
            const V3(.82, .9, .84),
            Color.lerp(p.stone, Colors.white, i * .1)!,
          );
          s.pyramid(V3(x, .88, -.55), .63, .4, p.roof);
          _windows(s, x - .23, .57, -.11, 2, p);
          for (var k = 0; k < 5; k++)
            s.box(
              V3(x - .36 + k * .18, .4, .04),
              const V3(.17, .07, .42),
              k.isEven ? p.roof : const Color(0xFFFFE9BB),
            );
          s.box(V3(x, .17, .19), const V3(.7, .22, .15), p.edge);
        }
        for (final x in [-1.35, 1.35]) _lamp(s, x, 1.1, p);
        s.box(const V3(0, .15, .95), const V3(.7, .38, .65), p.metal);
        s.orb(
          const V3(0, .52, .95),
          const V3(.2, .24, .2),
          p.glow,
          slices: 10,
          rings: 4,
        );
        break;
      case 3:
        for (final x in [-1.12, 1.12]) {
          s.box(V3(x, .51, -.55), const V3(.54, 1.12, .6), p.edge);
          for (final y in [.2, .48, .76, 1.04])
            s.box(V3(x, y, -.23), const V3(.4, .05, .02), p.glow);
          s.pyramid(V3(x, 1.08, -.55), .43, .33, p.metal);
        }
        s.box(const V3(0, .29, 0), const V3(1.16, .7, 1.16), p.stone);
        s.orb(
          const V3(0, .63, 0),
          const V3(.58, .46, .58),
          p.metal,
          slices: 12,
          rings: 5,
        );
        s.box(const V3(0, .73, .4), const V3(.08, .5, .64), p.edge);
        for (final x in [-.65, .65])
          s.box(V3(x, -.01, .8), const V3(.035, .025, 1.15), p.glow);
        s.box(const V3(0, -.01, 1.3), const V3(1.34, .025, .035), p.glow);
        break;
      case 4:
        for (var i = 0; i < 3; i++)
          s.box(
            V3(0, i * .1, .45 - i * .25),
            V3(2.5 - i * .12, .12, 1.9 - i * .22),
            i.isEven ? p.roof : p.metal,
          );
        for (final x in [-1.25, 1.25]) {
          s.box(V3(x, .65, -.5), const V3(.22, 1.45, .3), p.metal);
          s.box(V3(x * .79, .67, -.56), const V3(.27, 1.3, .12), p.roof);
        }
        s.box(const V3(0, 1.37, -.5), const V3(2.75, .22, .32), p.metal);
        s.orb(
          const V3(0, 1.41, -.3),
          const V3(.27, .27, .05),
          p.roof,
          slices: 8,
          rings: 3,
        );
        for (final x in [-1.2, 1.2])
          for (final z in [.85, 1.3])
            s.box(V3(x, .07, z), const V3(.32, .22, .27), p.roof);
        break;
      case 5:
        s.box(const V3(0, .4, -.45), const V3(2.4, .92, .55), p.stone);
        for (final x in [-1.12, 1.12]) {
          s.box(V3(x, .65, -.45), const V3(.6, 1.45, .67), p.edge);
          for (final dx in [-.21, .21])
            for (final z in [-.68, -.22])
              s.box(V3(x + dx, 1.43, z), const V3(.18, .23, .2), p.stone);
          s.box(V3(x, .83, -.085), const V3(.23, .48, .035), p.roof);
        }
        s.box(const V3(0, .28, -.14), const V3(.62, .72, .06), p.edge);
        for (final x in [-.24, -.12, 0.0, .12, .24])
          s.box(V3(x, .28, -.095), const V3(.025, .65, .025), p.metal);
        for (final x in [-1.15, 1.15]) _lamp(s, x, 1.03, p);
        for (final z in [.35, .72, 1.09])
          s.box(V3(0, -.005, z), const V3(.65, .035, .3), p.roof);
        break;
      case 6:
        s.orb(
          const V3(0, .005, 0),
          const V3(1.45, .1, 1.45),
          p.metal,
          slices: 16,
          rings: 3,
        );
        s.orb(
          const V3(0, .07, 0),
          const V3(1.32, .04, 1.32),
          p.edge,
          slices: 16,
          rings: 2,
        );
        for (var i = 0; i < 3; i++)
          s.box(
            V3(0, .16 + i * .12, .35 - i * .2),
            V3(1 - i * .1, .15, .8 - i * .12),
            p.stone,
          );
        s.box(const V3(0, .8, -.4), const V3(.62, 1.14, .24), p.roof);
        s.box(const V3(0, .4, -.14), const V3(.62, .12, .5), p.metal);
        for (final x in [-.36, .36])
          s.box(V3(x, .57, -.1), const V3(.12, .42, .5), p.metal);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          s.orb(
            V3(math.cos(a) * 1.45, .46, math.sin(a) * 1.45),
            const V3(.12, .29, .12),
            i.isEven ? p.glow : p.roof,
            slices: 4,
            rings: 3,
          );
        }
        break;
    }
    _precinctDetails(s, stage, p);
  }

  static void _planter(Scene3D s, double x, double z, ChapterPalette p) {
    s.box(V3(x, -.015, z), const V3(.31, .17, .31), p.roof);
    s.box(V3(x, .06, z), const V3(.34, .035, .34), p.metal);
    s.orb(
      V3(x, .15, z),
      const V3(.2, .16, .2),
      const Color(0xFF799064),
      slices: 6,
      rings: 3,
    );
    s.orb(
      V3(x + .07, .27, z - .035),
      const V3(.055, .05, .055),
      p.glow,
      slices: 5,
      rings: 2,
    );
  }

  static void _precinctDetails(Scene3D s, int stage, ChapterPalette p) {
    const cream = Color(0xFFF2E5CC);
    // A quiet landscaped precinct fits entirely inside the existing 20-cell loop.
    for (final x in [-1.65, 1.65]) _planter(s, x, 1.22, p);
    for (final x in [-1.67, 1.67]) {
      s.box(V3(x, -.06, -.02), const V3(.045, .025, 1.42), p.metal);
    }
    switch (stage) {
      case 1:
        // Clock hands, limestone cornices and paired cloister pilasters.
        s.box(const V3(0, 1.19, -.252), const V3(.014, .12, .014), p.edge);
        s.box(const V3(.04, 1.17, -.25), const V3(.085, .014, .014), p.edge);
        for (final y in [.07, .77])
          s.box(V3(0, y, -.175), const V3(2.08, .055, .06), p.metal);
        for (final x in [-.93, -.48, .48, .93])
          s.box(V3(x, .41, -.16), const V3(.055, .64, .055), cream);
        for (final x in [-.65, .65]) {
          s.box(V3(x, -.04, .6), const V3(.28, .035, .17), cream);
          s.box(V3(x, -.04, 1.05), const V3(.28, .035, .17), cream);
        }
        break;
      case 2:
        for (var i = 0; i < 3; i++) {
          final x = -1.08 + i * 1.08;
          s.box(V3(x, .12, .19), const V3(.73, .035, .22), p.metal);
          s.box(V3(x, .84, -.1), const V3(.84, .035, .04), cream);
          for (final dx in [-.34, .34])
            s.box(V3(x + dx, .24, .17), const V3(.028, .3, .028), p.metal);
          for (var j = 0; j < 3; j++)
            s.orb(
              V3(x - .17 + j * .17, .315, .19),
              const V3(.065, .065, .055),
              j.isEven ? p.glow : p.roof,
              slices: 5,
              rings: 2,
            );
        }
        for (final x in [-.42, .42]) {
          s.box(V3(x, .02, 1.28), const V3(.24, .24, .25), p.roof);
          s.box(V3(x, .07, 1.41), const V3(.24, .02, .015), p.metal);
        }
        break;
      case 3:
        // Workshop copper piping and an illuminated radial instrument.
        for (final x in [-.84, .84]) {
          s.box(V3(x, .22, -.56), const V3(.07, .65, .07), p.metal);
          s.box(V3(x * .62, .52, -.56), const V3(.68, .07, .07), p.metal);
        }
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          s.orb(
            V3(math.cos(a) * .36, .64 + math.sin(a) * .33, .5),
            const V3(.035, .035, .018),
            cream,
            slices: 4,
            rings: 2,
          );
        }
        s.box(const V3(0, .7, .52), const V3(.035, .2, .02), p.edge);
        s.box(const V3(.07, .61, .52), const V3(.18, .035, .02), p.edge);
        break;
      case 4:
        // Velvet pleats, proscenium trim and warm footlights.
        for (final side in [-1.0, 1.0])
          for (var i = 0; i < 3; i++) {
            s.box(
              V3(side * (.87 + i * .075), .67, -.465),
              const V3(.034, 1.22, .025),
              Color.lerp(p.roof, p.edge, i * .13)!,
            );
          }
        s.box(const V3(0, 1.26, -.32), const V3(2.39, .045, .045), cream);
        for (var i = 0; i < 7; i++)
          s.orb(
            V3(-.96 + i * .32, .095, 1.27),
            const V3(.035, .05, .035),
            p.glow,
            slices: 5,
            rings: 2,
          );
        s.face([
          const V3(-.18, .62, -.28),
          const V3(.18, .62, -.28),
          const V3(.12, .39, -.28),
          const V3(0, .33, -.28),
          const V3(-.12, .39, -.28),
        ], p.metal);
        break;
      case 5:
        for (final x in [-1.12, 1.12]) {
          s.box(V3(x, .43, -.09), const V3(.64, .045, .035), p.metal);
          s.face([
            V3(x - .11, 1.03, -.058),
            V3(x + .11, 1.03, -.058),
            V3(x + .11, .8, -.058),
            V3(x, .73, -.058),
            V3(x - .11, .8, -.058),
          ], p.metal);
          s.box(V3(x, 1.64, -.45), const V3(.025, .45, .025), p.metal);
          s.face([
            V3(x, 1.85, -.45),
            V3(x + .32, 1.77, -.45),
            V3(x, 1.67, -.45),
          ], p.roof);
        }
        for (final x in [-.82, -.41, .41, .82])
          s.box(V3(x, .91, -.45), const V3(.17, .19, .6), p.stone);
        break;
      case 6:
        // Thin polygonal astrolabe bands make a crown behind the throne.
        for (var i = 0; i < 16; i++) {
          final a = i * math.pi / 8, b = (i + 1) * math.pi / 8;
          s.face([
            V3(math.cos(a) * .63, 1.02 + math.sin(a) * .63, -.56),
            V3(math.cos(b) * .63, 1.02 + math.sin(b) * .63, -.56),
            V3(math.cos(b) * .60, 1.02 + math.sin(b) * .60, -.56),
            V3(math.cos(a) * .60, 1.02 + math.sin(a) * .60, -.56),
          ], p.metal);
        }
        for (final x in [-.5, .5])
          s.pyramid(V3(x, .44, -.47), .11, .36, p.glow, sides: 5);
        s.orb(
          const V3(0, 1.72, -.56),
          const V3(.065, .065, .065),
          p.glow,
          slices: 6,
          rings: 3,
        );
        break;
    }
  }
}
