import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/player.dart';
import '../art/equipment_layers.dart';
import 'scene_3d.dart';
import 'career_details.dart';
import 'creature_models.dart';
import 'miniature_details.dart';

class Models3D {
  static const armorColors = {
    'coat': Color(0xFFAE794C),
    'robe': Color(0xFF626FBE),
    'plate': Color(0xFFA9C4D9),
    'ranger_cloak': Color(0xFF417D69),
    'scholar_coat': Color(0xFF446C92),
    'flame_armor': Color(0xFFB85648),
    'astral_robe': Color(0xFF765AAA),
  };
  static void armorDetails(Scene3D s, String id) {
    if (id == 'none') return;
    const gold = Color(0xFFDCB66F), cream = Color(0xFFF1DFBD);
    final c = armorColors[id] ?? const Color(0xFF647B76);
    final dark = MiniatureDetails.shade(c, .28);
    if (id == 'ranger_cloak' || id == 'astral_robe') {
      final left = const V3(-.3, 1.17, -.225),
          right = const V3(.3, 1.17, -.225);
      s.face([
        left,
        right,
        const V3(.44, .23, -.4),
        const V3(.17, .28, -.46),
        const V3(0, .18, -.48),
        const V3(-.2, .27, -.46),
        const V3(-.45, .21, -.4),
      ], dark);
      for (final sign in [-1.0, 1.0]) {
        s.face([
          V3(sign * .08, 1.14, -.24),
          V3(sign * .23, 1.14, -.24),
          V3(sign * .34, .28, -.442),
          V3(sign * .15, .26, -.472),
        ], c);
        MiniatureDetails.rod(
          s,
          V3(sign * .29, 1.17, -.24),
          V3(sign * .441, .25, -.41),
          .017,
          gold,
        );
        MiniatureDetails.jewel(
          s,
          V3(sign * .23, 1.126, .192),
          .045,
          .055,
          gold,
        );
      }
      if (id == 'astral_robe')
        for (final y in [.38, .59, .8])
          MiniatureDetails.star(
            s,
            V3(0, y, .3 - (y - .38) * .15),
            .043,
            const Color(0xFFBDDEDF),
          );
    }
    if (id == 'coat' || id == 'scholar_coat') {
      for (final sign in [-1.0, 1.0]) {
        s.box(V3(sign * .19, .76, .224), const V3(.13, .14, .035), dark);
        s.box(V3(sign * .19, .827, .246), const V3(.147, .026, .021), cream);
        MiniatureDetails.stitch(
          s,
          V3(sign * .25, .71, .247),
          V3(sign * .13, .71, .247),
          gold,
          count: 3,
        );
      }
      if (id == 'scholar_coat') {
        for (final sign in [-1.0, 1.0])
          MiniatureDetails.rod(
            s,
            V3(sign * .14, 1.075, .237),
            V3(sign * .14, .87, .246),
            .021,
            gold,
          );
        s.box(
          const V3(.19, .845, .242),
          const V3(.018, .13, .025),
          const Color(0xFFAAC1C8),
        );
      }
    }
    if (id == 'robe' || id == 'astral_robe') {
      s.face([
        const V3(-.09, 1.09, .226),
        const V3(.09, 1.09, .226),
        const V3(.135, .285, .286),
        const V3(0, .23, .304),
        const V3(-.135, .285, .286),
      ], dark);
      for (final sign in [-1.0, 1.0])
        MiniatureDetails.rod(
          s,
          V3(sign * .095, 1.08, .24),
          V3(sign * .132, .29, .299),
          .012,
          gold,
          sides: 4,
        );
      MiniatureDetails.star(s, const V3(0, .82, .265), .07, gold);
    }
    if (id == 'plate' || id == 'flame_armor') {
      for (final sign in [-1.0, 1.0]) {
        MiniatureDetails.taper(
          s,
          V3(sign * .38, .7, 0),
          .14,
          const V3(.113, 0, .124),
          const V3(.122, 0, .127),
          dark,
        );
        for (final y in [.855, .945])
          MiniatureDetails.rod(
            s,
            V3(sign * .035, y, .269),
            V3(sign * .18, y + .026, .239),
            .011,
            gold,
            sides: 4,
          );
      }
    }
    if (id == 'flame_armor') {
      for (final sign in [-1.0, 1.0]) {
        s.pyramid(V3(sign * .35, 1.16, -.015), .13, .2, gold);
        s.pyramid(V3(sign * .42, 1.13, -.07), .09, .15, cream);
      }
      MiniatureDetails.jewel(
        s,
        const V3(0, .946, .279),
        .069,
        .118,
        const Color(0xFFF2BB79),
      );
    }
  }

