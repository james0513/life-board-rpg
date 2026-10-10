import 'dart:convert';

import '../models/json_checks.dart';
import '../models/job.dart';
import '../models/player.dart';
import '../models/shop_item.dart';
import 'json_source.dart';

class JobManager {
  final JsonLoader loadJson;
  Future<List<Job>>? _cache;
  List<Job>? _jobs;
  JobManager({required this.loadJson});

  List<Job> get jobs => _jobs ?? (throw StateError('Call load() first'));
  Job byId(String id) => jobs.firstWhere(
    (j) => j.id == id,
    orElse: () => throw ArgumentError.value(id, 'id', 'Unknown job'),
  );

  Future<List<Job>> load() async {
    final pending = _cache ??= _read();
    try {
      return await pending;
    } catch (_) {
      if (identical(_cache, pending)) _cache = null;
      rethrow;
    }
  }

  Future<List<Job>> _read() async {
    final root = jsonObject(
      jsonDecode(await loadJson('assets/data/jobs.json')),
      'jobs file',
    );
    checkKeys(root, {'schemaVersion', 'jobs'}, 'jobs file');
    if (jsonInt(root['schemaVersion'], 'schemaVersion') != 1) {
      throw const FormatException('Unsupported jobs schemaVersion');
    }
    final parsed = jsonList(
      root['jobs'],
      'jobs',
    ).map((e) => Job.fromJson(jsonObject(e, 'job'))).toList();
    final map = {for (final j in parsed) j.id: j};
    if (parsed.isEmpty ||
        map.length != parsed.length ||
        !map.containsKey('unemployed')) {
      throw const FormatException('Jobs need unique IDs and unemployed root');
    }
    final rootJob = map['unemployed']!;
    if (rootJob.tier != 0 ||
        rootJob.fromJobIds.isNotEmpty ||
        rootJob.requirements.isNotEmpty) {
      throw const FormatException(
        'unemployed must be an unrestricted tier-0 root',
      );
    }
    for (final job in parsed) {
      if (job.id != 'unemployed' && job.fromJobIds.isEmpty) {
        throw FormatException('${job.id} needs a predecessor');
      }
      if (job.fromJobIds.toSet().length != job.fromJobIds.length) {
        throw FormatException('${job.id} has duplicate predecessors');
      }
      for (final parent in job.fromJobIds) {
        if (!map.containsKey(parent) || map[parent]!.tier != job.tier - 1) {
          throw FormatException(
            '${job.id}: invalid predecessor $parent or tier (cycle)',
          );
        }
      }
    }
    _jobs = List.unmodifiable(parsed);
    return _jobs!;
  }

  StatDelta workEffects(Player player, StatDelta base) => base.money > 0
      ? base.withMoney(base.money * byId(player.jobId).workPercent ~/ 100)
      : base;

  JobEligibility evaluate(Player player, String targetId) {
    final job = byId(targetId);
    final reasons = <String>[];
    if (player.jobId == targetId) reasons.add('目前已是此職業');
    if (!job.fromJobIds.contains(player.jobId)) {
      reasons.add(
        '前置職業：${job.fromJobIds.isEmpty ? "不可轉入" : job.fromJobIds.map((id) => byId(id).title).join("／")}',
      );
    }
    for (final requirement in job.requirements) {
      if (!requirement.isMet(player)) {
        reasons.add(
          '${requirement.label}（目前 ${player.stat(requirement.stat)}）',
        );
      }
    }
    return JobEligibility(reasons);
  }

  // Revalidates on commit; disabling a UI button alone is insufficient.
  Player changeJob(Player player, String targetId) {
    final result = evaluate(player, targetId);
    if (!result.allowed) throw StateError(result.reasons.join('；'));
    // Money is an eligibility threshold, NOT a fee.
    return sanitizeEquipment(player.copyWith(jobId: targetId));
  }
}
