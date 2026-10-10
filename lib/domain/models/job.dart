import 'dart:math';
import 'json_checks.dart';
import 'player.dart';

enum Comparison { gt, gte }

class JobRequirement {
  final Stat stat;
  final Comparison comparison;
  final int value;
  const JobRequirement(this.stat, this.comparison, this.value);
  factory JobRequirement.fromJson(Map<String, dynamic> json) {
    checkKeys(json, {'stat', 'operator', 'value'}, 'requirement');
    final statName = jsonText(json['stat'], 'requirement.stat');
    final op = jsonText(json['operator'], 'requirement.operator');
    if (!Stat.values.any((s) => s.name == statName) ||
        !Comparison.values.any((c) => c.name == op)) {
      throw const FormatException('Unknown stat or comparison');
    }
    final value = jsonInt(json['value'], 'requirement.value');
    if (value < 0) throw const FormatException('Requirement cannot be negative');
    return JobRequirement(Stat.values.byName(statName), Comparison.values.byName(op), value);
  }
  bool isMet(Player player) => switch (comparison) {
    Comparison.gt => player.stat(stat) > value,
    Comparison.gte => player.stat(stat) >= value,
  };
  String get label => '${stat.label} ${comparison == Comparison.gt ? ">" : ">="} $value';
}

class Job {
  final String id, title, description;
  final int tier;
  final String skillName;
  final Stat skillStat, attackStat;
  final int skillBase, skillScale, attackBase, attackScale;
  int get workPercent => [100, 110, 140, 180][tier];
  int skillPower(Player p) => skillBase + min(p.stat(skillStat), 200) * skillScale ~/ 100;
  int attackPower(Player p) => attackBase + min(p.stat(attackStat), 200) * attackScale ~/ 100;
  String get skillFormula => '$skillBase + ${skillStat.label} × ${skillScale / 100}（屬性計算上限 200）';
  final List<String> fromJobIds;
  final List<JobRequirement> requirements;
  Job({required this.id, required this.title, required this.description,
    required this.tier, required this.skillName, required this.skillStat, required this.attackStat,
    required this.skillBase, required this.skillScale, required this.attackBase, required this.attackScale, required List<String> fromJobIds,
    required List<JobRequirement> requirements})
    : fromJobIds = List.unmodifiable(fromJobIds),
      requirements = List.unmodifiable(requirements);
  factory Job.fromJson(Map<String, dynamic> json) {
    checkKeys(json, {'id', 'title', 'description', 'tier', 'fromJobIds', 'requirements', 'combat'}, 'job');
    final tier = jsonInt(json['tier'], 'job.tier');
    if (tier < 0 || tier > 3) throw const FormatException('Invalid job tier');
    final combat = jsonObject(json['combat'], 'combat');
    checkKeys(combat, {'skillName','skillStat','attackStat','skillBase','skillScale','attackBase','attackScale'}, 'combat');
    Stat combatStat(String key) {
      final name = jsonText(combat[key],key);
      if (!Stat.values.any((s) => s.name == name && s != Stat.money)) throw const FormatException('Invalid combat stat');
      return Stat.values.byName(name);
    }
    int value(String key) {
      final v = jsonInt(combat[key], key);
      if (v < 0) throw const FormatException('Negative combat value');
      return v;
    }
    return Job(id: jsonText(json['id'], 'job.id'), title: jsonText(json['title'], 'job.title'),
      description: jsonText(json['description'], 'job.description'), tier: tier,
      skillName: jsonText(combat['skillName'],'skillName'), skillStat: combatStat('skillStat'),
      attackStat: combatStat('attackStat'), skillBase: value('skillBase'), skillScale: value('skillScale'),
      attackBase: value('attackBase'), attackScale: value('attackScale'),
      fromJobIds: jsonList(json['fromJobIds'], 'job.fromJobIds')
        .map((e) => jsonText(e, 'fromJobId')).toList(),
      requirements: jsonList(json['requirements'], 'job.requirements')
        .map((e) => JobRequirement.fromJson(jsonObject(e, 'requirement'))).toList());
  }
}

class JobEligibility {
  final List<String> reasons;
  JobEligibility(List<String> reasons) : reasons = List.unmodifiable(reasons);
  bool get allowed => reasons.isEmpty;
}
