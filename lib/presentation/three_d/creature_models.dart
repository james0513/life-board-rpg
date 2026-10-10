import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scene_3d.dart';
import 'miniature_details.dart';

/// One distinct silhouette per encounter portrait. Boss indices are separate.
class CreatureModels {
  static const monsterCount = 18;
  static const colors = [
    Color(0xFF72A5AE),
    Color(0xFFC69C77),
    Color(0xFF9C89C8),
    Color(0xFFE5C9A1),
    Color(0xFF72CCD4),
    Color(0xFFD4AF5B),
    Color(0xFFE5DDD0),
    Color(0xFF7C91AF),
    Color(0xFF67739F),
    Color(0xFF5963A5),
    Color(0xFF8A6357),
    Color(0xFFC29157),
    Color(0xFF729C73),
    Color(0xFF8BA6B0),
    Color(0xFFBB8CCD),
    Color(0xFF9DD2E5),
    Color(0xFFD88266),
    Color(0xFF9A8DC4),
  ];
  static const gold = Color(0xFFD8B475),
      dark = Color(0xFF403B46),
      ivory = Color(0xFFF3E3C6);
  static void eyes(Scene3D s, double y, {double gap = .17, double z = .35}) {
    for (final x in [-gap, gap]) {
      s.orb(V3(x, y, z), const V3(.13, .14, .045), ivory, slices: 8, rings: 3);
      s.orb(
        V3(x, y, z + .035),
        const V3(.063, .083, .03),
        dark,
        slices: 6,
        rings: 3,
      );
      s.orb(
        V3(x - .02, y + .035, z + .06),
        const V3(.022, .026, .012),
        Colors.white,
        slices: 4,
        rings: 2,
      );
    }
  }

  static void wings(Scene3D s, Color c, {double y = 1, double reach = 1}) {
    for (final sign in [-1.0, 1.0]) {
      final root = V3(sign * .24, y, .005),
          tip = V3(sign * reach, y + .55, -.08);
      final lower = V3(sign * reach * .87, y - .19, -.035),
          fold = V3(sign * .55, y - .04, .026);
      s.face([
        root,
        tip,
        V3(sign * reach * .95, y + .1, -.06),
      ], MiniatureDetails.light(c, .18));
      s.face([root, V3(sign * reach * .95, y + .1, -.06), lower, fold], c);
      s.face([
        root,
        fold,
        V3(sign * .37, y - .21, .036),
      ], MiniatureDetails.shade(c, .17));
      MiniatureDetails.rod(s, root, tip, .026, MiniatureDetails.shade(c, .3));
      MiniatureDetails.rod(
        s,
        root,
        lower,
        .014,
        MiniatureDetails.light(c, .36),
        sides: 4,
      );
    }
  }

  static void crystal(Scene3D s, V3 p, Color c, {double scale = 1}) {
    s.orb(p, V3(.15, .28, .15) * scale, c, slices: 4, rings: 3);
  }

