import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/models/save_data.dart';
import 'package:life_graybox/domain/services/job_manager.dart';
import 'package:life_graybox/presentation/art/appearance.dart';
import 'package:life_graybox/presentation/three_d/models_3d.dart';
import 'package:life_graybox/presentation/three_d/scene_3d.dart';
import 'package:life_graybox/presentation/widgets/creator_credit.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('twelve new careers enforce thresholds and roundtrip save with belongings',()async{
   final manager=JobManager(loadJson:(path)async=>File(path).readAsStringSync());
   await manager.load();
   final valid=manager.jobs.map((j)=>j.id).toSet();
   for(final id in CareerAppearance.newJobs){
     final job=manager.byId(id);
     Player candidate({Stat? below}){
       final stats={for(final stat in Stat.values)stat:10000};
       for(final r in job.requirements){stats[r.stat]=r.value-(below==r.stat?1:0);}
       return Player(jobId:job.fromJobIds.first,stamina:stats[Stat.stamina]!,
         intelligence:stats[Stat.intelligence]!,charm:stats[Stat.charm]!,morality:stats[Stat.morality]!,money:stats[Stat.money]!,
         clearedStages:3,weaponId:'staff',inventory:const {'staff':1,'potion':2});
     }
     final base=candidate();
     expect(manager.evaluate(base,id).allowed,isTrue);
     for(final r in job.requirements){expect(manager.evaluate(candidate(below:r.stat),id).allowed,isFalse);}
     final promoted=manager.changeJob(base,id);
     final restored=SaveData.decode(SaveData(promoted,DateTime.utc(2026)).encode(),valid).player;
     expect(restored.jobId,id);expect(restored.weaponId,'staff');expect(restored.clearedStages,3);expect(restored.money,base.money);
     expect(job.skillPower(restored),greaterThan(0));
     expect(job.workPercent,job.tier==2?140:180);
   }
 });
 test('eighteen monsters and six bosses have distinct finite renderable geometry',(){
   final monsters=jsonDecode(File('assets/data/enemies.json').readAsStringSync()) as List;
   final stages=jsonDecode(File('assets/data/stages.json').readAsStringSync()) as List;
   final signatures=<String>{};
   final all=<({int index,bool boss})>[
     for(final raw in monsters)(index:Enemy.fromJson(Map<String,dynamic>.from(raw)).portrait,boss:false),
     for(final raw in stages)(index:(raw['id'] as int)-1,boss:true),
   ];
   expect(all.length,24);
   for(final enemy in all){
     final scene=Scene3D();Models3D.monster(scene,const V3(0,0,0),enemy.index,boss:enemy.boss);
     expect(scene.faces,isNotEmpty);
     for(final face in scene.faces)for(final p in face.points)expect(p.x.isFinite&&p.y.isFinite&&p.z.isFinite,isTrue);
     signatures.add(scene.faces.map((f)=>'${f.color}:${f.points.map((p)=>'${p.x},${p.y},${p.z}').join(';')}').join('|'));
     final recorder=ui.PictureRecorder();scene.draw(Canvas(recorder),const Size(220,220),const Camera3D(eye:V3(3,2.5,5),target:V3(0,1,0),focal:2));
     recorder.endRecording().dispose();
   }
   expect(signatures.length,24);
 });
 test('monster tiers keep high-rank enemies out of the initial pool',(){
   final raw=jsonDecode(File('assets/data/enemies.json').readAsStringSync()) as List;
   final enemies=raw.map((r)=>Enemy.fromJson(Map<String,dynamic>.from(r))).toList();
   expect(enemies.map((e)=>e.portrait).toSet(),List.generate(18,(i)=>i).toSet());
   expect(enemies.singleWhere((e)=>e.id=='astral_sentinel').minTier,3);
   expect(enemies.where((e)=>e.minTier==0).every((e)=>e.hp<=100),isTrue);
 });
 testWidgets('creator credit names TSENGSHOUHSIEN exactly', (tester)async{
   await tester.pumpWidget(const MaterialApp(home:Scaffold(body:CreatorCredit())));
   expect(find.text('遊戲創作者 TSENGSHOUHSIEN\n© 2026 TSENGSHOUHSIEN. All rights reserved.'),findsOneWidget);
   expect(tester.takeException(),isNull);
 });
}