  static void accessory(Scene3D s, String id) {
    const gold = Color(0xFFF5D18C);
    switch (id) {
      case 'ruby_ring':
        s.orb(
          const V3(.43, .69, .17),
          const V3(.09, .09, .055),
          gold,
          slices: 8,
          rings: 3,
        );
        s.orb(
          const V3(.43, .7, .22),
          const V3(.065, .07, .04),
          const Color(0xFFE96D7B),
          slices: 4,
          rings: 3,
        );
        break;
      case 'sapphire_pendant':
        s.box(const V3(0, 1.03, .23), const V3(.025, .22, .025), gold);
        s.orb(
          const V3(0, .9, .27),
          const V3(.12, .15, .06),
          const Color(0xFF75BCF5),
          slices: 6,
          rings: 4,
        );
        break;
      case 'guardian_brooch':
        s.box(const V3(-.17, 1.03, .25), const V3(.19, .22, .045), gold);
        s.box(
          const V3(-.17, 1.03, .28),
          const V3(.07, .13, .025),
          const Color(0xFF70DBB7),
        );
        break;
      case 'wing_charm':
        for (final sign in [-1.0, 1.0])
          s.face([
            const V3(0, .98, .26),
            V3(sign * .19, 1.13, .26),
            V3(sign * .14, .99, .26),
          ], gold);
        s.orb(
          const V3(0, 1, .28),
          const V3(.065, .08, .04),
          const Color(0xFFBA9DF0),
          slices: 6,
          rings: 3,
        );
        break;
      default:
        break;
    }
  }

  static Color jobColor(String job) => switch (job) {
    'student' => const Color(0xFF57916D),
    'part_timer' => const Color(0xFFC97559),
    'engineer' => const Color(0xFF4988A1),
    'artist' => const Color(0xFFD79652),
    'warrior' => const Color(0xFF8BABB4),
    'scholar' => const Color(0xFFBCA874),
    'president' => const Color(0xFFE9DFCC),
    'mentor' => const Color(0xFF8466AD),
    'hero' => const Color(0xFFE8C35D),
    'apprentice' => const Color(0xFFB08C62),
    'adventurer' => const Color(0xFF598669),
    'doctor' => const Color(0xFFE9F2E9),
    'mage' => const Color(0xFF5167B0),
    'ranger' => const Color(0xFF4E8F67),
    'merchant' => const Color(0xFFA25F72),
    'archmage' => const Color(0xFF9669C1),
    'paladin' => const Color(0xFFF2D783),
    'ranger_master' => const Color(0xFF3F9E8A),
    'alchemist' => const Color(0xFF55A18D),
    'sage' => const Color(0xFF5376A6),
    'bard' => const Color(0xFFC887A1),
    'maestro' => const Color(0xFF6C4F8F),
    'chef' => const Color(0xFFAF705B),
    'gourmet_master' => const Color(0xFFD4A456),
    'guardian' => const Color(0xFF507B9A),
    'warlord' => const Color(0xFFAA5155),
    'dancer' => const Color(0xFFDB8DAA),
    'celestial_dancer' => const Color(0xFFA48ADB),
    'beast_tamer' => const Color(0xFF719669),
    'dragon_tamer' => const Color(0xFF4F969D),
    _ => const Color(0xFF849469),
  };

