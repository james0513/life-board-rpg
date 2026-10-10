import 'json_checks.dart';
import 'life_progress.dart';
import 'life_story.dart';

enum CharacterGender { male, female }

enum Stat { stamina, intelligence, charm, morality, money }

extension StatLabel on Stat {
  String get label => switch (this) {
    Stat.stamina => '體力',
    Stat.intelligence => '智力',
    Stat.charm => '魅力',
    Stat.morality => '道德',
    Stat.money => '金錢',
  };
}

class StatDelta {
  final int stamina, intelligence, charm, morality, money;
  const StatDelta({
    this.stamina = 0,
    this.intelligence = 0,
    this.charm = 0,
    this.morality = 0,
    this.money = 0,
  });
  factory StatDelta.fromJson(Map<String, dynamic> json) {
    checkKeys(json, {
      'stamina',
      'intelligence',
      'charm',
      'money',
      if (json.containsKey('morality')) 'morality',
    }, 'effects');
    return StatDelta(
      stamina: jsonInt(json['stamina'], 'effects.stamina'),
      intelligence: jsonInt(json['intelligence'], 'effects.intelligence'),
      charm: jsonInt(json['charm'], 'effects.charm'),
      morality: json.containsKey('morality')
          ? jsonInt(json['morality'], 'effects.morality')
          : 0,
      money: jsonInt(json['money'], 'effects.money'),
    );
  }
  Map<String, int> toJson() => {
    'stamina': stamina,
    'intelligence': intelligence,
    'charm': charm,
    'morality': morality,
    'money': money,
  };
  StatDelta withMoney(int value) => StatDelta(
    stamina: stamina,
    intelligence: intelligence,
    charm: charm,
    morality: morality,
    money: value,
  );
  String get summary => toJson().entries
      .where((e) => e.value != 0)
      .map((e) {
        final label = Stat.values.byName(e.key).label;
        return '$label ${e.value > 0 ? "+" : ""}${e.value}';
      })
      .join('、');
}

class Player {
  final LifeProgress life;
  final LifeStory story;
  final int position, stamina, intelligence, charm, morality, money, experience;
  final int clearedStages, stageWins;
  final int stageTurns, turnsPerStage;
  bool get bossPending => !campaignComplete && stageTurns >= turnsPerStage;
  int get currentStage => clearedStages < 6 ? clearedStages + 1 : 6;
  bool get campaignComplete => clearedStages == 6;
  final String jobId;
  final CharacterGender gender;
  final String weaponId, armorId, accessoryId;
  final Map<String, int> inventory;
  String get displayName => gender == CharacterGender.male ? '阿晨' : '小晴';
  const Player({
    this.story = const LifeStory(),
    this.life = const LifeProgress(),
    this.clearedStages = 0,
    this.stageWins = 0,
    this.stageTurns = 0,
    this.turnsPerStage = 8,
    this.position = 0,
    this.stamina = 10,
    this.intelligence = 10,
    this.charm = 10,
    this.morality = 10,
    this.money = 1000,
    this.jobId = 'unemployed',
    this.experience = 0,
    this.gender = CharacterGender.male,
    this.armorId = 'none',
    this.accessoryId = 'none',
    this.weaponId = 'none',
    this.inventory = const {'potion': 2, 'ether': 1},
  });

  int stat(Stat stat) => switch (stat) {
    Stat.stamina => stamina,
    Stat.intelligence => intelligence,
    Stat.charm => charm,
    Stat.morality => morality,
    Stat.money => money,
  };
  Player copyWith({
    LifeStory? story,
    LifeProgress? life,
    int? clearedStages,
    int? stageWins,
    int? stageTurns,
    int? turnsPerStage,
    int? position,
    String? jobId,
    int? experience,
    CharacterGender? gender,
    String? armorId,
    String? accessoryId,
    String? weaponId,
    Map<String, int>? inventory,
  }) => Player(
    life: life ?? this.life,
    story: story ?? this.story,
    clearedStages: clearedStages ?? this.clearedStages,
    stageWins: stageWins ?? this.stageWins,
    stageTurns: stageTurns ?? this.stageTurns,
    turnsPerStage: turnsPerStage ?? this.turnsPerStage,
    armorId: armorId ?? this.armorId,
    accessoryId: accessoryId ?? this.accessoryId,
    gender: gender ?? this.gender,
    weaponId: weaponId ?? this.weaponId,
    inventory: inventory == null ? this.inventory : Map.unmodifiable(inventory),
    position: position ?? this.position,
    jobId: jobId ?? this.jobId,
    stamina: stamina,
    intelligence: intelligence,
    charm: charm,
    morality: morality,
    money: money,
    experience: experience ?? this.experience,
  );
  Player apply(StatDelta d) => Player(
    clearedStages: clearedStages,
    stageWins: stageWins,
    stageTurns: stageTurns,
    turnsPerStage: turnsPerStage,
    position: position,
    jobId: jobId,
    experience: experience,
    life: life,
    story: story,
    armorId: armorId,
    accessoryId: accessoryId,
    gender: gender,
    weaponId: weaponId,
    inventory: inventory,
    stamina: _floor(stamina + d.stamina),
    intelligence: _floor(intelligence + d.intelligence),
    charm: _floor(charm + d.charm),
    morality: _floor(morality + d.morality),
    money: _floor(money + d.money),
  );
  int get level => 1 + experience ~/ 100;
  Player gainExperience(int amount) =>
      copyWith(experience: experience + _floor(amount));
  static int _floor(int n) => n < 0 ? 0 : n;
}
