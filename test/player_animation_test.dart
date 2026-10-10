import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/presentation/components/player_component.dart';
import 'package:life_graybox/presentation/game/life_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('walking changes animation frames; landing returns to idle', () async {
    final pawn = PlayerComponent(Vector2.zero());
    expect(pawn.isWalking, isFalse);
    final done = pawn.walk([Vector2(94, 0)], (_) {});
    expect(pawn.direction, WalkDirection.right);
    expect(pawn.frameIndex, 0);
    pawn.update(.1);
    expect(pawn.frameIndex, 1);
    expect(pawn.position.x, closeTo(94 * .1 / .36, .0001));
    pawn.update(.1);
    expect(pawn.frameIndex, 2);
    pawn.update(.2);
    expect(await done, isTrue);
    expect(pawn.isWalking, isFalse);
    expect(pawn.frameIndex, 1);
    expect(pawn.position.x, 94);
  });

  test('direction changes at each orthogonal corner', () async {
    final pawn = PlayerComponent(Vector2.zero());
    final reached = <int>[];
    final done = pawn.walk([Vector2(94, 0), Vector2(94, 94),
      Vector2(0, 94), Vector2.zero()], reached.add);
    expect(pawn.direction, WalkDirection.right);
    pawn.update(.361);
    expect(pawn.direction, WalkDirection.down);
    pawn.update(.36);
    expect(pawn.direction, WalkDirection.left);
    pawn.update(.36);
    expect(pawn.direction, WalkDirection.up);
    pawn.update(.36);
    expect(await done, isTrue);
    expect(reached, [0, 1, 2, 3]);
    expect(pawn.position.length, 0);
  });

  test('long frame processes all cells once and stops precisely', () async {
    final pawn = PlayerComponent(Vector2.zero());
    final reached = <int>[];
    final done = pawn.walk([Vector2(94, 0), Vector2(188, 0)], reached.add);
    pawn.update(5);
    expect(await done, isTrue);
    expect(reached, [0, 1]);
    expect(pawn.position.x, 188);
    pawn.update(5);
    expect(reached, [0, 1]);
  });

  test('duplicate walk and reset are rejected during animation', () async {
    final pawn = PlayerComponent(Vector2.zero());
    final done = pawn.walk([Vector2(94, 0)], (_) {});
    expect(() => pawn.walk([Vector2(0, 94)], (_) {}), throwsStateError);
    expect(() => pawn.resetTo(Vector2.zero()), throwsStateError);
    pawn.update(1);
    await done;
    pawn.resetTo(Vector2(20, 30));
    expect(pawn.direction, WalkDirection.down);
    expect(pawn.position.y, 30);
  });

  test('component removal cancels pending movement future', () async {
    final pawn = PlayerComponent(Vector2.zero());
    final done = pawn.walk([Vector2(94, 0)], (_) {});
    pawn.onRemove();
    expect(await done, isFalse);
    expect(pawn.isWalking, isFalse);
  });

  test('last tile wraps to first with right-facing movement', () async {
    final game = LifeGame(initialPosition: 19);
    final pawn = PlayerComponent(game.pawnCenter(19));
    final done = pawn.walk([game.pawnCenter(0), game.pawnCenter(1)], (_) {});
    expect(pawn.direction, WalkDirection.up);
    pawn.update(.361);
    expect(pawn.direction, WalkDirection.right);
    pawn.update(.36);
    expect(await done, isTrue);
    expect(pawn.position.distanceTo(game.pawnCenter(1)), closeTo(0, .0001));
  });

  test('sprite sheet decodes, slices and renders all direction rows', () async {
    final data = await rootBundle.load('assets/images/player/hero_walk.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(
      data.offsetInBytes, data.lengthInBytes));
    final image = (await codec.getNextFrame()).image;
    final pawn = PlayerComponent(Vector2.zero(), sheet: image);
    await pawn.onLoad();
    expect(image.width, greaterThan(256));
    expect(image.width, image.height);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (final direction in WalkDirection.values) {
      pawn.direction = direction;
      pawn.render(canvas);
    }
    final picture = recorder.endRecording();
    picture.dispose();
    image.dispose();
    codec.dispose();
  });

  test('all integrated media are registered and load from the bundle', () async {
    final paths = [
      for (final id in ['unemployed', 'part_timer', 'junior_engineer', 'senior_engineer',
        'police_trainee', 'police_officer', 'entrepreneur']) 'assets/images/characters/$id.png',
      for (final id in ['town_center', 'title_city', 'event_cafe']) 'assets/images/backgrounds/$id.png',
      'assets/images/ui/dialog_frame.png',
      for (final id in ['morning', 'board', 'evening']) 'assets/audio/music/${id}_loop.wav',
      for (final id in ['click', 'step', 'dice', 'stat_up', 'event', 'promotion', 'setback', 'save'])
        'assets/audio/sfx/$id.wav',
    ];
    for (final path in paths) {
      expect((await rootBundle.load(path)).lengthInBytes, greaterThan(100), reason: path);
    }
  });
}