  /// A hand-painted chibi miniature. Feet, sleeves and held gear keep the
  /// original walk phase so the board animation and equipment previews agree.
  static void hero(
    Scene3D scene,
    V3 pos,
    EquipmentLook look, {
    double scale = 1,
    double walk = 0,
    double facing = 0,
  }) {
    final local = Scene3D();
    look = look.resolvedVisuals;
    final female = look.gender == CharacterGender.female;
    final coat = armorColors[look.armor] ?? jobColor(look.jobId);
    final seam = MiniatureDetails.light(coat, .34);
    final lining = MiniatureDetails.shade(coat, .28);
    const skin = Color(0xFFEFC49D),
        hair = Color(0xFF594032),
        hairLight = Color(0xFF795342);
    const leather = Color(0xFF604B40),
        sole = Color(0xFF403837),
        gold = Color(0xFFDCB66F);
    final step = math.sin(walk) * .12;
    final robed =
        ['robe', 'astral_robe', 'scholar_coat'].contains(look.armor) ||
        ['mage', 'archmage', 'scholar', 'mentor', 'sage'].contains(look.jobId);
    final armored =
        ['plate', 'flame_armor'].contains(look.armor) ||
        [
          'warrior',
          'hero',
          'paladin',
          'guardian',
          'warlord',
        ].contains(look.jobId);
    for (final sign in [-1.0, 1.0]) {
      final foot = V3(sign * .15, .065, .055 + sign * step);
      MiniatureDetails.taper(
        local,
        V3(sign * .15, .13, sign * step),
        .43,
        const V3(.105, 0, .115),
        const V3(.12, 0, .12),
        const Color(0xFF645950),
      );
      local.box(foot, const V3(.245, .105, .35), sole);
      local.orb(
        foot + const V3(0, .08, .035),
        const V3(.127, .12, .185),
        leather,
        slices: 8,
        rings: 3,
      );
      MiniatureDetails.taper(
        local,
        V3(sign * .15, .16, sign * step),
        .16,
        const V3(.121, 0, .132),
        const V3(.113, 0, .126),
        leather,
      );
      local.box(
        V3(sign * .15, .275, .131 + sign * step),
        const V3(.21, .045, .022),
        lining,
      );
      local.box(
        V3(sign * .15, .276, .151 + sign * step),
        const V3(.057, .041, .018),
        gold,
      );
      local.orb(
        V3(sign * .345, 1.065, -sign * step * .55),
        const V3(.17, .17, .175),
        coat,
        slices: 8,
        rings: 3,
      );
      MiniatureDetails.taper(
        local,
        V3(sign * .385, .7, -sign * step),
        .34,
        const V3(.1, 0, .112),
        const V3(.124, 0, .13),
        coat,
      );
      MiniatureDetails.taper(
        local,
        V3(sign * .385, .69, -sign * step),
        .065,
        const V3(.109, 0, .12),
        const V3(.108, 0, .119),
        seam,
      );
      local.orb(
        V3(sign * .39, .645, -sign * step),
        const V3(.105, .108, .105),
        skin,
        slices: 6,
        rings: 3,
      );
    }
    MiniatureDetails.taper(
      local,
      const V3(0, .5, 0),
      .67,
      V3(female ? .245 : .275, 0, .19),
      const V3(.305, 0, .205),
      coat,
    );
    // A tailored split hem stays readable even on a tiny board pawn.
    for (final sign in [-1.0, 1.0]) {
      local.face([
        V3(sign * .025, .66, .209),
        V3(sign * .255, .66, .187),
        V3(sign * .31, .405, .195),
        V3(sign * .065, .44, .242),
      ], lining);
      MiniatureDetails.rod(
        local,
        V3(sign * .062, .447, .249),
        V3(sign * .292, .414, .204),
        .012,
        seam,
        sides: 4,
      );
    }
    if (robed) {
      MiniatureDetails.taper(
        local,
        const V3(0, .19, 0),
        .51,
        const V3(.41, 0, .285),
        const V3(.25, 0, .18),
        coat,
        sides: 10,
      );
      MiniatureDetails.taper(
        local,
        const V3(0, .195, 0),
        .065,
        const V3(.411, 0, .289),
        const V3(.391, 0, .277),
        seam,
        sides: 10,
      );
      for (final sign in [-1.0, 1.0])
        MiniatureDetails.rod(
          local,
          V3(sign * .15, .26, .273),
          V3(sign * .11, .58, .209),
          .012,
          lining,
          sides: 4,
        );
    }
    MiniatureDetails.taper(
      local,
      const V3(0, 1.125, 0),
      .125,
      const V3(.13, 0, .115),
      const V3(.125, 0, .11),
      skin,
    );
    for (final sign in [-1.0, 1.0]) {
      local.face([
        V3(sign * .265, 1.153, .178),
        V3(sign * .095, 1.202, .177),
        V3(sign * .017, 1.02, .226),
        V3(sign * .106, 1.058, .231),
      ], const Color(0xFFF6E5C5));
      MiniatureDetails.rod(
        local,
        V3(sign * .27, 1.135, .19),
        V3(sign * .13, .88, .211),
        .013,
        seam,
        sides: 4,
      );
    }
    for (final y in [.76, .865, .965])
      MiniatureDetails.jewel(local, V3(0, y, .214), .022, .026, gold);
    MiniatureDetails.taper(
      local,
      const V3(0, .585, .006),
      .075,
      const V3(.298, 0, .215),
      const V3(.298, 0, .215),
      leather,
    );
    local.box(const V3(0, .623, .22), const V3(.13, .102, .03), gold);
    local.box(const V3(0, .623, .24), const V3(.075, .054, .02), leather);
    if (armored) {
      for (final sign in [-1.0, 1.0]) {
        local.orb(
          V3(sign * .335, 1.085, 0),
          const V3(.205, .145, .22),
          gold,
          slices: 8,
          rings: 3,
        );
        local.orb(
          V3(sign * .34, 1.118, .009),
          const V3(.168, .118, .18),
          coat,
          slices: 8,
          rings: 3,
        );
        MiniatureDetails.jewel(
          local,
          V3(sign * .34, 1.106, .186),
          .035,
          .057,
          gold,
        );
      }
      local.face([
        const V3(-.23, 1.08, .202),
        const V3(.23, 1.08, .202),
        const V3(.19, .825, .231),
        const V3(0, .756, .26),
        const V3(-.19, .825, .231),
      ], MiniatureDetails.light(coat, .17));
      MiniatureDetails.jewel(local, const V3(0, .934, .27), .065, .102, gold);
    }
    // Soft cheek planes, a tiny nose and separate eye whites make the face
    // readable at portrait size without a high-poly mesh.
    local.orb(
      const V3(0, 1.489, 0),
      const V3(.342, .337, .302),
      skin,
      slices: 10,
      rings: 6,
    );
    for (final sign in [-1.0, 1.0]) {
      local.orb(
        V3(sign * .333, 1.48, -.012),
        const V3(.063, .085, .067),
        skin,
        slices: 6,
        rings: 3,
      );
      local.orb(
        V3(sign * .349, 1.473, .017),
        const V3(.028, .043, .04),
        const Color(0xFFDDA581),
        slices: 5,
        rings: 2,
      );
    }
    local.orb(
      const V3(0, 1.683, -.061),
      const V3(.36, .224, .306),
      hair,
      slices: 10,
      rings: 4,
    );
    local.orb(
      const V3(0, 1.515, -.222),
      V3(.325, female ? .35 : .21, .19),
      hair,
      slices: 8,
      rings: 4,
    );
    for (var i = 0; i < 5; i++) {
      final x = -.3 + i * .132;
      local.face([
        V3(x, 1.744, .166),
        V3(x + .145, 1.773, .156),
        V3(x + .115, 1.615 + (i.isEven ? .02 : .065), .269),
        V3(x + .034, 1.649, .26),
      ], i.isEven ? hair : hairLight);
    }
    for (final sign in [-1.0, 1.0])
      local.face([
        V3(sign * .315, 1.69, .08),
        V3(sign * .355, 1.587, .102),
        V3(sign * .296, 1.445, .127),
        V3(sign * .269, 1.653, .198),
      ], hair);
    if (female) {
      for (var i = 0; i < 3; i++)
        local.orb(
          V3(-.316 - i * .015, 1.43 - i * .145, -.203),
          V3(.115 - i * .012, .137, .118 - i * .015),
          i.isEven ? hair : hairLight,
          slices: 6,
          rings: 3,
        );
      local.box(const V3(-.35, 1.127, -.175), const V3(.12, .045, .11), seam);
    } else {
      local.face([
        const V3(-.19, 1.846, .012),
        const V3(-.04, 1.94, -.043),
        const V3(.14, 1.836, .053),
      ], hairLight);
    }
    for (final x in [-.118, .118]) {
      local.orb(
        V3(x, 1.525, .28),
        const V3(.084, .103, .032),
        const Color(0xFFFFF6DF),
        slices: 8,
        rings: 3,
      );
      local.orb(
        V3(x + .008, 1.524, .31),
        const V3(.049, .073, .018),
        const Color(0xFF4E433B),
        slices: 6,
        rings: 3,
      );
      local.orb(
        V3(x - .006, 1.555, .33),
        const V3(.017, .021, .009),
        const Color(0xFFFFFAE8),
        slices: 4,
        rings: 2,
      );
      MiniatureDetails.rod(
        local,
        V3(x - .057, 1.641, .264),
        V3(x + .054, 1.633, .275),
        .012,
        hair,
        sides: 4,
      );
    }
    for (final x in [-.212, .212])
      local.orb(
        V3(x, 1.429, .258),
        const V3(.052, .021, .012),
        const Color(0xFFE9A296),
        slices: 6,
        rings: 2,
      );
    local.orb(
      const V3(0, 1.458, .303),
      const V3(.033, .038, .037),
      const Color(0xFFE7AE88),
      slices: 6,
      rings: 3,
    );
    local.face([
      const V3(-.05, 1.393, .296),
      const V3(0, 1.383, .305),
      const V3(.05, 1.394, .296),
      const V3(0, 1.365, .301),
    ], const Color(0xFFA76958));
    if (['mage', 'archmage', 'scholar'].contains(look.jobId)) {
      MiniatureDetails.taper(
        local,
        const V3(0, 1.783, -.016),
        .045,
        const V3(.46, 0, .38),
        const V3(.46, 0, .38),
        lining,
        sides: 10,
      );
      local.pyramid(
        const V3(0, 1.808, -.026),
        .315,
        .43,
        jobColor(look.jobId),
        sides: 7,
      );
      MiniatureDetails.taper(
        local,
        const V3(0, 1.835, -.026),
        .063,
        const V3(.301, 0, .301),
        const V3(.253, 0, .253),
        gold,
        sides: 7,
      );
      MiniatureDetails.star(local, const V3(.048, 2.011, .163), .066, gold);
    }
    if (['student', 'mentor'].contains(look.jobId)) {
      local.box(const V3(0, 1.842, 0), const V3(.68, .045, .58), lining);
      local.box(
        const V3(0, 1.868, 0),
        const V3(.7, .018, .6),
        jobColor(look.jobId),
      );
      MiniatureDetails.rod(
        local,
        const V3(.05, 1.886, .05),
        const V3(.335, 1.875, .19),
        .014,
        gold,
      );
      MiniatureDetails.rod(
        local,
        const V3(.335, 1.875, .19),
        const V3(.335, 1.65, .19),
        .016,
        gold,
      );
      local.orb(
        const V3(.335, 1.652, .19),
        const V3(.032, .052, .031),
        gold,
        slices: 5,
        rings: 2,
      );
    }
    if (['artist', 'merchant', 'part_timer'].contains(look.jobId)) {
      local.orb(
        const V3(-.035, 1.818, -.01),
        const V3(.396, .135, .329),
        jobColor(look.jobId),
        slices: 10,
        rings: 3,
      );
      MiniatureDetails.taper(
        local,
        const V3(0, 1.755, 0),
        .05,
        const V3(.335, 0, .27),
        const V3(.34, 0, .278),
        lining,
      );
      local.box(
        const V3(-.045, 1.958, -.01),
        const V3(.044, .047, .038),
        lining,
      );
    }
    if (['hero', 'paladin'].contains(look.jobId)) {
      MiniatureDetails.taper(
        local,
        const V3(0, 1.773, 0),
        .072,
        const V3(.338, 0, .29),
        const V3(.341, 0, .292),
        gold,
      );
      for (final x in [-.24, 0.0, .24])
        local.pyramid(V3(x, 1.8, .15), .075, x == 0 ? .19 : .14, gold);
      MiniatureDetails.jewel(
        local,
        const V3(0, 1.837, .302),
        .045,
        .061,
        const Color(0xFF769EA4),
      );
    }
    if (look.jobId == 'doctor') {
      local.box(
        const V3(0, 1, .212),
        const V3(.062, .21, .026),
        const Color(0xFFB76363),
      );
      local.box(
        const V3(0, 1, .23),
        const V3(.18, .064, .025),
        const Color(0xFFB76363),
      );
    }
    CareerDetails.add(
      local,
      look.jobId,
      jobColor(look.jobId),
      uncovered: look.armor == 'none',
    );
    armorDetails(local, look.armor);
    weapon(local, look.weapon, V3(.43, .66, .03 - step));
    accessory(local, look.accessory);
    if (look.accessory == 'ring')
      MiniatureDetails.jewel(
        local,
        const V3(.43, .69, .16),
        .065,
        .07,
        const Color(0xFF7DBBC6),
      );
    if (look.accessory == 'pendant') {
      MiniatureDetails.rod(
        local,
        const V3(0, 1.02, .225),
        const V3(0, .87, .245),
        .015,
        gold,
      );
      MiniatureDetails.jewel(
        local,
        const V3(0, .87, .255),
        .075,
        .095,
        const Color(0xFFC9777E),
      );
    }
    if (look.accessory == 'charm')
      MiniatureDetails.star(local, const V3(-.16, 1.03, .256), .084, gold);
    final cosine = math.cos(facing), sine = math.sin(facing);
    for (final face in local.faces) {
      scene.face(
        face.points
            .map(
              (v) =>
                  pos +
                  V3(
                        v.x * cosine + v.z * sine,
                        v.y,
                        -v.x * sine + v.z * cosine,
                      ) *
                      scale,
            )
            .toList(),
        face.color,
      );
    }
  }