  static void monster(Scene3D s, int kind) {
    final c = colors[kind];
    switch (kind) {
      case 0: // clockwork
      case 7: // knight
      case 17: // sentinel
        MiniatureDetails.taper(
          s,
          const V3(0, .33, 0),
          .68,
          const V3(.29, 0, .23),
          const V3(.36, 0, .22),
          c,
        );
        s.orb(
          const V3(0, 1.24, 0),
          const V3(.34, .3, .3),
          c,
          slices: 8,
          rings: 4,
        );
        for (final x in [-.48, .48]) {
          s.box(V3(x, .73, 0), const V3(.2, .5, .26), gold);
          s.box(V3(x * .4, .15, .06), const V3(.23, .28, .36), dark);
        }
        eyes(s, 1.25, z: .28);
        if (kind == 0) {
          s.orb(
            const V3(0, .75, .25),
            const V3(.23, .23, .04),
            ivory,
            slices: 12,
            rings: 2,
          );
          s.box(const V3(.06, .78, .3), const V3(.17, .025, .015), dark);
        }
        if (kind == 7) {
          s.box(const V3(-.5, .73, .18), const V3(.4, .6, .12), c);
          s.pyramid(const V3(0, 1.5, 0), .12, .35, const Color(0xFFD87572));
        }
        if (kind == 17) {
          for (final x in [-.35, 0.0, .35])
            crystal(s, V3(x, 1.6, 0), const Color(0xFFB3F2EC));
          wings(s, c, y: .9, reach: .85);
        }
        break;
      case 1: // raccoon
      case 15: // fox
        s.orb(const V3(0, .58, 0), const V3(.4, .52, .32), c);
        s.orb(const V3(0, 1.23, 0), const V3(.42, .35, .33), c);
        for (final x in [-.27, .27]) s.pyramid(V3(x, 1.47, -.05), .19, .35, c);
        if (kind == 1)
          s.box(const V3(0, 1.27, .3), const V3(.7, .16, .06), dark);
        eyes(s, 1.27, z: .34);
        s.orb(const V3(0, 1.1, .34), const V3(.22, .13, .13), ivory);
        s.orb(
          const V3(0, 1.13, .47),
          const V3(.065, .05, .045),
          dark,
          slices: 6,
          rings: 3,
        );
        s.orb(
          const V3(.48, .6, -.25),
          const V3(.28, .5, .22),
          kind == 15 ? ivory : c,
        );
        if (kind == 15)
          for (final x in [-.36, .36])
            crystal(s, V3(x, .18, .1), ivory, scale: .65);
        break;
      case 2: // pillow dragon
      case 16: // ember drake
        s.orb(const V3(0, .58, 0), const V3(.52, .52, .37), c);
        s.orb(const V3(0, 1.13, .1), const V3(.4, .35, .32), c);
        s.orb(const V3(0, .99, .34), const V3(.3, .16, .19), ivory);
        eyes(s, 1.22, z: .39);
        wings(s, c, y: .82, reach: .9);
        for (final x in [-.24, .24]) s.pyramid(V3(x, 1.4, 0), .12, .25, gold);
        s.orb(const V3(.4, .24, -.36), const V3(.32, .17, .33), c);
        if (kind == 2)
          s.orb(
            const V3(0, .43, .32),
            const V3(.34, .2, .075),
            ivory,
            slices: 8,
            rings: 3,
          );
        if (kind == 16)
          crystal(s, const V3(.64, .3, -.4), const Color(0xFFFFCD77));
        break;
      case 3:
        s.box(const V3(0, .85, 0), const V3(.92, .65, .2), c);
        s.face([
          const V3(-.46, 1.17, .12),
          const V3(.46, 1.17, .12),
          const V3(0, .77, .14),
        ], ivory);
        eyes(s, .76, z: .16);
        s.orb(
          const V3(0, .96, .18),
          const V3(.09, .09, .03),
          const Color(0xFFC26E73),
        );
        break;
      case 4:
      case 9:
        s.orb(
          const V3(0, .63, 0),
          const V3(.55, .6, .43),
          c,
          slices: 10,
          rings: 6,
        );
        eyes(s, .76, z: .4);
        s.pyramid(const V3(0, 1.13, 0), .24, .35, c, sides: 6);
        if (kind == 4) {
          s.box(const V3(0, 1.3, 0), const V3(.65, .05, .56), dark);
          s.box(const V3(.34, 1.16, 0), const V3(.03, .24, .03), gold);
        } else
          for (final x in [-.3, .3])
            s.orb(V3(x, .1, .18), const V3(.24, .1, .22), c);
        break;
      case 5:
        s.orb(const V3(0, .62, 0), const V3(.55, .4, .45), c);
        s.orb(const V3(0, .98, .17), const V3(.28, .26, .25), dark);
        eyes(s, 1.04, z: .4);
        s.box(const V3(0, .73, .42), const V3(.03, .44, .025), ivory);
        for (final x in [-.57, .57])
          for (final z in [-.24, .1, .32])
            s.box(V3(x, .34, z), const V3(.3, .07, .07), dark);
        s.pyramid(const V3(0, 1.19, .14), .11, .3, gold);
        break;
      case 6:
        for (final x in [-.25, 0.0, .25])
          for (final y in [.55, .8, 1.05])
            s.orb(V3(x, y, 0), const V3(.28, .28, .32), c, slices: 8, rings: 4);
        s.orb(
          const V3(0, 1.07, .25),
          const V3(.27, .32, .24),
          const Color(0xFF8C797C),
        );
        eyes(s, 1.13, z: .46);
        for (final x in [-.34, .34])
          s.orb(V3(x, 1.16, .17), const V3(.15, .2, .14), gold);
        break;
      case 8:
        s.orb(const V3(0, .68, 0), const V3(.47, .61, .32), c);
        s.orb(const V3(0, 1.24, 0), const V3(.43, .37, .3), c);
        for (final x in [-.2, .2])
          s.orb(V3(x, 1.27, .27), const V3(.21, .24, .08), ivory);
        eyes(s, 1.3, z: .35);
        s.pyramid(const V3(0, 1.04, .33), .1, .15, gold);
        wings(s, c, y: .7, reach: .7);
        break;
      case 10:
        s.orb(const V3(0, .84, 0), const V3(.28, .48, .25), c);
        s.orb(const V3(0, 1.28, 0), const V3(.3, .27, .26), c);
        wings(s, c, y: 1, reach: 1.02);
        eyes(s, 1.3, z: .25);
        for (final x in [-.2, .2]) s.pyramid(V3(x, 1.44, 0), .13, .29, c);
        s.box(const V3(0, .74, .24), const V3(.24, .24, .15), ivory);
        break;
      case 11:
        s.box(const V3(0, .55, 0), const V3(.82, .55, .53), c);
        s.box(const V3(0, .99, -.1), const V3(.86, .21, .56), gold);
        eyes(s, .72, z: .29);
        for (final x in [-.3, -.1, .1, .3])
          s.pyramid(V3(x, .82, .3), .07, .13, ivory);
        s.box(const V3(0, .43, .29), const V3(.16, .16, .05), gold);
        break;
      case 12:
        s.orb(
          const V3(0, .52, 0),
          const V3(.65, .45, .55),
          c,
          slices: 8,
          rings: 4,
        );
        s.orb(const V3(0, .51, .54), const V3(.28, .23, .25), ivory);
        eyes(s, .58, z: .73, gap: .12);
        for (final x in [-.4, .4])
          for (final z in [-.3, .3])
            s.box(V3(x, .13, z), const V3(.25, .2, .27), c);
        for (final x in [-.2, .15])
          crystal(s, V3(x, .98, -.05), const Color(0xFF97C48A), scale: .7);
        break;
      case 13:
        s.orb(const V3(0, .72, 0), const V3(.4, .35, .35), c);
        eyes(s, .81, z: .32);
        for (final sign in [-1.0, 1.0])
          for (var i = 0; i < 4; i++) {
            final z = -.35 + i * .22;
            s.face([
              V3(sign * .2, .7, z),
              V3(sign * .85, .45, z),
              V3(sign * .72, .09, z),
              V3(sign * .65, .4, z),
            ], gold);
          }
        s.orb(const V3(0, 1.05, 0), const V3(.23, .08, .23), ivory);
        break;
      case 14:
        s.orb(
          const V3(0, 1.1, 0),
          const V3(.52, .35, .4),
          c,
          slices: 10,
          rings: 4,
        );
        eyes(s, 1.1, z: .37);
        for (var i = 0; i < 7; i++) {
          final x = (i - 3) * .12;
          s.box(
            V3(x, .55, .05),
            V3(.04, .55 + (i % 2) * .17, .045),
            i.isEven ? c : gold,
          );
        }
        break;
    }
    _details(s, kind, c);
  }

