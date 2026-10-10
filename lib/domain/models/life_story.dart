import 'json_checks.dart';
import 'life_progress.dart';

/// A frozen ending, recorded once for a generation even if play continues.
class EndingRecord {
  final int generation, age, money, learnedCount;
  final String id, jobId;

  const EndingRecord({
    required this.generation,
    required this.age,
    required this.id,
    required this.jobId,
    required this.money,
    required this.learnedCount,
  });

  void validate({Set<String>? validJobIds}) {
    if (generation < 1 ||
        generation > LifeProgress.maxCounter ||
        age < 18 ||
        age > 18 + LifeProgress.maxCounter ~/ 4 ||
        money < 0 ||
        learnedCount < 0 ||
        learnedCount > 1000 ||
        !LifeStory.endingIds.contains(id) ||
        jobId.trim().isEmpty ||
        (validJobIds != null && !validJobIds.contains(jobId))) {
      throw const FormatException('人生結局紀錄無效');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'generation': generation,
      'age': age,
      'id': id,
      'jobId': jobId,
      'money': money,
      'learnedCount': learnedCount,
    };
  }

  factory EndingRecord.fromJson(
    Map<String, dynamic> json,
    Set<String> validJobIds,
  ) {
    checkKeys(json, {
      'generation',
      'age',
      'id',
      'jobId',
      'money',
      'learnedCount',
    }, 'ending');
    final record = EndingRecord(
      generation: jsonInt(json['generation'], 'ending.generation'),
      age: jsonInt(json['age'], 'ending.age'),
      id: jsonText(json['id'], 'ending.id'),
      jobId: jsonText(json['jobId'], 'ending.jobId'),
      money: jsonInt(json['money'], 'ending.money'),
      learnedCount: jsonInt(json['learnedCount'], 'ending.learnedCount'),
    );
    record.validate(validJobIds: validJobIds);
    return record;
  }
}

/// Original, immutable story/family progress. Collection inputs are copied.
/// A fresh const instance starts with all three adult acquaintances unmet.
class LifeStory {
  static const npcIds = {'cen_yu', 'chu_ye', 'luo_qing'};
  static const chainIds = {'lantern', 'craft', 'roots'};
  static const endingIds = {
    'trials',
    'scholar',
    'family',
    'prosperity',
    'peaceful',
  };
  static const historyLimit = 30;

  final Map<String, int> affinities;
  final String? partnerId;
  final bool married;
  final int children;
  final Map<String, int> storySteps;
  final Map<String, String> storyChoices;
  final int lastSettledTurn;
  final List<EndingRecord> history;
  final String? currentEndingId;

  const LifeStory({this.lastSettledTurn = 0})
    : affinities = const {'cen_yu': 0, 'chu_ye': 0, 'luo_qing': 0},
      partnerId = null,
      married = false,
      children = 0,
      storySteps = const {'lantern': 0, 'craft': 0, 'roots': 0},
      storyChoices = const {},
      history = const [],
      currentEndingId = null,
      assert(
        lastSettledTurn >= 0 && lastSettledTurn <= LifeProgress.maxCounter,
      );

  const LifeStory._({
    required this.affinities,
    required this.partnerId,
    required this.married,
    required this.children,
    required this.storySteps,
    required this.storyChoices,
    required this.lastSettledTurn,
    required this.history,
    required this.currentEndingId,
  });

  LifeStory copyWith({
    Map<String, int>? affinities,
    String? partnerId,
    bool clearPartner = false,
    bool? married,
    int? children,
    Map<String, int>? storySteps,
    Map<String, String>? storyChoices,
    int? lastSettledTurn,
    List<EndingRecord>? history,
    String? currentEndingId,
    bool clearCurrentEnding = false,
  }) {
    final next = LifeStory._(
      affinities: affinities == null
          ? this.affinities
          : Map<String, int>.unmodifiable(affinities),
      partnerId: clearPartner ? null : partnerId ?? this.partnerId,
      married: married ?? this.married,
      children: children ?? this.children,
      storySteps: storySteps == null
          ? this.storySteps
          : Map<String, int>.unmodifiable(storySteps),
      storyChoices: storyChoices == null
          ? this.storyChoices
          : Map<String, String>.unmodifiable(storyChoices),
      lastSettledTurn: lastSettledTurn ?? this.lastSettledTurn,
      history: history == null
          ? this.history
          : List<EndingRecord>.unmodifiable(history),
      currentEndingId: clearCurrentEnding
          ? null
          : currentEndingId ?? this.currentEndingId,
    );
    next.validate();
    return next;
  }