  static void weapon(Scene3D s, String id, V3 hand) {
    if (id == 'none') return;
    const gold = Color(0xFFDDB879);
    final legendary = ['dawnblade', 'astral_staff', 'fate_bow'].contains(id);
    final color = legendary ? gold : const Color(0xFFADCEDD);
    if (id == 'ember_spear') {
      s.box(
        hand + const V3(0, .2, 0),
        const V3(.06, 1.65, .06),
        const Color(0xFF694948),
      );
      s.pyramid(hand + const V3(0, 1.01, 0), .16, .4, const Color(0xFFFFAC6B));
      s.box(hand + const V3(0, .96, 0), const V3(.32, .06, .08), gold);
      for (final y in [-.29, .14, .75])
        MiniatureDetails.taper(
          s,
          hand + V3(0, y, 0),
          .075,
          const V3(.047, 0, .047),
          const V3(.047, 0, .047),
          gold,
          sides: 6,
        );
      MiniatureDetails.jewel(
        s,
        hand + const V3(0, 1.09, .115),
        .055,
        .15,
        const Color(0xFFFFDA9C),
      );
      for (final sign in [-1.0, 1.0])
        s.face([
          hand + V3(sign * .07, .94, .014),
          hand + V3(sign * .23, 1.12, .014),
          hand + V3(sign * .15, .89, .027),
        ], gold);
    } else if (id == 'frost_wand') {
      s.box(
        hand + const V3(0, .23, 0),
        const V3(.06, 1.1, .06),
        const Color(0xFF97BDDC),
      );
      for (final x in [-.13, 0.0, .13])
        s.orb(
          hand + V3(x, .88 - x.abs(), 0),
          const V3(.09, .23, .09),
          const Color(0xFF9DEBFF),
          slices: 4,
          rings: 3,
        );
      for (final sign in [-1.0, 1.0])
        MiniatureDetails.rod(
          s,
          hand + const V3(0, .53, 0),
          hand + V3(sign * .13, .76, 0),
          .025,
          gold,
        );
      MiniatureDetails.star(
        s,
        hand + const V3(0, .91, .093),
        .076,
        const Color(0xFFF0EDDC),
      );
      MiniatureDetails.taper(
        s,
        hand + const V3(0, .08, 0),
        .15,
        const V3(.045, 0, .045),
        const V3(.045, 0, .045),
        const Color(0xFF65758E),
        sides: 6,
      );
    } else if (id == 'thunder_hammer') {
      s.box(hand + const V3(0, .2, 0), const V3(.085, .95, .085), gold);
      s.box(
        hand + const V3(0, .75, 0),
        const V3(.5, .28, .23),
        const Color(0xFF7C88B6),
      );
      s.box(
        hand + const V3(0, .75, .13),
        const V3(.065, .22, .035),
        const Color(0xFFB9F6FF),
      );
      for (final sign in [-1.0, 1.0]) {
        s.box(hand + V3(sign * .218, .75, 0), const V3(.08, .31, .26), gold);
        for (final y in [.675, .825])
          s.box(
            hand + V3(sign * .221, y, .139),
            const V3(.068, .022, .015),
            const Color(0xFFF0DEB5),
          );
      }
      MiniatureDetails.jewel(
        s,
        hand + const V3(0, .75, .151),
        .066,
        .115,
        const Color(0xFFBFE4E0),
      );
      s.box(
        hand + const V3(0, .1, 0),
        const V3(.095, .26, .095),
        const Color(0xFF695248),
      );
    } else if (id == 'moon_blades') {
      for (final x in [0.0, -.86]) {
        final sign = x == 0 ? 1.0 : -1.0;
        s.face([
          hand + V3(x - sign * .045, -.025, .035),
          hand + V3(x + sign * .065, .36, .035),
          hand + V3(x + sign * .02, .67, .025),
          hand + V3(x + sign * .16, .43, .035),
          hand + V3(x + sign * .1, .09, .039),
        ], const Color(0xFFB6BCD9));
        s.face([
          hand + V3(x + sign * .02, .67, .025),
          hand + V3(x + sign * .19, .41, .018),
          hand + V3(x + sign * .135, .075, .015),
          hand + V3(x + sign * .1, .09, .039),
          hand + V3(x + sign * .16, .43, .035),
        ], const Color(0xFFF1DFE7));
        s.box(hand + V3(x, -.06, 0), const V3(.22, .05, .07), gold);
        s.box(
          hand + V3(x, -.16, 0),
          const V3(.066, .18, .066),
          const Color(0xFF725872),
        );
        MiniatureDetails.jewel(
          s,
          hand + V3(x, -.057, .05),
          .038,
          .051,
          const Color(0xFFADA4D0),
        );
      }
    } else if (id == 'staff' || id == 'astral_staff') {
      MiniatureDetails.rod(
        s,
        hand + const V3(0, -.4, 0),
        hand + const V3(0, .88, 0),
        .039,
        const Color(0xFF725744),
        sides: 6,
      );
      for (final y in [-.3, .14, .7])
        MiniatureDetails.taper(
          s,
          hand + V3(0, y, 0),
          .07,
          const V3(.055, 0, .055),
          const V3(.055, 0, .055),
          gold,
          sides: 6,
        );
      for (final sign in [-1.0, 1.0])
        MiniatureDetails.rod(
          s,
          hand + const V3(0, .76, 0),
          hand + V3(sign * .17, .98, 0),
          .027,
          gold,
        );
      s.orb(
        hand + const V3(0, .95, 0),
        const V3(.19, .23, .18),
        legendary ? const Color(0xFFC0A4FB) : const Color(0xFF65DCEB),
        slices: 6,
        rings: 4,
      );
    } else if (id == 'longbow' || id == 'fate_bow') {
      for (var i = 0; i < 8; i++) {
        final a = -math.pi / 2 + i * math.pi / 8, b = a + math.pi / 8;
        MiniatureDetails.rod(
          s,
          hand + V3(math.cos(a) * .22, .3 + math.sin(a) * .55, 0),
          hand + V3(math.cos(b) * .22, .3 + math.sin(b) * .55, 0),
          .038,
          legendary ? gold : const Color(0xFF729476),
          sides: 5,
        );
      }
      MiniatureDetails.rod(
        s,
        hand + const V3(0, -.25, 0),
        hand + const V3(0, .85, 0),
        .008,
        const Color(0xFFF1E7CE),
        sides: 4,
      );
      MiniatureDetails.rod(
        s,
        hand + const V3(.21, .2, 0),
        hand + const V3(.21, .41, 0),
        .046,
        const Color(0xFF705445),
        sides: 5,
      );
      MiniatureDetails.rod(
        s,
        hand + const V3(-.16, .3, .055),
        hand + const V3(.4, .3, .055),
        .012,
        gold,
        sides: 4,
      );
      s.face([
        hand + const V3(.49, .3, .056),
        hand + const V3(.38, .35, .056),
        hand + const V3(.38, .25, .056),
      ], const Color(0xFFD8DED3));
      if (legendary)
        for (final y in [-.15, .75])
          MiniatureDetails.star(s, hand + V3(.11, y, .041), .077, gold);
    } else {
      final bladeWidth = legendary ? .095 : .06;
      final blade = id == 'spellblade' ? const Color(0xFFAA9DCE) : color;
      s.face([
        hand + V3(-bladeWidth, .08, 0),
        hand + V3(-bladeWidth, .82, 0),
        hand + const V3(0, .98, .028),
        hand + const V3(0, .08, .036),
      ], MiniatureDetails.light(blade, .3));
      s.face([
        hand + const V3(0, .08, .036),
        hand + const V3(0, .98, .028),
        hand + V3(bladeWidth, .82, 0),
        hand + V3(bladeWidth, .08, 0),
      ], blade);
      s.face([
        hand + V3(-bladeWidth, .08, 0),
        hand + V3(bladeWidth, .08, 0),
        hand + V3(bladeWidth, .82, 0),
        hand + const V3(0, .98, -.025),
        hand + V3(-bladeWidth, .82, 0),
      ], MiniatureDetails.shade(blade, .12));
      if (legendary)
        MiniatureDetails.jewel(
          s,
          hand + const V3(0, .39, .038),
          .045,
          .13,
          const Color(0xFFF5E0A0),
        );
      s.box(hand + const V3(0, .05, 0), const V3(.36, .065, .09), gold);
      s.box(
        hand + const V3(0, -.08, 0),
        const V3(.075, .23, .075),
        const Color(0xFF654D43),
      );
      for (final y in [-.16, -.1, -.04])
        s.box(hand + V3(0, y, .042), const V3(.079, .012, .009), gold);
      s.orb(
        hand + const V3(0, -.225, 0),
        const V3(.065, .055, .056),
        gold,
        slices: 6,
        rings: 2,
      );
      MiniatureDetails.jewel(
        s,
        hand + const V3(0, .05, .055),
        .043,
        .051,
        id == 'spellblade' ? const Color(0xFF9A8AC4) : const Color(0xFF799C9E),
      );
    }
  }

