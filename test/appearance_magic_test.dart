import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/presentation/art/appearance.dart';
import 'package:life_graybox/presentation/components/player_component.dart';
import 'package:life_graybox/presentation/battle/battle_screen.dart';
import 'package:life_graybox/presentation/battle/spell_effect.dart';
import 'battle_test.dart' show FixedRandom;
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all ten career pairs map inside the atlas and preserve default fallback',(){
    expect(CareerAppearance.jobs.length,31);
    final indices=CareerAppearance.baseJobs.map((j)=>CareerAppearance.index(j)!).toList();
    expect(indices.toSet().length,10);
    for(final i in indices){expect(i,greaterThanOrEqualTo(0));expect(i+5,lessThan(20));}
    expect(CareerAppearance.index('unemployed'),0);
  });
  test('career sheet decodes and swapping profession renders every form and reset',()async{
    final data=await rootBundle.load(CareerAppearance.asset);
    final codec=await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes));
    final img=(await codec.getNextFrame()).image;
    final pawn=PlayerComponent(Vector2.zero());
    final recorder=ui.PictureRecorder();final canvas=ui.Canvas(recorder);
    for(final id in CareerAppearance.baseJobs){
      pawn.setCareer(img,id);expect(pawn.jobId,id);pawn.render(canvas);
      final done=pawn.walk([Vector2(pawn.position.x+20,pawn.position.y)],(_){});
      pawn.update(.1);pawn.render(canvas);pawn.update(1);await done;
    }
    pawn.setCareer(img,'unemployed');expect(pawn.jobId,'unemployed');
    recorder.endRecording().dispose();img.dispose();codec.dispose();
  });
  test('enemy catalog has eighteen distinct portraits and tier-appropriate pools',()async{
    final raw=jsonDecode(await File('assets/data/enemies.json').readAsString()) as List;
    final enemies=raw.map((e)=>Enemy.fromJson(Map<String,dynamic>.from(e))).toList();
    expect(enemies.length,18);expect(enemies.map((e)=>e.id).toSet().length,18);
    expect(enemies.map((e)=>e.portrait).toSet(),List.generate(18,(i)=>i).toSet());
    expect(enemies.where((e)=>e.minTier<=0).length,10);
    expect(enemies.where((e)=>e.minTier<=1).length,14);
    expect(enemies.where((e)=>e.minTier<=2).length,17);
    expect((await rootBundle.load('assets/images/battle/monsters_extra.png')).lengthInBytes,greaterThan(100));
  });
  test('spell styles draw every phase without invalid paint values',(){
    final recorder=ui.PictureRecorder();final canvas=ui.Canvas(recorder);
    for(final id in ['student','engineer','artist','scholar','warrior','hero','mentor']){
      for(final t in [0.0,.15,.25,.4,.59,.6,.8,1.0]){
        SpellEffect(progress:t,jobId:id).paint(canvas,const Size(800,300));
      }
    }
    recorder.endRecording().dispose();
    expect(spellFor('engineer'),SpellVisual.lightning);
    expect(spellFor('scholar'),SpellVisual.runes);
    expect(spellFor('hero'),SpellVisual.blade);
  });
  testWidgets('magic charges before damage and commits at projectile contact only once',(tester)async{
    final b=BattleSession(const Player(),const Enemy(id:'tank',name:'測試怪',description:'',
      hp:999,attack:1,reward:0,portrait:0),random:FixedRandom(99));
    await tester.pumpWidget(MaterialApp(home:BattleScreen(session:b,onSound:(_){},onSettle:()async=>true)));
    await tester.tap(find.text('技能／魔法'));await tester.pumpAndSettle();
    await tester.tap(find.text('靈光斬'));await tester.pump();
    await tester.pump(const Duration(milliseconds:350));
    expect(b.enemyHp,999);expect(b.energy,3);
    await tester.pump(const Duration(milliseconds:340));
    expect(b.enemyHp,lessThan(999));expect(b.energy,2);expect(b.round,1);
    final hp=b.enemyHp;
    await tester.pump(const Duration(milliseconds:450));
    await tester.pump(const Duration(milliseconds:200));
    await tester.pump(const Duration(milliseconds:850));
    await tester.pumpAndSettle();
    expect(b.enemyHp,hp);expect(b.round,1);expect(tester.takeException(),isNull);
  });
}
