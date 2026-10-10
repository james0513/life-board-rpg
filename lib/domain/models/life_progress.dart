import 'json_checks.dart';

/// Original life-simulation rules: four turns are one year, starting at 18.
///
/// The const constructor creates a fresh life with immutable empty collections.
/// Use [copyWith] to add practice or skills; it defensively copies both inputs.
class LifeProgress {
  static const int maxCounter = 1000000;

  final int turns;
  final int generation;
  final int eq;
  final int stress;
  final int affection;
  final int homeLevel;
  final Map<String, int> jobPractice;
  final List<String> learnedSkills;
  final String? inheritedSkill;

  const LifeProgress({
    this.turns = 0,
    this.generation = 1,
    this.eq = 50,
    this.stress = 0,
    this.affection = 0,
    this.homeLevel = 0,
  }) : jobPractice = const {},
       learnedSkills = const [],
       inheritedSkill = null,
       assert(turns >= 0 && turns <= maxCounter),
       assert(generation >= 1 && generation <= maxCounter),
       assert(eq >= 0 && eq <= 100),
       assert(stress >= 0 && stress <= 100),
       assert(affection >= 0 && affection <= 100),
       assert(homeLevel >= 0 && homeLevel <= 2);

  const LifeProgress._({
    required this.turns,
    required this.generation,
    required this.eq,
    required this.stress,
    required this.affection,
    required this.homeLevel,
    required this.jobPractice,
    required this.learnedSkills,
    required this.inheritedSkill,
  });

  int get age => 18 + turns ~/ 4;
  int get seasonIndex => turns % 4;
  String get season => const ['春', '夏', '秋', '冬'][seasonIndex];

  LifeProgress copyWith({
    int? turns,
    int? generation,
    int? eq,
    int? stress,
    int? affection,
    int? homeLevel,
    Map<String, int>? jobPractice,
    List<String>? learnedSkills,
    String? inheritedSkill,
    bool clearInheritedSkill = false,
  }) {
    final next = LifeProgress._(
      turns: turns ?? this.turns,
      generation: generation ?? this.generation,
      eq: eq ?? this.eq,
      stress: stress ?? this.stress,
      affection: affection ?? this.affection,
      homeLevel: homeLevel ?? this.homeLevel,
      jobPractice: jobPractice == null
          ? this.jobPractice
          : Map<String, int>.unmodifiable(jobPractice),
      learnedSkills: learnedSkills == null
          ? this.learnedSkills
          : List<String>.unmodifiable(learnedSkills),
      inheritedSkill: clearInheritedSkill
          ? null
          : inheritedSkill ?? this.inheritedSkill,
    );
    next._validate();
    return next;
  }

  void _validate({Set<String>? validJobIds}) {
    void inRange(int value, int minimum, int maximum, String name) {
      if (value < minimum || value > maximum) {
        throw FormatException('life.$name 超出有效範圍');
      }
    }

    void checkJob(String id) {
      if (id.trim().isEmpty ||
          (validJobIds != null && !validJobIds.contains(id))) {
        throw const FormatException('人生技能或熟練度的職業不存在');
      }
    }

    inRange(turns, 0, maxCounter, 'turns');
    inRange(generation, 1, maxCounter, 'generation');
    inRange(eq, 0, 100, 'eq');
    inRange(stress, 0, 100, 'stress');
    inRange(affection, 0, 100, 'affection');
    inRange(homeLevel, 0, 2, 'homeLevel');
    for (final entry in jobPractice.entries) {
      checkJob(entry.key);
      inRange(entry.value, 0, maxCounter, 'jobPractice');
    }
    for (final skill in learnedSkills) {
      checkJob(skill);
    }
    if (learnedSkills.toSet().length != learnedSkills.length) {
      throw const FormatException('人生技能不可重複');
    }
    if (inheritedSkill != null) {
      checkJob(inheritedSkill!);
      if (!learnedSkills.contains(inheritedSkill)) {
        throw const FormatException('傳承技能必須列入已習得技能');
      }
    }
  }

  Map<String, dynamic> toJson() {
    _validate();
    return {
      'turns': turns,
      'generation': generation,
      'eq': eq,
      'stress': stress,
      'affection': affection,
      'homeLevel': homeLevel,
      'jobPractice': jobPractice,
      'learnedSkills': learnedSkills,
      'inheritedSkill': inheritedSkill,
    };
  }

  factory LifeProgress.fromJson(
    Map<String, dynamic> json,
    Set<String> validJobIds,
  ) {
    checkKeys(json, {
      'turns',
      'generation',
      'eq',
      'stress',
      'affection',
      'homeLevel',
      'jobPractice',
      'learnedSkills',
      'inheritedSkill',
    }, 'life');
    final practice = jsonObject(json['jobPractice'], 'life.jobPractice');
    final life = LifeProgress._(
      turns: jsonInt(json['turns'], 'life.turns'),
      generation: jsonInt(json['generation'], 'life.generation'),
      eq: jsonInt(json['eq'], 'life.eq'),
      stress: jsonInt(json['stress'], 'life.stress'),
      affection: jsonInt(json['affection'], 'life.affection'),
      homeLevel: jsonInt(json['homeLevel'], 'life.homeLevel'),
      jobPractice: Map<String, int>.unmodifiable({
        for (final entry in practice.entries)
          entry.key: jsonInt(entry.value, 'life.jobPractice.${entry.key}'),
      }),
      learnedSkills: List<String>.unmodifiable(
        jsonList(
          json['learnedSkills'],
          'life.learnedSkills',
        ).map((value) => jsonText(value, 'life.learnedSkills')),
      ),
      inheritedSkill: json['inheritedSkill'] == null
          ? null
          : jsonText(json['inheritedSkill'], 'life.inheritedSkill'),
    );
    life._validate(validJobIds: validJobIds);
    return life;
  }
}