  /// Painted markings and silhouette details specific to all eighteen species.
  static void _details(Scene3D s, int kind, Color c) {
    final shade = MiniatureDetails.shade(c, .27),
        light = MiniatureDetails.light(c, .3);
    switch (kind) {
      case 0:
        for (final x in [-.25, .25])
          s.orb(
            V3(x, .94, .215),
            const V3(.035, .035, .022),
            gold,
            slices: 5,
            rings: 2,
          );
        MiniatureDetails.rod(
          s,
          const V3(0, .75, .31),
          const V3(0, .89, .31),
          .016,
          dark,
          sides: 4,
        );
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          s.box(
            V3(math.cos(a) * .19, .75 + math.sin(a) * .19, .301),
            const V3(.027, .03, .014),
            gold,
          );
        }
        s.box(const V3(.36, 1.29, -.02), const V3(.18, .075, .075), gold);
        for (final y in [1.2, 1.38])
          s.orb(
            V3(.49, y, -.02),
            const V3(.09, .08, .06),
            gold,
            slices: 6,
            rings: 2,
          );
        s.box(const V3(0, 1.58, 0), const V3(.11, .08, .09), gold);
        break;
      case 1:
        s.orb(
          const V3(0, .58, .29),
          const V3(.26, .31, .052),
          ivory,
          slices: 8,
          rings: 3,
        );
        for (final y in [.34, .56, .78])
          s.orb(
            V3(.485, y, -.22),
            const V3(.251, .065, .216),
            shade,
            slices: 6,
            rings: 2,
          );
        for (final sign in [-1.0, 1.0])
          s.face([
            V3(sign * .19, 1.52, .026),
            V3(sign * .3, 1.72, -.025),
            V3(sign * .36, 1.51, .026),
          ], ivory);
        s.box(
          const V3(-.45, .45, .12),
          const V3(.24, .3, .21),
          const Color(0xFFCB8C74),
        );
        MiniatureDetails.rod(
          s,
          const V3(-.54, .6, .12),
          const V3(-.48, .76, .12),
          .019,
          gold,
        );
        MiniatureDetails.rod(
          s,
          const V3(-.48, .76, .12),
          const V3(-.36, .6, .12),
          .019,
          gold,
        );
        MiniatureDetails.star(s, const V3(-.45, .46, .233), .066, ivory);
        break;
      case 2:
        for (final sign in [-1.0, 1.0]) {
          s.orb(
            V3(sign * .29, .16, .16),
            const V3(.18, .135, .2),
            shade,
            slices: 6,
            rings: 3,
          );
          MiniatureDetails.stitch(
            s,
            V3(sign * .05, .31, .395),
            V3(sign * .28, .38, .365),
            c,
            count: 4,
          );
        }
        s.face([
          const V3(-.25, 1.395, -.09),
          const V3(.28, 1.4, -.09),
          const V3(.32, 1.57, -.02),
          const V3(.02, 1.73, .01),
        ], shade);
        s.orb(
          const V3(.32, 1.55, 0),
          const V3(.078, .078, .08),
          ivory,
          slices: 6,
          rings: 3,
        );
        MiniatureDetails.star(s, const V3(-.07, .47, .404), .068, gold);
        break;
      case 3:
        MiniatureDetails.rod(
          s,
          const V3(-.45, .535, .119),
          const V3(0, .86, .149),
          .014,
          gold,
          sides: 4,
        );
        MiniatureDetails.rod(
          s,
          const V3(.45, .535, .119),
          const V3(0, .86, .149),
          .014,
          gold,
          sides: 4,
        );
        s.box(
          const V3(.31, 1.065, .137),
          const V3(.16, .12, .025),
          const Color(0xFFB7A2B4),
        );
        MiniatureDetails.star(s, const V3(.31, 1.065, .158), .04, ivory);
        for (final sign in [-1.0, 1.0]) {
          MiniatureDetails.rod(
            s,
            V3(sign * .3, .52, 0),
            V3(sign * .38, .3, .06),
            .035,
            shade,
          );
          s.orb(
            V3(sign * .4, .29, .1),
            const V3(.13, .065, .13),
            shade,
            slices: 6,
            rings: 2,
          );
          s.face([
            V3(sign * .46, .85, 0),
            V3(sign * .67, .98, .03),
            V3(sign * .61, .74, .065),
          ], c);
        }
        break;
      case 4:
        s.orb(
          const V3(-.24, .95, .317),
          const V3(.105, .08, .018),
          ivory,
          slices: 6,
          rings: 2,
        );
        for (final p in [
          const V3(-.34, .4, .31),
          const V3(.31, .5, .33),
          const V3(.23, .98, .23),
        ])
          MiniatureDetails.jewel(s, p, .043, .067, light);
        s.orb(
          const V3(.34, 1.024, 0),
          const V3(.05, .07, .045),
          gold,
          slices: 6,
          rings: 2,
        );
        break;
      case 5:
        for (final sign in [-1.0, 1.0]) {
          s.face([
            V3(sign * .025, .67, .459),
            V3(sign * .43, .57, .308),
            V3(sign * .45, .76, .19),
            V3(sign * .05, .93, .271),
          ], gold);
          MiniatureDetails.rod(
            s,
            V3(sign * .18, 1.15, .18),
            V3(sign * .34, 1.37, .12),
            .024,
            gold,
          );
          s.orb(
            V3(sign * .35, 1.38, .12),
            const V3(.055, .055, .055),
            ivory,
            slices: 5,
            rings: 2,
          );
          for (final z in [-.24, .1, .32])
            MiniatureDetails.rod(
              s,
              V3(sign * .69, .34, z),
              V3(sign * .76, .18, z + .06),
              .03,
              shade,
            );
        }
        MiniatureDetails.jewel(s, const V3(0, .65, .476), .09, .13, ivory);
        break;
      case 6:
        for (final sign in [-1.0, 1.0]) {
          s.orb(
            V3(sign * .28, .2, .02),
            const V3(.11, .16, .115),
            shade,
            slices: 6,
            rings: 3,
          );
          s.orb(
            V3(sign * .35, 1.18, .18),
            const V3(.13, .145, .13),
            gold,
            slices: 8,
            rings: 3,
          );
          s.orb(
            V3(sign * .355, 1.18, .301),
            const V3(.065, .075, .03),
            shade,
            slices: 6,
            rings: 2,
          );
        }
        MiniatureDetails.star(
          s,
          const V3(.13, .74, .329),
          .075,
          const Color(0xFFAC9EC6),
        );
        s.orb(
          const V3(-.05, .98, .475),
          const V3(.07, .045, .035),
          ivory,
          slices: 6,
          rings: 2,
        );
        break;
      case 7:
        s.box(const V3(0, 1.285, .309), const V3(.61, .1, .027), dark);
        for (final x in [-.17, .17])
          s.box(
            V3(x, 1.287, .33),
            const V3(.12, .035, .014),
            const Color(0xFFAFCED0),
          );
        s.face([
          const V3(-.71, 1.01, .255),
          const V3(-.3, 1.01, .255),
          const V3(-.33, .59, .255),
          const V3(-.5, .47, .26),
          const V3(-.68, .59, .255),
        ], gold);
        s.face([
          const V3(-.655, .946, .271),
          const V3(-.36, .946, .271),
          const V3(-.38, .625, .271),
          const V3(-.5, .54, .277),
          const V3(-.63, .625, .271),
        ], shade);
        MiniatureDetails.star(s, const V3(-.51, .775, .291), .093, ivory);
        MiniatureDetails.rod(
          s,
          const V3(.47, .42, .13),
          const V3(.47, 1.2, .13),
          .038,
          gold,
        );
        s.pyramid(const V3(.47, 1.19, .13), .08, .27, ivory);
        break;
      case 8:
        for (final sign in [-1.0, 1.0]) {
          s.pyramid(V3(sign * .3, 1.48, -.025), .12, .25, shade);
          for (var i = 0; i < 3; i++)
            s.face([
              V3(sign * (.37 + i * .085), .88 - i * .06, .055),
              V3(sign * (.59 + i * .055), .88 - i * .07, .047),
              V3(sign * (.44 + i * .07), .45 - i * .015, .071),
            ], i.isEven ? light : c);
        }
        for (final y in [.52, .71, .88])
          MiniatureDetails.star(s, V3(0, y, .317), .05, gold);
        s.box(const V3(0, .29, .32), const V3(.54, .085, .3), gold);
        s.box(const V3(0, .35, .34), const V3(.49, .04, .27), ivory);
        break;
      case 9:
        s.orb(
          const V3(-.25, .97, .276),
          const V3(.098, .063, .02),
          const Color(0xFFC4BADD),
          slices: 6,
          rings: 2,
        );
        for (final x in [-.46, .43])
          s.orb(
            V3(x, .14, .06),
            const V3(.19, .07, .18),
            shade,
            slices: 6,
            rings: 2,
          );
        s.face([
          const V3(-.1, .49, .407),
          const V3(.1, .49, .407),
          const V3(.06, .434, .42),
          const V3(-.06, .434, .42),
        ], ivory);
        break;
      case 10:
        for (final sign in [-1.0, 1.0])
          s.face([
            V3(sign * .15, 1.48, .064),
            V3(sign * .21, 1.69, .013),
            V3(sign * .285, 1.49, .06),
          ], const Color(0xFFC59688));
        MiniatureDetails.taper(
          s,
          const V3(0, .59, .24),
          .23,
          const V3(.14, 0, .105),
          const V3(.17, 0, .13),
          ivory,
        );
        MiniatureDetails.taper(
          s,
          const V3(0, .81, .24),
          .012,
          const V3(.136, 0, .103),
          const V3(.136, 0, .103),
          const Color(0xFF795345),
        );
        s.orb(
          const V3(.177, .72, .24),
          const V3(.065, .08, .04),
          gold,
          slices: 6,
          rings: 2,
        );
        MiniatureDetails.jewel(s, const V3(0, .7, .371), .044, .059, c);
        break;
      case 11:
        for (final x in [-.34, .34]) {
          s.box(V3(x, .56, .282), const V3(.064, .52, .03), gold);
          for (final y in [.39, .67])
            s.orb(
              V3(x, y, .31),
              const V3(.025, .025, .02),
              ivory,
              slices: 5,
              rings: 2,
            );
        }
        for (final y in [.43, .6])
          s.box(V3(0, y, .269), const V3(.75, .012, .015), shade);
        s.orb(
          const V3(.2, .86, .32),
          const V3(.12, .038, .095),
          const Color(0xFFCC8D89),
          slices: 6,
          rings: 2,
        );
        MiniatureDetails.jewel(s, const V3(0, .43, .325), .041, .06, dark);
        for (final x in [-.2, .02, .24])
          s.orb(
            V3(x, 1.135, -.06),
            const V3(.11, .029, .105),
            gold,
            slices: 8,
            rings: 2,
          );
        break;
      case 12:
        for (final x in [-.3, 0.0, .3]) {
          s.orb(
            V3(x, .795, -.02),
            const V3(.25, .12, .3),
            x == 0 ? light : shade,
            slices: 6,
            rings: 3,
          );
          MiniatureDetails.jewel(s, V3(x, .805, .251), .079, .057, gold);
        }
        s.pyramid(
          const V3(-.18, 1.12, -.05),
          .14,
          .2,
          const Color(0xFF739068),
          sides: 5,
        );
        for (final x in [-.48, .43])
          s.orb(
            V3(x, .72, -.17),
            const V3(.13, .07, .14),
            const Color(0xFFA8B47D),
            slices: 6,
            rings: 2,
          );
        break;
      case 13:
        s.orb(
          const V3(0, .79, .348),
          const V3(.26, .245, .035),
          gold,
          slices: 10,
          rings: 2,
        );
        s.orb(
          const V3(0, .79, .388),
          const V3(.21, .199, .024),
          ivory,
          slices: 10,
          rings: 2,
        );
        MiniatureDetails.rod(
          s,
          const V3(0, .79, .42),
          const V3(-.085, .92, .42),
          .014,
          dark,
          sides: 4,
        );
        MiniatureDetails.rod(
          s,
          const V3(0, .79, .422),
          const V3(.137, .8, .422),
          .012,
          dark,
          sides: 4,
        );
        for (final sign in [-1.0, 1.0])
          for (var i = 0; i < 4; i++)
            s.orb(
              V3(sign * .73, .43, -.35 + i * .22),
              const V3(.058, .065, .063),
              c,
              slices: 5,
              rings: 2,
            );
        break;
      case 14:
        s.orb(
          const V3(-.23, 1.27, .26),
          const V3(.12, .048, .039),
          ivory,
          slices: 6,
          rings: 2,
        );
        for (var i = 0; i < 7; i++) {
          final x = (i - 3) * .12;
          s.orb(
            V3(x, .25 - (i % 2) * .085, .05),
            const V3(.043, .055, .043),
            i.isEven ? const Color(0xFFD2ACCE) : const Color(0xFF96C8C2),
            slices: 5,
            rings: 2,
          );
        }
        for (final x in [-.3, 0.0, .3])
          MiniatureDetails.star(s, V3(x, 1.03, .397), .042, gold);
        break;
      case 15:
        for (final sign in [-1.0, 1.0]) {
          s.face([
            V3(sign * .18, 1.51, .048),
            V3(sign * .29, 1.75, -.02),
            V3(sign * .36, 1.5, .048),
          ], const Color(0xFFBAA8CB));
          s.face([
            V3(sign * .06, .9, .288),
            V3(sign * .25, .99, .253),
            V3(sign * .19, .56, .301),
            const V3(0, .68, .329),
          ], ivory);
          s.orb(
            V3(sign * .23, .16, .13),
            const V3(.13, .095, .16),
            shade,
            slices: 6,
            rings: 3,
          );
        }
        MiniatureDetails.star(s, const V3(0, 1.457, .273), .077, ivory);
        s.orb(
          const V3(.51, .88, -.24),
          const V3(.23, .17, .2),
          light,
          slices: 6,
          rings: 3,
        );
        break;
      case 16:
        for (final sign in [-1.0, 1.0]) {
          s.orb(
            V3(sign * .32, .17, .15),
            const V3(.2, .135, .22),
            shade,
            slices: 6,
            rings: 3,
          );
          for (final x in [.25, .32, .39])
            s.pyramid(V3(sign * x, .15, .33), .034, .076, ivory);
        }
        for (var i = 0; i < 3; i++)
          s.face([
            V3(-.19, .41 + i * .125, .322),
            V3(.19, .41 + i * .125, .322),
            V3(.16, .48 + i * .125, .338),
            V3(-.16, .48 + i * .125, .338),
          ], i.isEven ? gold : ivory);
        for (final y in [.53, .75, .98])
          s.pyramid(V3(0, y, -.32), .11, .18, gold);
        break;
      case 17:
        s.face([
          const V3(-.29, 1.3, .268),
          const V3(.29, 1.3, .268),
          const V3(.24, 1.1, .298),
          const V3(0, 1.03, .314),
          const V3(-.24, 1.1, .298),
        ], dark);
        MiniatureDetails.jewel(
          s,
          const V3(0, 1.215, .334),
          .09,
          .064,
          const Color(0xFFB9E1D5),
        );
        MiniatureDetails.jewel(s, const V3(0, .73, .24), .123, .21, gold);
        for (final sign in [-1.0, 1.0])
          s.face([
            V3(sign * .26, .74, -.09),
            V3(sign * .46, .22, -.14),
            V3(sign * .12, .35, .04),
          ], shade);
        break;
    }
  }

  static void boss(Scene3D s, int kind) {
    final c = [
      const Color(0xFF719589),
      const Color(0xFFB99461),
      const Color(0xFF6F989E),
      const Color(0xFFA47598),
      const Color(0xFFB16F5D),
      const Color(0xFF8B7CA9),
    ][kind];
    final shade = MiniatureDetails.shade(c, .3),
        light = MiniatureDetails.light(c, .24);
    switch (kind) {
      case 0: // Inkfeather, an owl-like academic sovereign.
        s.orb(
          const V3(0, .74, -.015),
          const V3(.48, .64, .34),
          shade,
          slices: 10,
          rings: 5,
        );
        for (final sign in [-1.0, 1.0]) {
          s.face([
            V3(sign * .2, 1.23, -.22),
            V3(sign * .67, .91, -.27),
            V3(sign * .63, .21, -.23),
            V3(sign * .32, .33, -.03),
          ], c);
          for (var i = 0; i < 3; i++)
            s.face([
              V3(sign * (.3 + i * .1), .99 - i * .04, -.07),
              V3(sign * (.45 + i * .08), .93 - i * .04, -.1),
              V3(sign * (.4 + i * .07), .27 - i * .01, -.035),
            ], i.isEven ? light : c);
          s.orb(
            V3(sign * .21, .15, .14),
            const V3(.17, .11, .2),
            gold,
            slices: 6,
            rings: 3,
          );
        }
        s.orb(
          const V3(0, 1.42, 0),
          const V3(.46, .4, .32),
          c,
          slices: 10,
          rings: 5,
        );
        for (final x in [-.2, .2])
          s.orb(
            V3(x, 1.44, .245),
            const V3(.235, .265, .089),
            ivory,
            slices: 8,
            rings: 4,
          );
        eyes(s, 1.47, z: .337, gap: .18);
        s.pyramid(const V3(0, 1.255, .369), .105, .14, gold);
        s.box(const V3(0, 1.823, -.012), const V3(.85, .052, .65), dark);
        MiniatureDetails.taper(
          s,
          const V3(0, 1.82, -.02),
          .17,
          const V3(.265, 0, .245),
          const V3(.24, 0, .22),
          shade,
        );
        MiniatureDetails.rod(
          s,
          const V3(0, 1.86, .06),
          const V3(.38, 1.86, .2),
          .017,
          gold,
        );
        MiniatureDetails.rod(
          s,
          const V3(.38, 1.86, .2),
          const V3(.38, 1.53, .2),
          .019,
          gold,
        );
        for (final sign in [-1.0, 1.0]) {
          s.face([
            V3(sign * .13, 1.12, .315),
            V3(sign * .3, 1.18, .253),
            V3(sign * .25, .39, .305),
            V3(sign * .1, .35, .342),
          ], gold);
          MiniatureDetails.star(s, V3(sign * .19, .73, .35), .059, ivory);
          s.box(V3(sign * .62, .83, .16), const V3(.26, .36, .13), shade);
          s.box(V3(sign * .62, .83, .238), const V3(.205, .29, .04), ivory);
          for (final y in [.75, .82, .89])
            s.box(V3(sign * .62, y, .264), const V3(.145, .012, .016), gold);
        }
        break;
      case 1: // Fullpurse has a pear-shaped waistcoat, cane and overfilled bag.
        s.orb(
          const V3(0, .69, 0),
          const V3(.61, .61, .41),
          c,
          slices: 10,
          rings: 5,
        );
        s.orb(
          const V3(0, .76, .3),
          const V3(.36, .45, .13),
          dark,
          slices: 8,
          rings: 4,
        );
        s.orb(
          const V3(0, 1.36, 0),
          const V3(.4, .32, .32),
          light,
          slices: 10,
          rings: 5,
        );
        eyes(s, 1.38, z: .304);
        for (final sign in [-1.0, 1.0]) {
          s.face([
            V3(sign * .02, 1.12, .358),
            V3(sign * .19, 1.22, .26),
            V3(sign * .36, .9, .346),
            V3(sign * .11, .99, .437),
          ], ivory);
          s.orb(
            V3(sign * .25, .15, .13),
            const V3(.23, .11, .24),
            dark,
            slices: 6,
            rings: 3,
          );
        }
        s.box(
          const V3(0, 1.118, .392),
          const V3(.18, .08, .06),
          const Color(0xFFAA6867),
        );
        MiniatureDetails.taper(
          s,
          const V3(0, 1.626, -.028),
          .058,
          const V3(.45, 0, .37),
          const V3(.45, 0, .37),
          dark,
        );
        MiniatureDetails.taper(
          s,
          const V3(0, 1.67, -.028),
          .4,
          const V3(.275, 0, .245),
          const V3(.29, 0, .25),
          dark,
        );
        MiniatureDetails.taper(
          s,
          const V3(0, 1.692, -.028),
          .086,
          const V3(.28, 0, .251),
          const V3(.28, 0, .251),
          gold,
        );
        for (final y in [.54, .72, .9])
          s.orb(
            V3(0, y, .445),
            const V3(.043, .043, .027),
            gold,
            slices: 6,
            rings: 2,
          );
        s.orb(
          const V3(.66, .56, .03),
          const V3(.32, .39, .28),
          gold,
          slices: 8,
          rings: 4,
        );
        MiniatureDetails.taper(
          s,
          const V3(.66, .85, .03),
          .08,
          const V3(.14, 0, .14),
          const V3(.12, 0, .12),
          shade,
          sides: 6,
        );
        MiniatureDetails.star(s, const V3(.66, .57, .314), .12, ivory);
        MiniatureDetails.rod(
          s,
          const V3(-.67, .16, .09),
          const V3(-.67, 1.02, .09),
          .038,
          dark,
        );
        s.orb(
          const V3(-.67, 1.06, .09),
          const V3(.088, .082, .077),
          gold,
          slices: 8,
          rings: 3,
        );
        break;
      case 2: // Zero is a broad industrial automaton with articulated fists.
        MiniatureDetails.taper(
          s,
          const V3(0, .43, 0),
          .7,
          const V3(.41, 0, .29),
          const V3(.49, 0, .285),
          c,
        );
        MiniatureDetails.taper(
          s,
          const V3(0, 1.1, 0),
          .12,
          const V3(.46, 0, .28),
          const V3(.34, 0, .24),
          gold,
        );
        MiniatureDetails.taper(
          s,
          const V3(0, 1.2, 0),
          .39,
          const V3(.34, 0, .26),
          const V3(.31, 0, .24),
          light,
        );
        s.box(const V3(0, 1.41, .265), const V3(.53, .135, .043), dark);
        for (final x in [-.16, 0.0, .16])
          s.box(
            V3(x, 1.423, .291),
            const V3(.09, .039, .012),
            const Color(0xFFAFE0D1),
          );
        for (final sign in [-1.0, 1.0]) {
          s.orb(
            V3(sign * .55, .99, 0),
            const V3(.23, .23, .23),
            gold,
            slices: 8,
            rings: 3,
          );
          MiniatureDetails.taper(
            s,
            V3(sign * .65, .51, .05),
            .4,
            const V3(.215, 0, .23),
            const V3(.185, 0, .19),
            shade,
          );
          s.box(V3(sign * .65, .46, .12), const V3(.4, .25, .34), c);
          for (final x in [-.11, .0, .11])
            s.box(
              V3(sign * .65 + x, .456, .3),
              const V3(.056, .18, .035),
              gold,
            );
          s.box(V3(sign * .235, .21, .07), const V3(.33, .33, .45), shade);
          s.box(V3(sign * .235, .08, .12), const V3(.37, .12, .53), dark);
          crystal(
            s,
            V3(sign * .56, 1.27, -.03),
            const Color(0xFFA4D5C4),
            scale: .75,
          );
        }
        MiniatureDetails.jewel(s, const V3(0, .81, .303), .18, .23, gold);
        MiniatureDetails.jewel(
          s,
          const V3(0, .81, .371),
          .115,
          .15,
          const Color(0xFFBCEAD9),
        );
        MiniatureDetails.rod(
          s,
          const V3(.14, 1.59, -.07),
          const V3(.14, 1.96, -.07),
          .028,
          gold,
        );
        s.orb(
          const V3(.14, 1.98, -.07),
          const V3(.064, .065, .064),
          const Color(0xFFE3B079),
          slices: 6,
          rings: 3,
        );
        for (final y in [.5, .59])
          s.box(V3(0, y, .297), const V3(.4, .035, .02), dark);
        break;
      case 3: // Masquerade maestro, a slender mask and sweeping split coat.
        for (final sign in [-1.0, 1.0]) {
          s.face([
            V3(sign * .19, 1.33, -.22),
            V3(sign * .62, 1.17, -.25),
            V3(sign * .73, .14, -.37),
            V3(sign * .19, .34, -.3),
          ], shade);
          MiniatureDetails.rod(
            s,
            V3(sign * .57, 1.13, -.25),
            V3(sign * .71, .19, -.36),
            .018,
            gold,
          );
          s.box(V3(sign * .16, .25, .03), const V3(.15, .44, .19), dark);
          s.orb(
            V3(sign * .19, .07, .09),
            const V3(.17, .075, .2),
            dark,
            slices: 6,
            rings: 3,
          );
        }
        MiniatureDetails.taper(
          s,
          const V3(0, .55, 0),
          .68,
          const V3(.23, 0, .18),
          const V3(.32, 0, .205),
          c,
        );
        for (final sign in [-1.0, 1.0])
          s.face([
            V3(sign * .28, 1.17, .193),
            V3(sign * .05, 1.09, .232),
            V3(sign * .13, .76, .21),
          ], ivory);
        s.orb(
          const V3(0, 1.51, 0),
          const V3(.315, .36, .285),
          shade,
          slices: 10,
          rings: 5,
        );
        s.orb(
          const V3(-.06, 1.52, .261),
          const V3(.291, .3, .078),
          ivory,
          slices: 8,
          rings: 4,
        );
        for (final x in [-.14, .12]) {
          s.face([
            V3(x - .09, 1.58, .332),
            V3(x + .085, 1.595, .332),
            V3(x + .06, 1.532, .345),
            V3(x - .063, 1.524, .345),
          ], dark);
          MiniatureDetails.jewel(s, V3(x, 1.557, .351), .023, .022, gold);
        }
        s.face([
          const V3(-.13, 1.394, .332),
          const V3(.11, 1.394, .332),
          const V3(.02, 1.342, .34),
        ], c);
        for (var i = 0; i < 3; i++)
          s.face([
            V3(.19 + i * .035, 1.74, -.03),
            V3(.3 + i * .12, 1.99 - i * .08, -.05),
            V3(.39 + i * .08, 1.72 - i * .06, -.02),
          ], i.isEven ? c : gold);
        MiniatureDetails.rod(
          s,
          const V3(.52, .46, .13),
          const V3(.64, 1.58, .13),
          .025,
          gold,
        );
        MiniatureDetails.star(s, const V3(.64, 1.64, .13), .14, gold);
        s.orb(
          const V3(-.45, .77, .14),
          const V3(.2, .27, .09),
          gold,
          slices: 8,
          rings: 3,
        );
        s.orb(
          const V3(-.45, .79, .231),
          const V3(.135, .18, .019),
          dark,
          slices: 8,
          rings: 3,
        );
        for (final x in [-.52, -.45, -.38])
          MiniatureDetails.rod(
            s,
            V3(x, .61, .26),
            V3(x, 1.01, .26),
            .008,
            ivory,
            sides: 4,
          );
        break;
      case 4: // Emberwarden, a fortress silhouette and banner-shaped shield.
        MiniatureDetails.taper(
          s,
          const V3(0, .35, 0),
          .86,
          const V3(.35, 0, .26),
          const V3(.48, 0, .29),
          shade,
        );
        s.face([
          const V3(-.38, 1.12, .256),
          const V3(.38, 1.12, .256),
          const V3(.29, .68, .314),
          const V3(0, .56, .353),
          const V3(-.29, .68, .314),
        ], c);
        for (final sign in [-1.0, 1.0]) {
          s.orb(
            V3(sign * .51, 1.12, 0),
            const V3(.31, .24, .3),
            dark,
            slices: 8,
            rings: 3,
          );
          s.orb(
            V3(sign * .53, 1.15, .018),
            const V3(.27, .195, .263),
            c,
            slices: 8,
            rings: 3,
          );
          s.pyramid(V3(sign * .59, 1.31, -.02), .13, .32, gold);
          s.box(V3(sign * .24, .17, .07), const V3(.32, .28, .42), dark);
          s.box(V3(sign * .24, .284, .225), const V3(.25, .2, .05), gold);
        }
        MiniatureDetails.taper(
          s,
          const V3(0, 1.19, 0),
          .5,
          const V3(.31, 0, .26),
          const V3(.33, 0, .25),
          dark,
        );
        s.face([
          const V3(-.29, 1.61, .19),
          const V3(.29, 1.61, .19),
          const V3(.235, 1.26, .252),
          const V3(0, 1.18, .29),
          const V3(-.235, 1.26, .252),
        ], c);
        s.box(const V3(0, 1.467, .273), const V3(.49, .075, .026), dark);
        for (final x in [-.14, .14])
          s.box(
            V3(x, 1.474, .291),
            const V3(.137, .024, .013),
            const Color(0xFFFFD49A),
          );
        MiniatureDetails.rod(
          s,
          const V3(0, 1.26, .288),
          const V3(0, 1.61, .217),
          .031,
          gold,
        );
        s.face([
          const V3(-.06, 1.68, -.2),
          const V3(.06, 1.68, -.2),
          const V3(.06, 1.96, .07),
          const V3(-.06, 1.96, .07),
        ], gold);
        s.face([
          const V3(-.9, 1.08, .27),
          const V3(-.41, 1.08, .27),
          const V3(-.42, .48, .27),
          const V3(-.65, .22, .29),
          const V3(-.89, .48, .27),
        ], gold);
        s.face([
          const V3(-.84, 1.01, .289),
          const V3(-.47, 1.01, .289),
          const V3(-.48, .51, .289),
          const V3(-.65, .32, .311),
          const V3(-.83, .51, .289),
        ], shade);
        MiniatureDetails.jewel(
          s,
          const V3(-.65, .75, .316),
          .104,
          .19,
          const Color(0xFFE2A779),
        );
        MiniatureDetails.rod(
          s,
          const V3(.69, .19, .1),
          const V3(.69, 1.61, .1),
          .045,
          gold,
        );
        s.pyramid(const V3(.69, 1.59, .1), .125, .36, ivory);
        MiniatureDetails.jewel(s, const V3(0, .88, .345), .092, .17, gold);
        break;
      case 5: // Fateweaver floats inside an open celestial astrolabe.
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6, b = (i + 1) * math.pi / 6;
          MiniatureDetails.rod(
            s,
            V3(math.cos(a) * .94, 1.1 + math.sin(a) * .87, -.23),
            V3(math.cos(b) * .94, 1.1 + math.sin(b) * .87, -.23),
            .018,
            gold,
            sides: 4,
          );
        }
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          crystal(
            s,
            V3(math.cos(a) * .95, 1.1 + math.sin(a) * .88, -.23),
            i.isEven ? gold : const Color(0xFFC0B5D9),
            scale: .58,
          );
        }
        wings(s, shade, y: 1.05, reach: 1.05);
        MiniatureDetails.taper(
          s,
          const V3(0, .31, 0),
          .79,
          const V3(.13, 0, .13),
          const V3(.35, 0, .23),
          shade,
        );
        for (final sign in [-1.0, 1.0]) {
          s.face([
            V3(sign * .12, 1.08, .213),
            V3(sign * .29, 1.09, .197),
            V3(sign * .38, .22, .071),
            V3(sign * .1, .4, .185),
          ], c);
          MiniatureDetails.rod(
            s,
            V3(sign * .26, 1.07, .208),
            V3(sign * .37, .25, .091),
            .018,
            gold,
          );
          s.orb(
            V3(sign * .43, .87, .12),
            const V3(.11, .14, .11),
            ivory,
            slices: 6,
            rings: 3,
          );
          MiniatureDetails.star(
            s,
            V3(sign * .54, 1.01, .2),
            .12,
            const Color(0xFFACD6C9),
          );
        }
        s.orb(
          const V3(0, 1.39, 0),
          const V3(.31, .37, .26),
          shade,
          slices: 10,
          rings: 5,
        );
        s.face([
          const V3(-.23, 1.56, .201),
          const V3(.23, 1.56, .201),
          const V3(.19, 1.25, .24),
          const V3(0, 1.14, .275),
          const V3(-.19, 1.25, .24),
        ], ivory);
        for (final x in [-.105, .105]) {
          s.face([
            V3(x - .069, 1.435, .256),
            V3(x + .069, 1.435, .256),
            V3(x + .045, 1.379, .274),
            V3(x - .045, 1.379, .274),
          ], dark);
          MiniatureDetails.jewel(
            s,
            V3(x, 1.408, .28),
            .025,
            .023,
            const Color(0xFFAECEC8),
          );
        }
        for (final sign in [-1.0, 1.0]) {
          MiniatureDetails.rod(
            s,
            V3(sign * .23, 1.62, 0),
            V3(sign * .38, 1.91, -.02),
            .058,
            gold,
          );
          s.pyramid(V3(sign * .38, 1.9, -.02), .08, .23, ivory);
        }
        s.pyramid(const V3(0, 1.71, .035), .13, .37, gold, sides: 5);
        MiniatureDetails.jewel(
          s,
          const V3(0, 1.63, .225),
          .072,
          .112,
          const Color(0xFFA7D4CC),
        );
        MiniatureDetails.jewel(s, const V3(0, .91, .284), .147, .197, gold);
        MiniatureDetails.jewel(
          s,
          const V3(0, .91, .344),
          .095,
          .135,
          const Color(0xFFA8D6CE),
        );
        break;
    }
  }
}