  static void monster(
    Scene3D s,
    V3 pos,
    int kind, {
    bool boss = false,
    double scale = 1,
  }) {
    final local = Scene3D();
    if (boss) {
      CreatureModels.boss(local, kind);
    } else {
      CreatureModels.monster(local, kind);
    }
    for (final f in local.faces)
      s.face(f.points.map((v) => pos + v * scale).toList(), f.color);
  }

  static void ground(Scene3D s, int stage) {
    const colors = [
      Color(0xFFB0CFA2),
      Color(0xFFD9BD8C),
      Color(0xFF82B6BB),
      Color(0xFFB394B9),
      Color(0xFFB58D7C),
      Color(0xFF80779F),
    ];
    s.box(const V3(0, -.35, 0), const V3(8, .45, 8), colors[stage - 1]);
  }

  static void scenery(Scene3D s, int stage, {bool includeGround = true}) {
    final palettes = [
      const Color(0xFFB0CFA2),
      const Color(0xFFD9BD8C),
      const Color(0xFF82B6BB),
      const Color(0xFFB394B9),
      const Color(0xFFB58D7C),
      const Color(0xFF80779F),
    ];
    final color = palettes[stage - 1];
    if (includeGround) ground(s, stage);
    if (stage == 6) {
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        s.pyramid(
          V3(math.cos(a) * 1.15, .05, math.sin(a) * 1.15),
          .16,
          .7,
          const Color(0xFFD5BCEF),
        );
      }
      s.box(
        const V3(0, .25, 0),
        const V3(.75, .6, .75),
        const Color(0xFFCFB96C),
      );
    } else if (stage == 4) {
      s.box(const V3(0, .15, 0), const V3(2.5, .3, 2), const Color(0xFF87624E));
      for (final x in [-1.0, 1.0])
        s.box(V3(x, .8, -.4), const V3(.22, 1.5, .5), const Color(0xFFA04875));
      s.box(
        const V3(0, 1.5, -.4),
        const V3(2.4, .25, .5),
        const Color(0xFFBD9862),
      );
    } else {
      for (final x in [-.8, .8]) {
        s.box(
          V3(x, .4, 0),
          const V3(.85, .8, 1.1),
          Color.lerp(color, Colors.white, .35)!,
        );
        if (stage == 3) {
          s.box(
            V3(x, .95, -.25),
            const V3(.2, .6, .2),
            const Color(0xFFADAD94),
          );
          s.orb(
            V3(x, .55, .6),
            const V3(.2, .2, .05),
            const Color(0xFF71DFDA),
            slices: 8,
            rings: 3,
          );
        } else if (stage == 5) {
          for (final dx in [-.3, 0.0, .3])
            s.box(V3(x + dx, .93, 0), const V3(.16, .3, 1.1), color);
        } else {
          s.pyramid(
            V3(x, .8, 0),
            .72,
            .45,
            stage == 1 ? const Color(0xFF588E79) : const Color(0xFFB87357),
          );
        }
        s.box(V3(x, .3, .56), const V3(.2, .42, .035), const Color(0xFF746657));
      }
    }
  }
}

