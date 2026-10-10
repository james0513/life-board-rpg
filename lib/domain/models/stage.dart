import 'battle.dart';
import 'player.dart';

class GameStage {
  final int id, requiredWins, color;
  final int defaultTurns;
  final String title, story;
  final Enemy boss;
  const GameStage({
    required this.id,
    required this.title,
    required this.story,
    required this.requiredWins,
    required this.color,
    required this.boss,
    this.defaultTurns = 8,
  });
  factory GameStage.fromJson(Map<String, dynamic> j) {
    final stage = GameStage(
      id: j['id'] as int,
      title: j['title'] as String,
      story: j['story'] as String,
      requiredWins: j['requiredWins'] as int,
      color: j['color'] as int,
      defaultTurns: (j['defaultTurns'] as int?) ?? 8,
      boss: Enemy.fromJson(Map<String, dynamic>.from(j['boss'] as Map)),
    );
    if (stage.id < 1 ||
        stage.id > 6 ||
        !([4, 8, 12].contains(stage.defaultTurns)) ||
        stage.boss.bossStage != stage.id ||
        stage.boss.id != 'boss_${stage.id}') {
      throw const FormatException('關卡定義錯誤');
    }
    return stage;
  }
  bool bossReady(Player p) =>
      !p.campaignComplete && p.currentStage == id && p.bossPending;
}
