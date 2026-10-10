import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/models/shop_item.dart';
import 'package:life_graybox/domain/models/save_data.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/services/shop_service.dart';
import 'package:life_graybox/domain/services/job_manager.dart';
import 'package:life_graybox/presentation/art/appearance.dart';
import 'package:life_graybox/presentation/screens/equipment_screen.dart';
import 'battle_test.dart' show FixedRandom;
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 const shop=ShopService();
 Player geared(){
   var p=const Player(money:5000);
   for(final id in ['staff','plate','ring']){p=shop.equip(shop.buy(p,id),id);}
   return p;
 }
 test('three slots coexist and unequip only the selected slot',(){
   final p=geared();expect(p.weaponId,'staff');expect(p.armorId,'plate');expect(p.accessoryId,'ring');
   expect(equipmentMagic(p),15);expect(equipmentDefense(p),7);expect(equipmentHp(p),30);
   final q=shop.equip(p,'none',slot:EquipmentSlot.armor);
   expect(q.weaponId,'staff');expect(q.armorId,'none');expect(q.accessoryId,'ring');expect(equipmentDefense(q),0);
   expect(p.stamina,10);expect(p.intelligence,10);
   expect(()=>shop.equip(p,'ring',slot:EquipmentSlot.weapon),throwsStateError);
   expect(()=>shop.equip(p,'coat'),throwsStateError);
   expect(()=>shop.buy(p,'plate'),throwsStateError);
 });
 test('armor reduces actual damage and accessories affect magic without accumulating',(){
   const e=Enemy(id:'test',name:'test',description:'',hp:999,attack:20,reward:1,portrait:0);
   final a=BattleSession(const Player(),e,random:FixedRandom(99));
   final b=BattleSession(geared(),e,random:FixedRandom(99));
   expect(b.maxHp,a.maxHp+30);
   final normal=a.playerAct(BattleAction.skill)!.damage;
   expect(b.playerAct(BattleAction.skill)!.damage,normal+15);
   expect(b.enemyAct()!.damage,a.enemyAct()!.damage-7);
   final repeat=shop.equip(shop.equip(geared(),'ring'),'ring');expect(equipmentMagic(repeat),15);
 });
 test('v6 slots roundtrip and v5 migrates with stage and weapon intact',(){
   final p=geared().copyWith(clearedStages:4,stageWins:2);
   final raw=jsonDecode(SaveData(p,DateTime.utc(2026)).encode());
   final restored=SaveData.decode(jsonEncode(raw),{'unemployed'}).player;
   expect(restored.armorId,'plate');expect(restored.accessoryId,'ring');expect(restored.stageWins,2);
   raw['player']['armorId']='ring';
   expect(()=>SaveData.decode(jsonEncode(raw),{'unemployed'}),throwsFormatException);
   raw['schemaVersion']=5;raw['player'].remove('armorId');raw['player'].remove('accessoryId');
   final old=SaveData.decode(jsonEncode(raw),{'unemployed'}).player;
   expect(old.armorId,'none');expect(old.weaponId,'staff');expect(old.clearedStages,4);
 });
 test('30 careers plus root and every career has a valid reachable predecessor',()async{
   final jobs=JobManager(loadJson:(p)=>File(p).readAsString());await jobs.load();
   expect(jobs.jobs.where((j)=>j.tier>0).length,30);
   final reachable={'unemployed'};
   for(final tier in [1,2,3]){
     for(final j in jobs.jobs.where((j)=>j.tier==tier)){
       expect(j.fromJobIds.any(reachable.contains),true);
       final p=Player(jobId:j.fromJobIds.first,stamina:200,intelligence:200,charm:200,morality:200,money:20000);
       expect(jobs.changeJob(p,j.id).jobId,j.id);reachable.add(j.id);
       expect(CareerAppearance.jobs,contains(j.id));
       if(!CareerAppearance.newJobs.contains(j.id))expect(CareerAppearance.index(j.id),isNotNull);
     }
   }
   expect(reachable.length,31);
 });
 test('both new gender atlases decode and every animation crop stays in bounds',()async{
   for(final gender in CharacterGender.values){
     final data=await rootBundle.load(CareerAppearance.assetFor(gender,jobId:'mage'));
     final codec=await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes));
     final image=(await codec.getNextFrame()).image;
     expect(image.width,greaterThan(0));
     final frames=<int>{};
     for(final id in CareerAppearance.extraJobs){
       final idx=CareerAppearance.index(id)!;frames.add(idx);frames.add(idx+3);
       expect(idx+3,lessThan(18));
     }
     expect(frames.length,18);image.dispose();codec.dispose();
   }
 });
 testWidgets('equipment switch saves once and switches active slot',(tester)async{
   var calls=0;var p=geared();
   await tester.pumpWidget(MaterialApp(home:EquipmentScreen(player:p,jobTitle:'待業',onEquip:(id,slot)async{
     calls++;p=shop.equip(p,id,slot:slot);return p;
   })));
   await tester.tap(find.text('防具：守護鎧甲'));await tester.pump();
   await tester.ensureVisible(find.text('卸下防具'));await tester.tap(find.text('卸下防具'));await tester.pump();
   expect(calls,1);expect(p.armorId,'none');expect(p.weaponId,'staff');
   expect(tester.takeException(),isNull);
 });
}
