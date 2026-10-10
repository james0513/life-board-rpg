import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/models/board_tile.dart';
import 'package:life_graybox/application/turn_controller.dart';
import 'package:life_graybox/application/player_controller.dart';

class FixedRandom implements Random {
  FixedRandom(this.value);
  final int value;
  @override int nextInt(int max) => value % max;
  @override double nextDouble() => .5;
  @override bool nextBool() => false;
}
const enemy = Enemy(id: 'test', name: '測試怪', description: '', hp: 65,
  attack: 10, reward: 220, portrait: 0);
void main() {
  test('eighteen enemy definitions and four combat cells', () {
    final raw = jsonDecode(File('assets/data/enemies.json').readAsStringSync()) as List;
    expect(raw.map((e) => Enemy.fromJson(Map<String, dynamic>.from(e))).length, 18);
    expect(boardTiles.where((t) => t.kind == TileKind.battle).map((t) => t.index), [3,8,13,18]);
    expect(boardTiles.length, 20);
  });
  test('victory reward can be claimed only once; enemy cannot attack after defeat', () {
    final b = BattleSession(const Player(stamina: 200), enemy, random: FixedRandom(0));
    b.act(BattleAction.attack);
    expect(b.status, BattleStatus.won);
    expect(b.hp, b.maxHp);
    expect(b.claim()!.money, 220);
    expect(b.claim(), isNull);
    b.act(BattleAction.attack);
    expect(b.round, 1);
  });
  test('no claim while battle active', () {
    expect(BattleSession(const Player(), enemy).claim(), isNull);
  });
  test('skill consumes focus, zero focus action is ignored, defense restores it', () {
    const tank = Enemy(id: 'tank', name: 'tank', description: '', hp: 999,
      attack: 1, reward: 0, portrait: 0);
    final b = BattleSession(const Player(), tank, random: FixedRandom(99));
    for (var i = 0; i < 3; i++) { b.act(BattleAction.skill); }
    expect(b.energy, 0);
    b.act(BattleAction.skill); expect(b.round, 3);
    b.act(BattleAction.defend); expect(b.energy, 1);
  });
  test('defense reduces counter damage', () {
    final b = BattleSession(const Player(), enemy, random: FixedRandom(0));
    b.act(BattleAction.defend);
    expect(b.maxHp-b.hp, 3);
  });
  test('successful flee has no cost; failed flee allows retaliation', () {
    final success = BattleSession(const Player(), enemy, random: FixedRandom(0));
    success.act(BattleAction.flee);
    expect(success.status, BattleStatus.escaped);
    expect(success.claim()!.money, 0);
    final fail = BattleSession(const Player(), enemy, random: FixedRandom(99));
    fail.act(BattleAction.flee);
    expect(fail.active, isTrue);
    expect(fail.hp, lessThan(fail.maxHp));
  });
  test('defeat fee cannot exceed player money', () {
    const strong = Enemy(id: 'strong', name: 'strong', description: '', hp: 999,
      attack: 999, reward: 0, portrait: 0);
    final b = BattleSession(const Player(money: 30), strong, random: FixedRandom(99));
    b.act(BattleAction.attack);
    expect(b.status, BattleStatus.lost);
    expect(b.hp, 0);
    expect(b.claim()!.money, -30);
  });
  test('combat locks turn and settlement cannot apply twice', () async {
    final c = ProviderContainer(); addTearDown(c.dispose);
    c.read(playerProvider.notifier).moveTo(3);
    final t = c.read(turnProvider.notifier);
    t.beginTurn(); t.finishRoll(); await t.land();
    expect(c.read(turnProvider).battleChoice, isTrue);
    expect(t.beginTurn(), isNull);
    t.finishBattle(const StatDelta(money: 220), '勝利');
    t.finishBattle(const StatDelta(money: 220), '勝利');
    expect(c.read(playerProvider).money, 1220);
    expect(c.read(turnProvider).phase, TurnPhase.idle);
  });
}
