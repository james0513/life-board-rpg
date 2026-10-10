import '../models/life_progress.dart';
import '../models/player.dart';

/// Pure, original life rules inspired by a board-game life/career loop.
/// Perks are permanent base-stat gains, granted once per learned skill per life.
/// They are not the active combat techniques defined in the jobs catalog.
class LifeService {
  const LifeService();

  static const activities = {
    'work',
    'career',
    'battle',
    'luck',
    'penalty',
    'shop',
  };
  static const actions = {'study', 'exercise', 'socialize', 'rest', 'buyHome'};
  static const practiceToLearn = 3;
  static const reincarnationAge = 60;

  /// Resolves one board landing after its event, career, shop, or battle ends.
  /// Event settlement owns money/rewards; this method never takes money.
  Player finishTurn(Player p, {required String activity}) {
    if (!activities.contains(activity)) {
      throw ArgumentError.value(activity, 'activity', '未知的人生活動');
    }
    _requireNextTurn(p.life);
    final eqChange = switch (activity) {
      'career' => 2,
      'work' || 'battle' || 'luck' => 1,
      _ => 0,
    };
    final stressChange = switch (activity) {
      'work' => 4,
      'career' => 1,
      'battle' => 5,
      'luck' => -2,
      'penalty' => 6,
      _ => -1,
    };
    var life = p.life.copyWith(
      turns: p.life.turns + 1,
      eq: _meter(p.life.eq + eqChange),
      stress: _meter(p.life.stress + stressChange - p.life.homeLevel),
    );
    var next = p;
    if (activity == 'work') {
      // Validate before changing anything, even when the perk is already known.
      final bonus = skillBonus(p.jobId);
      final practice = (life.jobPractice[p.jobId] ?? 0) + 1;
      life = life.copyWith(
        jobPractice: {...life.jobPractice, p.jobId: practice},
      );
      if (practice >= practiceToLearn &&
          !life.learnedSkills.contains(p.jobId)) {
        life = life.copyWith(learnedSkills: [...life.learnedSkills, p.jobId]);
        next = next.apply(bonus);
      }
    }
    return next.copyWith(life: life);
  }

  /// Each successful action costs one season. Failed validation changes nothing.
  Player lifeAction(Player p, String action) {
    if (!actions.contains(action)) {
      throw ArgumentError.value(action, 'action', '未知的人生選擇');
    }
    _requireNextTurn(p.life);
    final cost = switch (action) {
      'study' => 200,
      'exercise' => 100,
      'socialize' => 150,
      'buyHome' => homeCost(p),
      _ => 0,
    };
    if (action == 'buyHome' && p.life.homeLevel >= 2) {
      throw StateError('家園已達最高等級');
    }
    if (p.money < cost) throw StateError('金錢不足，需要 $cost');
    final delta = switch (action) {
      'study' => StatDelta(money: -cost, intelligence: 5),
      'exercise' => StatDelta(money: -cost, stamina: 5),
      _ => StatDelta(money: -cost),
    };
    final stressChange = switch (action) {
      'study' => 3,
      'exercise' => -4,
      'socialize' => -3,
      'rest' => -12,
      _ => 0,
    };
    return p
        .apply(delta)
        .copyWith(
          life: p.life.copyWith(
            turns: p.life.turns + 1,
            eq: _meter(p.life.eq + (action == 'socialize' ? 3 : 0)),
            stress: _meter(p.life.stress + stressChange),
            affection: _meter(
              p.life.affection + (action == 'socialize' ? 8 : 0),
            ),
            homeLevel: p.life.homeLevel + (action == 'buyHome' ? 1 : 0),
          ),
        );
  }

  int homeCost(Player p) => switch (p.life.homeLevel) {
    0 => 2500,
    1 => 6500,
    _ => 0,
  };

  String actionDescription(String action) => switch (action) {
    'study' => '花費 200 · 智力 +5 · 壓力 +3',
    'exercise' => '花費 100 · 體力 +5 · 壓力 −4',
    'socialize' => '花費 150 · 好感 +8 · EQ +3 · 壓力 −3',
    'rest' => '免費 · 壓力 −12',
    'buyHome' => '首購 2500／升級 6500 · 每級家園使棋盤回合壓力減少 1',
    _ => throw ArgumentError.value(action, 'action', '未知的人生選擇'),
  };

  bool canReincarnate(Player p) =>
      p.campaignComplete || p.life.age >= reincarnationAge;

  /// Starts a fresh campaign, retaining gender and at most one chosen perk.
  /// All old stat growth is discarded before the chosen bonus is applied once.
  Player reincarnate(Player p, {String? inheritSkill}) {
    if (!canReincarnate(p)) throw StateError('完成六章試煉或年滿 60 歲後可轉生');
    if (p.life.generation >= LifeProgress.maxCounter) {
      throw StateError('世代已達記錄上限');
    }
    if (inheritSkill != null &&
        !p.life.learnedSkills.contains(inheritSkill) &&
        p.life.inheritedSkill != inheritSkill) {
      throw StateError('只能傳承已習得的技能');
    }
    final bonus = inheritSkill == null
        ? const StatDelta()
        : skillBonus(inheritSkill);
    final life = LifeProgress(generation: p.life.generation + 1).copyWith(
      learnedSkills: inheritSkill == null ? const [] : [inheritSkill],
      inheritedSkill: inheritSkill,
    );
    return Player(
      gender: p.gender,
      life: life,
      turnsPerStage: p.turnsPerStage,
    ).apply(bonus);
  }

  /// No JSON/catalog dependency: IDs match the shipped job tree.
  /// Tier 1/2/3 perks grant +2/+4/+6 to their specialty; root grants +1.
  StatDelta skillBonus(String id) {
    final amount = switch (id) {
      'unemployed' => 1,
      'student' || 'part_timer' || 'apprentice' || 'adventurer' => 2,
      'engineer' ||
      'artist' ||
      'warrior' ||
      'scholar' ||
      'doctor' ||
      'mage' ||
      'ranger' ||
      'merchant' ||
      'alchemist' ||
      'bard' ||
      'chef' ||
      'guardian' ||
      'dancer' ||
      'beast_tamer' => 4,
      'president' ||
      'mentor' ||
      'hero' ||
      'archmage' ||
      'paladin' ||
      'ranger_master' ||
      'sage' ||
      'maestro' ||
      'gourmet_master' ||
      'warlord' ||
      'celestial_dancer' ||
      'dragon_tamer' => 6,
      _ => throw ArgumentError.value(id, 'id', '未知的職業技能'),
    };
    return switch (id) {
      'unemployed' ||
      'student' ||
      'apprentice' ||
      'engineer' ||
      'scholar' ||
      'mage' ||
      'alchemist' ||
      'mentor' ||
      'archmage' ||
      'sage' => StatDelta(intelligence: amount),
      'part_timer' ||
      'adventurer' ||
      'warrior' ||
      'ranger' ||
      'chef' ||
      'guardian' ||
      'gourmet_master' ||
      'warlord' => StatDelta(stamina: amount),
      'artist' ||
      'merchant' ||
      'bard' ||
      'dancer' ||
      'president' ||
      'ranger_master' ||
      'maestro' ||
      'celestial_dancer' => StatDelta(charm: amount),
      _ => StatDelta(morality: amount),
    };
  }

  String skillDescription(String id) =>
      '${skillBonus(id).summary}（習得時永久增加；轉生可擇一傳承）';

  void _requireNextTurn(LifeProgress life) {
    if (life.turns >= LifeProgress.maxCounter) throw StateError('回合已達記錄上限');
  }

  int _meter(int value) => value.clamp(0, 100).toInt();
}