  /// With life provided, also reject impossible save cross-references.
  void validate({LifeProgress? life, Set<String>? validJobIds}) {
    if (affinities.keys.toSet().difference(npcIds).isNotEmpty ||
        npcIds.difference(affinities.keys.toSet()).isNotEmpty ||
        affinities.values.any((v) => v < 0 || v > 100) ||
        storySteps.keys.toSet().difference(chainIds).isNotEmpty ||
        chainIds.difference(storySteps.keys.toSet()).isNotEmpty ||
        storySteps.values.any((v) => v < 0 || v > 3) ||
        (partnerId != null && !npcIds.contains(partnerId)) ||
        (married && partnerId == null) ||
        children < 0 ||
        children > 2 ||
        (children > 0 && !married) ||
        lastSettledTurn < 0 ||
        lastSettledTurn > LifeProgress.maxCounter ||
        history.length > historyLimit ||
        (currentEndingId != null && !endingIds.contains(currentEndingId))) {
      throw const FormatException('人生故事或家庭資料無效');
    }
    for (final entry in storyChoices.entries) {
      final parts = entry.key.split('_');
      final step = parts.length == 2 ? int.tryParse(parts.last) : null;
      if (parts.length != 2 ||
          !chainIds.contains(parts.first) ||
          step == null ||
          step < 0 ||
          step > 2 ||
          entry.key != '${parts.first}_$step' ||
          step >= storySteps[parts.first]! ||
          !{'a', 'b'}.contains(entry.value)) {
        throw const FormatException('故事選擇必須對應已完成章節的有效選項');
      }
    }
    var previousGeneration = 0;
    for (final record in history) {
      record.validate(validJobIds: validJobIds);
      if (record.generation <= previousGeneration) {
        throw const FormatException('結局世代不可重複或倒序');
      }
      previousGeneration = record.generation;
    }
    if (currentEndingId != null &&
        (history.isEmpty || history.last.id != currentEndingId)) {
      throw const FormatException('目前結局必須對應最新紀錄');
    }
    if (life != null) {
      if (lastSettledTurn > life.turns ||
          history.any((record) => record.generation > life.generation) ||
          (currentEndingId != null &&
              history.last.generation != life.generation) ||
          (currentEndingId == null &&
              history.any((r) => r.generation == life.generation)) ||
          (currentEndingId != null && history.last.age > life.age)) {
        throw const FormatException('人生故事與世代／回合不符');
      }
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'affinities': affinities,
      'partnerId': partnerId,
      'married': married,
      'children': children,
      'storySteps': storySteps,
      'storyChoices': storyChoices,
      'lastSettledTurn': lastSettledTurn,
      'history': history.map((r) => r.toJson()).toList(growable: false),
      'currentEndingId': currentEndingId,
    };
  }

  factory LifeStory.fromJson(
    Map<String, dynamic> json,
    Set<String> validJobIds, {
    required LifeProgress life,
  }) {
    checkKeys(json, {
      'affinities',
      'partnerId',
      'married',
      'children',
      'storySteps',
      'storyChoices',
      'lastSettledTurn',
      'history',
      'currentEndingId',
    }, 'story');
    Map<String, int> counters(String key) {
      final values = jsonObject(json[key], 'story.$key');
      return Map<String, int>.unmodifiable({
        for (final e in values.entries)
          e.key: jsonInt(e.value, 'story.$key.${e.key}'),
      });
    }

    if (json['married'] is! bool)
      throw const FormatException('story.married 必須是布林值');
    final story = LifeStory._(
      affinities: counters('affinities'),
      partnerId: json['partnerId'] == null
          ? null
          : jsonText(json['partnerId'], 'story.partnerId'),
      married: json['married'] as bool,
      children: jsonInt(json['children'], 'story.children'),
      storySteps: counters('storySteps'),
      storyChoices: Map<String, String>.unmodifiable({
        for (final entry in jsonObject(
          json['storyChoices'],
          'story.storyChoices',
        ).entries)
          entry.key: jsonText(entry.value, 'story.storyChoices.${entry.key}'),
      }),
      lastSettledTurn: jsonInt(
        json['lastSettledTurn'],
        'story.lastSettledTurn',
      ),
      history: List<EndingRecord>.unmodifiable(
        jsonList(json['history'], 'story.history').map(
          (r) => EndingRecord.fromJson(
            jsonObject(r, 'story.history.record'),
            validJobIds,
          ),
        ),
      ),
      currentEndingId: json['currentEndingId'] == null
          ? null
          : jsonText(json['currentEndingId'], 'story.currentEndingId'),
    );
    story.validate(life: life, validJobIds: validJobIds);
    return story;
  }
}
