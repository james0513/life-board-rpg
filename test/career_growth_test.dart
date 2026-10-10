import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/models/save_data.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/services/job_manager.dart';
import 'package:life_graybox/application/content_providers.dart';
import 'package:life_graybox/application/player_controller.dart';
import 'package:life_graybox/application/turn_controller.dart';
import 'battle_test.dart' show FixedRandom;

void main(){
  Future<String> loader(String p)=>File(p).readAsString();
  Future<JobManager> jobs()async {final j=JobManager(loadJson:loader);await j.load();return j;}
  test('morality floors at zero and survives other player updates',(){
    final p=const Player(morality:3,experience:40).apply(const StatDelta(morality:-8));
    expect(p.morality,0);
    final grown=p.apply(const StatDelta(morality:9)).copyWith(position:8,jobId:'student').gainExperience(40);
    expect(grown.morality,9);expect(grown.experience,80);
    expect(const StatDelta(morality:3).summary,'道德 +3');
  });
  test('all three final careers reachable through exactly three stages',()async{
    final j=await jobs();
    for(final path in [ ['student','engineer','president'], ['student','scholar','mentor'], ['part_timer','warrior','hero'], ['part_timer','artist','president'] ]){
      var p=const Player(stamina:100,intelligence:100,charm:100,morality:100,money:10000);
      for(var i=0;i<path.length;i++){
        p=j.changeJob(p,path[i]);expect(j.byId(p.jobId).tier,i+1);
      }
      expect(p.money,10000);
    }
    expect(j.jobs.where((v)=>v.tier==1).length,4);
    expect(j.jobs.where((v)=>v.tier==2).length,14);
    expect(j.jobs.where((v)=>v.tier==3).length,12);
  });
  test('strict scholar thresholds and grandfathered jobs do not permit invalid new promotion',()async{
    final j=await jobs();
    expect(j.evaluate(const Player(jobId:'student',intelligence:50,morality:31),'scholar').allowed,isFalse);
    expect(j.evaluate(const Player(jobId:'student',intelligence:51,morality:30),'scholar').allowed,isFalse);
    expect(j.evaluate(const Player(jobId:'student',intelligence:51,morality:31),'scholar').allowed,isTrue);
    expect(j.evaluate(const Player(jobId:'warrior',intelligence:100,charm:100,morality:100,money:10000),'president').allowed,isFalse);
    expect(()=>j.changeJob(const Player(jobId:'engineer'),'mentor'),throwsStateError);
  });
  test('job work multipliers round down and never multiply penalties',()async{
    final j=await jobs();
    for(final entry in {'unemployed':101,'student':111,'engineer':141,'hero':181}.entries){
      final p=Player(jobId:entry.key);
      final result=j.workEffects(p,const StatDelta(money:101,morality:2,stamina:-3));
      expect(result.money,entry.value);expect(result.morality,2);expect(result.stamina,-3);
      expect(j.workEffects(p,const StatDelta(money:-101)).money,-101);
    }
  });
  test('same player uses career-specific skill name and scaling in actual combat',()async{
    final j=await jobs();
    const tank=Enemy(id:'tank',name:'tank',description:'',hp:9999,attack:1,reward:0,portrait:0);
    const player=Player(intelligence:80,charm:20,morality:60);
    final engineer=BattleSession(player,tank,job:j.byId('engineer'),random:FixedRandom(99));
    final artist=BattleSession(player,tank,job:j.byId('artist'),random:FixedRandom(99));
    expect(engineer.skillName,'程式脈衝');expect(artist.skillName,'靈感共鳴');
    final e=engineer.playerAct(BattleAction.skill)!;
    final a=artist.playerAct(BattleAction.skill)!;
    expect(e.damage,j.byId('engineer').skillPower(player)+4);
    expect(e.damage,greaterThan(a.damage));
    expect(j.byId('hero').skillPower(player),92);
  });
  test('work event applies career multiplier exactly once through controller',()async{
    final c=ProviderContainer(overrides:[jsonLoaderProvider.overrideWithValue(loader)]);addTearDown(c.dispose);
    c.read(playerProvider.notifier).replace(const Player(position:2,jobId:'engineer'));
    final t=c.read(turnProvider.notifier);t.beginTurn();t.finishRoll();await t.land();
    final option=c.read(turnProvider).choiceEvent!.options.first;
    expect(t.finishChoice(option.id),isTrue);
    expect(c.read(playerProvider).money,1000+option.effects.money*140~/100);
    expect(c.read(playerProvider).morality,10+option.effects.morality);
    expect(t.finishChoice(option.id),isFalse);
  });
  test('legacy careers migrate in v1/v2, morality defaults and XP preserved',()async{
    final j=await jobs();final ids=j.jobs.map((v)=>v.id).toSet();
    for(final pair in {'junior_engineer':'engineer','senior_engineer':'mentor','police_trainee':'warrior','police_officer':'hero','entrepreneur':'president'}.entries){
      for(final v in [1,2]){
        final raw=jsonDecode(SaveData(Player(jobId:pair.key,experience:120,money:4321),DateTime.utc(2026)).encode());
        for(final key in ['gender','weaponId','inventory','clearedStages','stageWins','armorId','accessoryId']) { raw['player'].remove(key); }
    raw['schemaVersion']=v;raw['player'].remove('morality');
        if(v==1)raw['player'].remove('experience');
        final p=SaveData.decode(jsonEncode(raw),ids).player;
        expect(p.jobId,pair.value);expect(p.morality,10);expect(p.money,4321);expect(p.experience,v==1?0:120);
      }
    }
  });
  test('v3 morality roundtrip, invalid values rejected, battle reward includes morality',(){
    final raw=SaveData(const Player(morality:48,experience:222),DateTime.utc(2026)).encode();
    expect(SaveData.decode(raw,{'unemployed'}).player.morality,48);
    final corrupt=jsonDecode(raw);corrupt['player']['morality']=-1;
    expect(()=>SaveData.decode(jsonEncode(corrupt),{'unemployed'}),throwsFormatException);
    final b=BattleSession(const Player(stamina:200),const Enemy(id:'weak',name:'weak',description:'',hp:1,attack:1,reward:10,portrait:0));
    b.act(BattleAction.attack);expect(b.claim()!.morality,2);expect(b.claim(),isNull);
  });
}
