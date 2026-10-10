import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/models/save_data.dart';
import 'package:life_graybox/domain/services/tile_event_manager.dart';
import 'package:life_graybox/application/content_providers.dart';
import 'package:life_graybox/application/player_controller.dart';
import 'package:life_graybox/application/turn_controller.dart';
import 'package:life_graybox/presentation/battle/battle_screen.dart';
import 'battle_test.dart' show FixedRandom;

const enemy = Enemy(id:'test', name:'測試怪', description:'', hp:200, attack:10,
  reward:220, portrait:0, experience:40);
void main() {
  test('player impact precedes counter and blocks repeated actions', () {
    final b = BattleSession(const Player(),enemy,random:FixedRandom(99));
    final hit = b.playerAct(BattleAction.attack)!;
    expect(hit.targetsPlayer,isFalse);
    expect(hit.damage,greaterThan(0));
    expect(b.hp,b.maxHp);
    expect(b.playerAct(BattleAction.attack),isNull);
    final counter = b.enemyAct()!;
    expect(b.hp,b.maxHp-counter.damage);
    expect(b.enemyAct(),isNull);
    expect(b.round,1);
  });
  test('enemy SP telegraphs, pays for heavy strike then recovers', () {
    final b = BattleSession(const Player(stamina:100),enemy,random:FixedRandom(99));
    b.act(BattleAction.defend); expect(b.enemySp,3);
    expect(b.intent,'蓄力重擊');
    b.act(BattleAction.defend); expect(b.enemySp,0);
    b.act(BattleAction.defend); expect(b.enemySp,1);
  });
  test('full-health item use consumes neither item nor turn', () {
    final b = BattleSession(const Player(),enemy);
    expect(b.playerAct(BattleAction.potion),isNull);
    expect(b.playerAct(BattleAction.ether),isNull);
    expect(b.round,0); expect(b.potions,2); expect(b.ethers,1);
  });
  test('items recover actual HP/SP once, deplete stock and permit retaliation', () {
    final b = BattleSession(const Player(),enemy,random:FixedRandom(99));
    b.act(BattleAction.skill);
    final before = b.hp;
    final potion = b.playerAct(BattleAction.potion)!;
    expect(potion.healing,b.maxHp-before);
    expect(b.potions,1); expect(b.awaitingEnemy,isTrue);
    b.enemyAct();
    final ether = b.playerAct(BattleAction.ether)!;
    expect(ether.spRecovered,1); expect(b.energy,3); expect(b.ethers,0);
    b.enemyAct(); b.act(BattleAction.skill);
    expect(b.playerAct(BattleAction.ether),isNull);
  });
  test('experience survives moves, stat updates, jobs and v2 save roundtrip', () {
    final p = const Player(experience:90).gainExperience(40)
      .apply(const StatDelta(money:20)).copyWith(position:3,jobId:'part_timer');
    expect(p.level,2); expect(p.experience,130);
    final result = SaveData.decode(SaveData(p,DateTime.utc(2026)).encode(),{'part_timer'}).player;
    expect(result.experience,130); expect(result.level,2);
  });
  test('v1 migrates without losing attributes and rejects invalid v2 XP', () {
    final raw = jsonDecode(SaveData(const Player(position:8,money:1200),DateTime.utc(2026)).encode());
    for(final key in ['gender','weaponId','inventory','clearedStages','stageWins','armorId','accessoryId']) { raw['player'].remove(key); }
    raw['schemaVersion']=1; raw['player'].remove('experience'); raw['player'].remove('morality');
    final p = SaveData.decode(jsonEncode(raw),{'unemployed'}).player;
    expect(p.experience,0); expect(p.position,8); expect(p.money,1200);
    for(final key in ['gender','weaponId','inventory','clearedStages','stageWins','armorId','accessoryId']) { raw['player'].remove(key); }
    raw['schemaVersion']=2; raw['player']['experience']=-1;
    expect(()=>SaveData.decode(jsonEncode(raw),{'unemployed'}),throwsFormatException);
  });
  test('XP and money settlement is idempotent', () async {
    final c=ProviderContainer(); addTearDown(c.dispose);
    c.read(playerProvider.notifier).moveTo(3);
    final t=c.read(turnProvider.notifier);
    t.beginTurn();t.finishRoll();await t.land();
    t.finishBattle(const StatDelta(money:220),'勝利',experience:40);
    t.finishBattle(const StatDelta(money:220),'勝利',experience:40);
    expect(c.read(playerProvider).money,1220);
    expect(c.read(playerProvider).experience,40);
  });
  test('event choice can enter combat; rejecting challenge remains idle', () async {
    final raw = jsonDecode(await File('assets/data/tile_events.json').readAsString());
    final challenge = (raw['events'] as List).firstWhere((e)=>e['id']=='friendly_challenge');
    final filtered = {'schemaVersion':1,'events':[challenge,...(raw['events'] as List).where((e)=>e['kind']!='luck')]};
    for(final choice in ['A','B']) {
      final c=ProviderContainer(overrides:[tileEventManagerProvider.overrideWithValue(
        TileEventManager(loadJson:(_) async=>jsonEncode(filtered)))]);
      try {
        final t=c.read(turnProvider.notifier); t.beginTurn();t.finishRoll();await t.land();
        expect(t.finishChoice(choice),isTrue);
        expect(c.read(turnProvider).battleChoice,choice=='A');
        expect(c.read(turnProvider).phase,choice=='A'?TurnPhase.resolving:TurnPhase.idle);
      } finally {c.dispose();}
    }
  });
  testWidgets('four core commands, canceled item menu does not spend a turn', (tester) async {
    final b=BattleSession(const Player(),enemy);
    await tester.pumpWidget(MaterialApp(home:BattleScreen(session:b,onSound:(_){},onSettle:()async=>true)));
    expect(find.text('普通攻擊'),findsOneWidget);
    expect(find.text('技能／魔法'),findsOneWidget);
    expect(find.text('道具'),findsOneWidget);
    expect(find.text('逃跑 65%'),findsOneWidget);
    await tester.tap(find.text('道具'));await tester.pumpAndSettle();
    await tester.tap(find.text('取消，不消耗回合'));await tester.pumpAndSettle();
    expect(b.round,0); expect(b.potions,2);
    expect(tester.takeException(),isNull);
  });
  testWidgets('hit frame shows damage, locks input and delays enemy damage', (tester) async {
    final b=BattleSession(const Player(),enemy,random:FixedRandom(99));
    await tester.pumpWidget(MaterialApp(home:BattleScreen(session:b,onSound:(_){},onSettle:()async=>true)));
    await tester.tap(find.text('普通攻擊'));await tester.pump();
    await tester.pump(const Duration(milliseconds:220));
    expect(b.enemyHp,lessThan(enemy.hp));expect(b.hp,b.maxHp);
    expect(find.textContaining(RegExp(r'^-\d+$')),findsOneWidget);
    await tester.tap(find.text('普通攻擊')); // disabled during animation
    expect(b.round,1);
    await tester.pump(const Duration(milliseconds:650));
    await tester.pump(const Duration(milliseconds:200));
    await tester.pump(const Duration(milliseconds:220));
    expect(b.hp,lessThan(b.maxHp));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });
  testWidgets('failed settlement stays on route and successful retry returns to map', (tester) async {
    final b=BattleSession(const Player(stamina:200),
      const Enemy(id:'tiny',name:'練習怪',description:'',hp:1,attack:1,reward:20,portrait:0),
      random:FixedRandom(0));
    b.act(BattleAction.attack);
    var attempts=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(context)=>
      TextButton(onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>
        BattleScreen(session:b,onSound:(_){},onSettle:()async {attempts++;return attempts>1;}))),
        child:const Text('進入挑戰'))))));
    await tester.tap(find.text('進入挑戰'));await tester.pumpAndSettle();
    await tester.tap(find.text('結算並返回大地圖'));await tester.pumpAndSettle();
    expect(find.text('重試存檔並返回'),findsOneWidget);
    expect(find.byType(BattleScreen),findsOneWidget);
    await tester.tap(find.text('重試存檔並返回'));await tester.pumpAndSettle();
    expect(find.byType(BattleScreen),findsNothing);
    expect(find.text('進入挑戰'),findsOneWidget);
    expect(attempts,2);
    expect(tester.takeException(),isNull);
  });

}
