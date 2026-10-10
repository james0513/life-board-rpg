import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scene_3d.dart';

/// Low-sided, solid details shared by the hand-painted tabletop miniatures.
/// All dimensions are local model units; these helpers have no game state.
class MiniatureDetails {
  static const brass = Color(0xFFCFA765);
  static const cream = Color(0xFFF5E6C8);
  static const ink = Color(0xFF3D3942);

  static Color light(Color c, [double amount = .18]) =>
      Color.lerp(c, cream, amount)!;
  static Color shade(Color c, [double amount = .22]) =>
      Color.lerp(c, ink, amount)!;

  /// An elliptical, bevel-like tapered solid, with flat caps.
  static void taper(
    Scene3D s,
    V3 base,
    double height,
    V3 lower,
    V3 upper,
    Color color, {
    int sides = 8,
  }) {
    final bottom = <V3>[];
    final top = <V3>[];
    for (var i = 0; i < sides; i++) {
      final a = (i + .5) * math.pi * 2 / sides;
      bottom.add(base + V3(math.cos(a) * lower.x, 0, math.sin(a) * lower.z));
      top.add(base + V3(math.cos(a) * upper.x, height, math.sin(a) * upper.z));
    }
    for (var i = 0; i < sides; i++) {
      final next = (i + 1) % sides;
      s.face([bottom[i], bottom[next], top[next], top[i]], color);
    }
    s.face(bottom.reversed.toList(), shade(color, .1));
    s.face(top, light(color, .08));
  }

  /// A solid rod between arbitrary points, used for seams, straps and shafts.
  static void rod(
    Scene3D s,
    V3 a,
    V3 b,
    double radius,
    Color color, {
    int sides = 5,
  }) {
    final direction = (b - a).unit;
    final seed = direction.y.abs() > .9 ? const V3(1, 0, 0) : const V3(0, 1, 0);
    final across = direction.cross(seed).unit;
    final up = direction.cross(across).unit;
    final first = <V3>[];
    final last = <V3>[];
    for (var i = 0; i < sides; i++) {
      final angle = i * math.pi * 2 / sides;
      final offset = (across * math.cos(angle) + up * math.sin(angle)) * radius;
      first.add(a + offset);
      last.add(b + offset);
    }
    for (var i = 0; i < sides; i++) {
      final n = (i + 1) % sides;
      s.face([first[i], first[n], last[n], last[i]], color);
    }
    s.face(first.reversed.toList(), color);
    s.face(last, light(color, .12));
  }

  /// Front-facing enamel inset with separate light and dark facets.
  static void jewel(Scene3D s, V3 p, double width, double height, Color color) {
    final top = p + V3(0, height, 0);
    final right = p + V3(width, 0, 0);
    final bottom = p + V3(0, -height, 0);
    final left = p + V3(-width, 0, 0);
    final center = p + V3(0, 0, width * .36);
    s.face([top, right, center], light(color, .35));
    s.face([right, bottom, center], color);
    s.face([bottom, left, center], shade(color, .15));
    s.face([left, top, center], light(color, .14));
  }

  static void stitch(Scene3D s, V3 a, V3 b, Color color, {int count = 4}) {
    for (var i = 0; i < count; i++) {
      final p = a + (b - a) * ((i + .5) / count);
      s.face([
        p + const V3(-.017, -.009, 0),
        p + const V3(.017, -.001, 0),
        p + const V3(.017, .009, 0),
        p + const V3(-.017, .001, 0),
      ], color);
    }
  }

  static void star(Scene3D s, V3 p, double radius, Color color) {
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      s.face([
        p + V3(math.cos(a) * radius, math.sin(a) * radius, 0),
        p +
            V3(
              math.cos(a + math.pi / 4) * radius * .26,
              math.sin(a + math.pi / 4) * radius * .26,
              .012,
            ),
        p + const V3(0, 0, .02),
        p +
            V3(
              math.cos(a - math.pi / 4) * radius * .26,
              math.sin(a - math.pi / 4) * radius * .26,
              .012,
            ),
      ], color);
    }
  }
}
