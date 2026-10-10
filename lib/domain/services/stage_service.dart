import 'dart:math';

import '../models/stage.dart';
import '../models/player.dart';
import '../models/battle.dart';

class StageService {
  final List<GameStage> stages;
  StageService(List<GameStage> source) : stages = List.unmodifiable(source) {
    if (stages.length != 6 ||
        List.generate(
          6,
          (i) => i + 1,
        ).any((id) => stages.where((s) => s.id == id).length != 1)) {
      throw const FormatException('必須包含六個唯一關卡');
    }
  }
  GameStage current(Player p) =>
      stages.firstWhere((s) => s.id == p.currentStage);
  Player settle(Player p, Enemy enemy, BattleStatus result) {
    if (result != BattleStatus.won || p.campaignComplete) return p;
    if (enemy.isBoss) {
      final stage = current(p);
      if (enemy.id != stage.boss.id || !stage.bossReady(p)) return p;
      return p.copyWith(
        clearedStages: p.clearedStages + 1,
        stageWins: 0,
        stageTurns: 0,
        position: 0,
      );
    }
    return p.copyWith(stageWins: (p.stageWins + 1).clamp(0, 3).toInt());
  }

  /// Called once, only when a map landing has fully resolved.
  static Player completeMapTurn(Player p) => p.campaignComplete || p.bossPending
      ? p
      : p.copyWith(stageTurns: p.stageTurns + 1);

  Player configureTurns(Player p, int turns) {
    if (![4, 8, 12].contains(turns)) throw ArgumentError.value(turns, 'turns');
    if (p.stageTurns != 0 || p.bossPending) {
      throw StateError('只能在每張地圖開始前設定回合數');
    }
    return p.copyWith(turnsPerStage: turns);
  }

  Enemy scaleEnemy(Enemy e, Player p) {
    if (e.isBoss) return e; // Authored boss curves are already stage-specific.
    final step = p.currentStage - 1;
    const hpPercent = [100, 125, 155, 190, 230, 275];
    const attackPercent = [100, 115, 130, 150, 175, 200];
    return Enemy(
      id: e.id,
      name: e.name,
      description: e.description,
      hp: max(e.hp + step, (e.hp * hpPercent[step] + 99) ~/ 100),
      attack: max(
        e.attack + step,
        (e.attack * attackPercent[step] + 99) ~/ 100,
      ),
      reward: e.reward * (100 + step * 30) ~/ 100,
      experience: e.experience * (100 + step * 20) ~/ 100,
      portrait: e.portrait,
      maxSp: e.maxSp,
      minTier: e.minTier,
      specialName: e.specialName,
      bossStage: e.bossStage,
    );
  }
}
