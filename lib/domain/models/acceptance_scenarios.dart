import 'life_progress.dart';
import 'life_story.dart';
import 'player.dart';

/// Explicit build-time sandbox. Normal runs never use this save key or these seeds.
const acceptanceMode = bool.fromEnvironment('LIFE_ACCEPTANCE', defaultValue: false);
const acceptanceSaveKey = 'life_graybox.acceptance.v026';
const acceptanceScenarioLabels = <String, String>{
  'beginning': '18 歲：新人生與連續故事',
  'family': '35 歲：交往、婚姻與家庭',
  'final_trial': '59 歲：終章戰鬥與晚年棋盤',
  'ending': '60 歲：多重結局與轉生傳承',
};

Player acceptanceScenario(String id) {
  if (!acceptanceScenarioLabels.containsKey(id)) {
    throw ArgumentError.value(id, 'id', '未知驗收情境');
  }
  if (id == 'beginning') {
    return const Player(jobId: 'student', money: 6000, stamina: 40,
      intelligence: 40, charm: 40, morality: 40);
  }
  final age = id == 'family' ? 35 : id == 'final_trial' ? 59 : 60;
  final turns = (age - 18) * 4;
  final life = LifeProgress(turns: turns, eq: 80, homeLevel: id == 'ending' ? 2 : 1)
    .copyWith(learnedSkills: ['student', 'engineer', 'mentor'],
      jobPractice: {'student': 3, 'engineer': 3, 'mentor': 3});
  final story = const LifeStory().copyWith(
    affinities: {'cen_yu': 85, 'chu_ye': 30, 'luo_qing': 20},
    partnerId: id == 'ending' ? 'cen_yu' : null,
    married: id == 'ending', children: id == 'ending' ? 1 : 0,
    lastSettledTurn: turns,
    storySteps: id == 'ending' ? {'lantern': 3, 'craft': 3, 'roots': 3} : const {'lantern': 0, 'craft': 0, 'roots': 0},
  );
  return Player(position: id == 'final_trial' ? 2 : 0,
    jobId: 'mentor', money: 15000, stamina: 160, intelligence: 160,
    charm: 90, morality: 90, clearedStages: id == 'ending' ? 6 : id == 'final_trial' ? 5 : 0,
    stageWins: id == 'final_trial' ? 3 : 0, stageTurns: id == 'final_trial' ? 8 : 0, life: life, story: story);
}
