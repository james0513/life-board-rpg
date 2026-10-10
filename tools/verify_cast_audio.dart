// Pure Dart audio contract checks. No Flutter or audio hardware required.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../lib/domain/models/battle.dart';
import '../lib/domain/models/player.dart';
import '../lib/domain/models/shop_item.dart';
import '../lib/presentation/services/battle_audio_cues.dart';

void check(bool value, String description) {
  if (!value) throw StateError(description);
}

void main() {
  final jobs =
      (jsonDecode(File('assets/data/jobs.json').readAsStringSync())
              as Map)['jobs']
          as List;
  final cues = <String>{'monster_spell', 'boss_spell'};
  var mappings = 0;
  for (final job in jobs) {
    for (final action in BattleAction.values) {
      for (final weapon in [
        'none',
        ...shopCatalog
            .where((item) => item.kind == ShopKind.weapon)
            .map((item) => item.id),
      ]) {
        final cue = playerActionCue(action, weapon, job['id'] as String);
        check(File('assets/audio/sfx/$cue.wav').existsSync(), 'Missing $cue');
        cues.add(cue);
        mappings++;
      }
    }
  }
  check(
    playerActionCue(BattleAction.frost, 'none', 'student') == 'cast_ice',
    'Ice cue',
  );
  check(
    playerActionCue(BattleAction.heal, 'none', 'student') == 'cast_heal',
    'Heal cue',
  );
  check(
    playerActionCue(BattleAction.burst, 'none', 'student') == 'cast_burst',
    'Burst cue',
  );
  for (final boss in [false, true]) {
    final battle = BattleSession(
      const Player(),
      Enemy(
        id: 'audio',
        name: 'Audio',
        description: '',
        hp: 10000,
        attack: 5,
        reward: 1,
        portrait: 2,
        bossStage: boss ? 1 : 0,
      ),
    );
    check(!enemyWillCast(battle), 'Uncharged enemy must not cast');
    check(
      enemyActionCue(battle) == (boss ? 'boss_swing' : 'monster_claw'),
      'Physical cue',
    );
    battle.enemySp = battle.enemy.maxSp;
    check(enemyWillCast(battle), 'Charged enemy should cast');
    check(
      enemyActionCue(battle) == (boss ? 'boss_spell' : 'monster_spell'),
      'Distinct role cast',
    );
    battle.playerAct(BattleAction.frost);
    check(!enemyWillCast(battle), 'Frozen enemy must not cast');
    check(enemyActionCue(battle) == null, 'Frozen enemy must be silent');
  }
  final fingerprints = <int>{};
  for (final cue in cues.where(isCastCue)) {
    final bytes = File('assets/audio/sfx/$cue.wav').readAsBytesSync();
    final wav = ByteData.sublistView(bytes);
    check(ascii.decode(bytes.sublist(0, 4)) == 'RIFF', '$cue WAV header');
    check(
      wav.getUint16(22, Endian.little) == 1 &&
          wav.getUint16(34, Endian.little) == 16,
      '$cue mono PCM16',
    );
    final sr = wav.getUint32(24, Endian.little);
    final samples = (bytes.length - 44) ~/ 2;
    final duration = samples / sr;
    check(
      duration > castContactDelay.inMilliseconds / 1000,
      '$cue must survive impact',
    );
    check(
      duration < castAnimationDuration.inMilliseconds / 1000,
      '$cue must finish before next action',
    );
    double rms(int startMs, int endMs) {
      var sum = 0.0;
      final start = (sr * startMs / 1000).round(),
          end = (sr * endMs / 1000).round();
      for (var i = start; i < end; i++) {
        final sample = wav.getInt16(44 + i * 2, Endian.little) / 32768;
        sum += sample * sample;
      }
      return sqrt(sum / (end - start));
    }

    check(rms(10, 100) > .08, '$cue audible onset');
    check(rms(400, 650) > .1, '$cue audible charge');
    check(rms(670, 800) > .03, '$cue audible tail');
    var hash = 0;
    for (final b in bytes) {
      hash = (hash * 31 + b) & 0x7fffffff;
    }
    check(fingerprints.add(hash), '$cue must be distinct');
  }
  check(fingerprints.length == 10, 'All ten spell assets covered');
  check(
    !isCastCue('hit_magic') && !isCastCue('hero_staff'),
    'Impact/action channel separation',
  );
  check(
    castContactDelay > physicalContactDelay,
    'Magic charge must precede impact',
  );
  print(
    'PASS: $mappings job/action/weapon cues, ten distinct audible spell WAVs, enemy charge/freeze contracts and cast timing. Actual device playback requires runtime verification.',
  );
}