class Actor3D extends StatelessWidget {
  final EquipmentLook? look;
  final int enemy;
  final bool boss;
  final double width, height;
  const Actor3D({
    super.key,
    this.look,
    this.enemy = 0,
    this.boss = false,
    this.width = 150,
    this.height = 180,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: CustomPaint(painter: _ActorPainter(look, enemy, boss)),
  );
}

class _ActorPainter extends CustomPainter {
  final EquipmentLook? look;
  final int enemy;
  final bool boss;
  _ActorPainter(this.look, this.enemy, this.boss);
  // EquipmentLook has value equality. Reuse static portrait geometry across
  // rebuilds while bounding memory; animated board actors still use hero(walk:).
  static final Map<(EquipmentLook?, int, bool), Scene3D> _portraits = {};
  Scene3D get _mesh {
    final key = (look, look == null ? enemy : 0, look == null && boss);
    final cached = _portraits.remove(key);
    if (cached != null) {
      _portraits[key] = cached;
      return cached;
    }
    final mesh = Scene3D();
    if (look != null) {
      Models3D.hero(mesh, const V3(0, 0, 0), look!);
    } else {
      Models3D.monster(mesh, const V3(0, 0, 0), enemy, boss: boss);
    }
    if (_portraits.length >= 48) _portraits.remove(_portraits.keys.first);
    _portraits[key] = mesh;
    return mesh;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final camera = Camera3D(
      eye: V3(look == null ? 2.6 : -2.6, 2.3, 5),
      target: const V3(0, 1, 0),
      focal: 2.25,
    );
    final feet = camera.project(const V3(0, .035, 0), size);
    if (feet != null) {
      final unit = math.min(size.width, size.height);
      final shadow = Rect.fromCenter(
        center: feet,
        width: unit * (boss ? .5 : .4),
        height: unit * .075,
      );
      canvas.drawOval(
        shadow,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x455B4637), Color(0x205B4637), Color(0x005B4637)],
            stops: [0, .42, 1],
          ).createShader(shadow),
      );
    }
    _mesh.draw(canvas, size, camera);
  }

  @override
  bool shouldRepaint(covariant _ActorPainter old) =>
      old.look != look || old.enemy != enemy || old.boss != boss;
}

class Arena3D extends CustomPainter {
  final int stage;
  const Arena3D(this.stage);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = stage == 6
            ? const Color(0xFF292942)
            : const Color(0xFFEADCC7),
    );
    final s = Scene3D(), floor = Scene3D();
    Models3D.ground(floor, stage);
    Models3D.scenery(s, stage, includeGround: false);
    floor.draw(
      canvas,
      size,
      const Camera3D(eye: V3(3, 6, 9), target: V3(0, 0, 0), focal: 1.9),
    );
    s.draw(
      canvas,
      size,
      const Camera3D(eye: V3(3, 6, 9), target: V3(0, 0, 0), focal: 1.9),
    );
  }

  @override
  bool shouldRepaint(covariant Arena3D old) => old.stage != stage;
}
