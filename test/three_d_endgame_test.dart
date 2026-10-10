import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/models/save_data.dart';
import 'package:life_graybox/domain/models/shop_item.dart';
import 'package:life_graybox/domain/services/shop_service.dart';
import 'package:life_graybox/presentation/art/appearance.dart';
import 'package:life_graybox/presentation/art/equipment_layers.dart';
import 'package:life_graybox/presentation/game/life_game.dart';
import 'package:life_graybox/presentation/three_d/scene_3d.dart';
import 'package:life_graybox/presentation/three_d/models_3d.dart';
import 'package:life_graybox/presentation/screens/victory_screen.dart';

import 'battle_test.dart' show FixedRandom;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('perspective shrinks far objects and rejects points behind camera', () {
    const camera = Camera3D(eye: V3(0, 0, 10));
    const size = Size(400, 400);
    final near = camera.project(const V3(1, 0, 5), size)!;
    final far = camera.project(const V3(1, 0, 0), size)!;
    expect(near.dx - 200, closeTo(2 * (far.dx - 200), .0001));
    expect(camera.project(const V3(0, 0, 11), size), isNull);
  });
  test('twenty board cells retain equal world steps including wrap', () {
    final cells = LifeGame.centers
        .map((p) => LifeGame.worldFromPoint(p.x, p.y))
        .toList();
    expect(cells.length, 20);
    for (var i = 0; i < cells.length; i++) {
      final delta = cells[(i + 1) % cells.length] - cells[i];
      expect(delta.dot(delta), closeTo(1, .00001));
    }
    final game = LifeGame(initialPosition: 0);
    game.changeZoom(100);
    expect(game.zoom, 1.35);
    game.changeZoom(-100);
    expect(game.zoom, .75);
    game.orbit(1);
    game.resetCamera();
    expect(game.yaw, .72);
  });
  test('all career and equipment meshes render with finite geometry', () {
    final scene = Scene3D();
    for (final gender in CharacterGender.values) {
      for (final job in CareerAppearance.jobs) {
        Models3D.hero(
          scene,
          const V3(0, 0, 0),
          EquipmentLook(jobId: job, gender: gender),
        );
      }
    }
    for (final item in shopCatalog.where((i) => i.isEquipment)) {
      Models3D.hero(
        scene,
        const V3(0, 0, 0),
        EquipmentLook(
          weapon: item.kind == ShopKind.weapon ? item.id : 'none',
          armor: item.kind == ShopKind.armor ? item.id : 'none',
          accessory: item.kind == ShopKind.accessory ? item.id : 'none',
        ),
      );
    }
    for (var stage = 1; stage <= 6; stage++) {
      Models3D.monster(scene, const V3(0, 0, 0), stage - 1, boss: true);
      Models3D.scenery(scene, stage);
    }
    expect(scene.faces, isNotEmpty);
    for (final face in scene.faces) {
      expect(face.points.length, greaterThanOrEqualTo(3));
      for (final p in face.points) {
        expect(p.x.isFinite && p.y.isFinite && p.z.isFinite, isTrue);
      }
    }
    final recorder = ui.PictureRecorder();
    scene.draw(
      ui.Canvas(recorder),
      const Size(400, 400),
      const Camera3D(eye: V3(4, 5, 9)),
    );
    recorder.endRecording().dispose();
  });
  test(
    'terminal weapons require stage six and survive equipment save roundtrip',
    () {
      const shop = ShopService();
      for (final id in ['dawnblade', 'astral_staff', 'fate_bow']) {
        final job = {
          'dawnblade': 'warrior',
          'astral_staff': 'mage',
          'fate_bow': 'ranger',
        }[id]!;
        expect(
          () =>
              shop.buy(Player(jobId: job, money: 10000, clearedStages: 4), id),
          throwsStateError,
        );
        final bought = shop.buy(
          Player(jobId: job, money: 10000, clearedStages: 5),
          id,
        );
        expect(bought.money, 10000 - shopById(id).price);
        expect(bought.weaponId, 'none');
        final equipped = shop.equip(bought, id);
        final restored = SaveData.decode(
          SaveData(equipped, DateTime.utc(2026)).encode(),
          {job},
        ).player;
        expect(restored.weaponId, id);
        expect(restored.clearedStages, 5);
        expect(() => shop.buy(equipped, id), throwsStateError);
      }
    },
  );
  test('terminal damage bonus only affects final boss, including magic', () {
    Enemy enemy(int stage) => Enemy(
      id: 'target',
      name: 'target',
      description: '',
      hp: 9999,
      attack: 1,
      reward: 1,
      portrait: 0,
      bossStage: stage,
    );
    for (final id in ['dawnblade', 'astral_staff', 'fate_bow']) {
      final job = {
        'dawnblade': 'warrior',
        'astral_staff': 'mage',
        'fate_bow': 'ranger',
      }[id]!;
      final player = Player(
        jobId: job,
        weaponId: id,
        inventory: {id: 1},
        clearedStages: 5,
      );
      for (final action in [
        BattleAction.attack,
        BattleAction.skill,
        BattleAction.frost,
        BattleAction.burst,
      ]) {
        int damage(int stage) => BattleSession(
          player,
          enemy(stage),
          random: FixedRandom(99),
        ).playerAct(action)!.damage;
        expect(damage(5), damage(0));
        expect(
          damage(6),
          damage(0) * (100 + shopById(id).finalBossPercent) ~/ 100,
        );
      }
    }
  });
  testWidgets('ending returns to board without awarding rewards again', (
    tester,
  ) async {
    const player = Player(clearedStages: 6, money: 4321);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const VictoryScreen(player: player, jobTitle: '學生'),
                ),
              ),
              child: const Text('觀看結局'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('觀看結局'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('恭喜破關！'), findsOneWidget);
    await tester.ensureVisible(find.text('繼續自由冒險'));
    await tester.tap(find.text('繼續自由冒險'));
    await tester.pumpAndSettle();
    expect(find.text('觀看結局'), findsOneWidget);
    expect(player.money, 4321);
    expect(player.clearedStages, 6);
  });
}
