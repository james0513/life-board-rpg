import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:life_graybox/presentation/screens/shop_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/models/save_data.dart';
import 'package:life_graybox/domain/services/shop_service.dart';
import 'battle_test.dart' show FixedRandom;
const tank = Enemy(id:'tank',name:'測試',description:'',hp:9999,attack:10,reward:1,portrait:0);
void main() {
  const shop=ShopService();
  testWidgets('failed purchase keeps balance and permits retry', (tester) async {
    var calls=0;
    await tester.pumpWidget(MaterialApp(home:ShopScreen(player:const Player(money:1000),
      onAction:(id,equip) async { calls++;throw StateError('disk full'); })));
    await tester.tap(find.text('購買').first);await tester.pumpAndSettle();
    expect(calls,1);expect(find.textContaining('金錢：\$1000'),findsOneWidget);
    expect(find.textContaining('操作未完成'),findsOneWidget);
    await tester.tap(find.text('購買').first);await tester.pumpAndSettle();expect(calls,2);
  });
  test('training charges exact price without changing source', () {
    const p=Player(money:1000);
    final next=shop.buy(p,'train_intelligence');
    expect(next.intelligence,p.intelligence+5);expect(next.money,750);expect(p.money,1000);
    expect(()=>shop.buy(const Player(money:0),'potion'),throwsStateError);
  });
  test('owned weapons equip, duplicates and inventory cap are rejected', () {
    final bought=shop.buy(const Player(money:2000),'staff');
    expect(bought.weaponId,'none');
    final equipped=shop.equip(bought,'staff');expect(equipped.weaponId,'staff');
    expect(equipped.money,1300);expect(shop.equip(equipped,'none').weaponId,'none');
    expect(()=>shop.buy(bought,'staff'),throwsStateError);
    expect(()=>shop.equip(const Player(),'sword'),throwsStateError);
    expect(()=>shop.buy(const Player(money:999,inventory:{'potion':99}),'potion'),throwsStateError);
  });
  test('gender, equipped weapon and quantities roundtrip in save v4', () {
    final p=shop.equip(shop.buy(const Player(money:2000,gender:CharacterGender.female),'staff'),'staff');
    final saved=SaveData.decode(SaveData(p,DateTime.utc(2026)).encode(),{'unemployed'}).player;
    expect(saved.gender,CharacterGender.female);expect(saved.weaponId,'staff');expect(saved.inventory,p.inventory);
    final raw=jsonDecode(SaveData(p,DateTime.utc(2026)).encode());raw['player']['inventory']['staff']=0;
    expect(()=>SaveData.decode(jsonEncode(raw),{'unemployed'}),throwsFormatException);
  });
  test('schema v3 gains starter inventory without losing progress', () {
    final raw=jsonDecode(SaveData(const Player(money:4321),DateTime.utc(2026)).encode());
    raw['schemaVersion']=3;
    for(final key in ['stageTurns','turnsPerStage','gender','weaponId','inventory','clearedStages','stageWins','armorId','accessoryId','life','story']) {raw['player'].remove(key);}
    final p=SaveData.decode(jsonEncode(raw),{'unemployed'}).player;
    expect(p.money,4321);expect(p.inventory['potion'],2);expect(p.gender,CharacterGender.male);
  });
  test('ice consumes two SP and skips exactly one counter', () {
    final b=BattleSession(const Player(),tank,random:FixedRandom(99));
    b.playerAct(BattleAction.frost);expect(b.energy,1);
    final hp=b.hp;b.enemyAct();expect(b.hp,hp);expect(b.enemyFrozen,false);
    b.act(BattleAction.attack);expect(b.hp,lessThan(hp));
  });
  test('healing clamps and burst consumes three SP', () {
    final b=BattleSession(const Player(),tank,random:FixedRandom(99));
    expect(b.canUse(BattleAction.heal),false);b.hp-=1;
    b.playerAct(BattleAction.heal);expect(b.hp,b.maxHp);expect(b.energy,1);
    final burst=BattleSession(const Player(),tank,random:FixedRandom(99));
    final normal=BattleSession(const Player(),tank,random:FixedRandom(99));
    expect(burst.playerAct(BattleAction.burst)!.damage,greaterThan(normal.playerAct(BattleAction.skill)!.damage));
    expect(burst.energy,0);expect(burst.canUse(BattleAction.burst),false);
  });
  test('equipment increases magic and gender does not change damage', () {
    BattleSession session(Player p)=>BattleSession(p,tank,random:FixedRandom(99));
    final base=session(const Player()).playerAct(BattleAction.skill)!.damage;
    final equipped=session(const Player(weaponId:'staff',inventory:{'staff':1})).playerAct(BattleAction.skill)!.damage;
    expect(equipped,base+10);
    expect(session(const Player(gender:CharacterGender.female)).playerAct(BattleAction.skill)!.damage,base);
  });
  test('consumables carry into next battle instead of refilling', () {
    final b=BattleSession(const Player(inventory:{'potion':1,'ether':0}),tank,random:FixedRandom(0));
    b.hp-=20;b.act(BattleAction.potion);b.act(BattleAction.flee);
    expect(b.status,BattleStatus.escaped);
    final next=BattleSession(b.player.copyWith(inventory:b.remainingInventory),tank);
    expect(next.potions,0);expect(next.ethers,0);
  });
}
