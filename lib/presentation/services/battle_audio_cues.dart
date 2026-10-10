import '../../domain/models/battle.dart';
import '../battle/spell_effect.dart';

String playerActionCue(BattleAction action, String weapon, String job) => switch (action) {
  BattleAction.attack => switch (weapon) {
    'longbow' || 'fate_bow' => 'hero_bow',
    'staff' || 'astral_staff' || 'frost_wand' => 'hero_staff',
    'none' || 'thunder_hammer' => 'hero_blunt',
    _ => 'hero_slash',
  },
  BattleAction.skill => 'cast_${spellFor(job).name}',
  BattleAction.frost => 'cast_ice',
  BattleAction.heal => 'cast_heal',
  BattleAction.burst => 'cast_burst',
  BattleAction.potion || BattleAction.ether => 'use_item',
  BattleAction.defend => 'guard',
  BattleAction.flee => 'flee',
};
String? enemyActionCue(BattleSession battle) {
  if (battle.enemyFrozen) return null;
  if (battle.enemySp >= battle.enemy.maxSp) return battle.enemy.isBoss ? 'boss_spell' : 'monster_spell';
  return battle.enemy.isBoss ? 'boss_swing' : battle.enemy.portrait.isEven ? 'monster_claw' : 'monster_bite';
}
String stageMusic(int stage) => 'stage_${stage.clamp(1, 6)}';
