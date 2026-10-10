// Independent domain review scenarios; no Flutter or browser claims.
// Run from project root: dart tools/verify_review_scenarios.dart
import 'dart:convert';
import 'dart:io';
import '../lib/domain/models/player.dart';
import '../lib/domain/models/life_progress.dart';
import '../lib/domain/models/save_data.dart';
import '../lib/domain/models/acceptance_scenarios.dart';
import '../lib/domain/services/story_service.dart';
import '../lib/domain/services/life_service.dart';
void main() {
 final rawJobs=jsonDecode(File('assets/data/jobs.json').readAsStringSync())['jobs'] as List;
 final jobs=rawJobs.map((j)=>j['id'] as String).toSet();
 const service=StoryService(); const life=LifeService(); var checks=0;
 void check(bool b,String s) {checks++;if(!b)throw StateError(s);}
 Player roundtrip(Player p) { final saved=SaveData(p,DateTime.utc(2026)); final read=SaveData.decode(saved.encode(),jobs); check(saved.encode()==read.encode(),'roundtrip');return read.player; }
 for(final id in acceptanceScenarioLabels.keys)roundtrip(acceptanceScenario(id));
 var p=const Player(money:100000);
 p=service.chooseStory(p,'lantern','a',expectedStep:0);
 check(p.life.turns==1&&p.story.lastSettledTurn==1&&p.story.storySteps['lantern']==1,'story step');
 check(p.story.storyChoices['lantern_0']=='a','branch retained');
 check(service.availableStories(p).first.description.contains('親自幫忙'),'next chapter prior choice');
 var rejected=false;try{service.chooseStory(p,'lantern','a',expectedStep:0);}catch(_){rejected=true;}check(rejected,'stale');
 for(var i=0;i<3;i++){p=service.perform(p,'talk',npcId:'cen_yu');}
 while(p.life.age<22)p=service.settleSeason(life.lifeAction(p,'rest'));
 while(p.story.affinities['cen_yu']!<70)p=service.perform(p,'date',npcId:'cen_yu');
 p=service.perform(p,'commit',npcId:'cen_yu');
 p=service.settleSeason(life.lifeAction(p,'buyHome'));
 p=service.perform(p,'propose',npcId:'cen_yu');
 while(p.life.age<25)p=service.settleSeason(life.lifeAction(p,'rest'));
 final beforeChild=p.money;
 p=service.perform(p,'child');
 check(p.story.children==1&&p.money==beforeChild-800-25,'child exact payment');
 final settled=p.money; p=service.settleSeason(p); check(p.money==settled,'settle idempotent');
 p=roundtrip(p);
 for(var gen=1;gen<=36;gen++) {
   while(p.life.age<60){p=service.settleSeason(life.lifeAction(p,'rest'));p=roundtrip(p);}
   final e=gen==1?'family':'peaceful';
   p=service.concludeLife(p,e); final record=p.story.history.last;
   check(identical(p,service.concludeLife(p,e)),'conclude idempotent');
   p=service.settleSeason(life.lifeAction(p,'rest'));
   check(identical(record,p.story.history.last),'ending frozen');
   p=roundtrip(p);
   p=service.reincarnate(p);check(p.life.generation==gen+1,'generation increment');
   check(p.story.history.length==(gen>30?30:gen),'history limit');
   check(p.story.currentEndingId==null&&p.story.children==0&&p.story.lastSettledTurn==0,'story reset');
   p=roundtrip(p);
 }
 for(var version=1;version<=7;version++){
   final data=jsonDecode(SaveData(const Player(life:LifeProgress(turns:168)),DateTime.utc(2026)).encode()) as Map;
   data['schemaVersion']=version;final q=data['player'] as Map; q.remove('stageTurns'); q.remove('turnsPerStage');
   q.remove('story');if(version<7)q.remove('life');
   if(version<6){q.remove('armorId');q.remove('accessoryId');}
   if(version<5){q.remove('clearedStages');q.remove('stageWins');}
   if(version<4){q.remove('gender');q.remove('weaponId');q.remove('inventory');}
   if(version<3)q.remove('morality');if(version<2)q.remove('experience');
   final migrated=SaveData.decode(jsonEncode(data),jobs).player;
   check(migrated.story.lastSettledTurn==migrated.life.turns,'migration marker $version');
   roundtrip(migrated);
 }
 print('Independent review passed $checks checks: all seeds; reachable adulthood/marriage/child; exact billing/idempotency; stale story; 36 endings/reincarnations/roundtrips; schema1-7 migration.');
}
