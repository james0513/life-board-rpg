import '../models/stage.dart';
import '../models/player.dart';
import '../models/battle.dart';
class StageService {
  final List<GameStage> stages;
  StageService(List<GameStage> source): stages=List.unmodifiable(source) {
    if(stages.length!=6 || List.generate(6,(i)=>i+1).any((id)=>stages.where((s)=>s.id==id).length!=1)) {
      throw const FormatException('必須包含六個唯一關卡');
    }
  }
  GameStage current(Player p)=>stages.firstWhere((s)=>s.id==p.currentStage);
  Player settle(Player p,Enemy enemy,BattleStatus result) {
    if(result!=BattleStatus.won || p.campaignComplete)return p;
    if(enemy.isBoss){
      final stage=current(p);
      if(enemy.id!=stage.boss.id || !stage.bossReady(p))return p;
      return p.copyWith(clearedStages:p.clearedStages+1,stageWins:0);
    }
    return p.copyWith(stageWins:(p.stageWins+1).clamp(0,3).toInt());
  }
  Enemy scaleEnemy(Enemy e,Player p) {
    final step=p.currentStage-1;
    return Enemy(id:e.id,name:e.name,description:e.description,
      hp:e.hp+step*18,attack:e.attack+step*2,reward:e.reward+step*40,
      experience:e.experience+step*10,portrait:e.portrait,maxSp:e.maxSp,minTier:e.minTier);
  }
}
