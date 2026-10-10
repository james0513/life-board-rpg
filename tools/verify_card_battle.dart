// Dependency-free v0.29 card battle regressions and a legal campaign policy.
// Numeric tuning here is original project tuning, not a reconstruction of
// values from the structural public-reference rules. No Flutter or pub calls.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'verify_battle_viewport.dart';

import '../lib/domain/models/battle.dart';
import '../lib/domain/models/card_battle.dart';
import '../lib/domain/models/life_progress.dart';
import '../lib/domain/models/player.dart';
import '../lib/domain/models/shop_item.dart';
import '../lib/domain/models/save_data.dart';
import '../lib/domain/models/stage.dart';
import '../lib/domain/services/stage_service.dart';

/// The full campaign harnesses share this policy, so none can silently bypass
/// cards via the legacy BattleAction attack/skill API. It sees only the hand,
/// HP and readiness that a player sees and uses the public selection API.
class CardCampaignPolicy {
  int cardMoves = 0, enemyMoves = 0, utilityMoves = 0, gaugeTicks = 0;
  int multiCardMoves = 0, impactChecks = 0;

  void _require(bool condition, String message) {
    if (!condition) throw StateError('Card campaign policy: $message');
  }

  void step(CardBattleSession battle) {
    var move = battle.pendingMove;
    if (move == null && battle.active && battle.heroReady) {
      if (battle.hp < battle.maxHp ~/ 3 &&
          battle.canUseUtility(BattleAction.potion)) {
        move = battle.useUtility(BattleAction.potion);
        if (move != null) utilityMoves++;
      } else {
        final choices = <List<BattleCard>>[];
        // Enumerate actual subsets. Use at least one weapon family and never
        // combine blade, shield and staff in a single move.
        final hand = battle.hand;
        for (var mask = 1; mask < (1 << hand.length); mask++) {
          final cards = <BattleCard>[
            for (var i = 0; i < hand.length; i++)
              if ((mask & (1 << i)) != 0) hand[i],
          ];
          final weapons = cards.where((c) => !c.isModifier).toList();
          if (weapons.isEmpty ||
              weapons.map((c) => c.family).toSet().length != 1) {
            continue;
          }
          choices.add(cards);
        }
        _require(choices.isNotEmpty, 'no legal weapon remained in hand');
        double score(List<BattleCard> cards) {
          var value = 0.0;
          for (final card in cards) {
            value += card.attack * 2.0 + card.defense * 0.45;
            if (card.isModifier) {
              value += switch (card.magic) {
                CardMagic.heal =>
                  battle.hp < battle.maxHp * 0.65
                      ? min(card.power, battle.maxHp - battle.hp) * 2.5
                      : -100.0,
                CardMagic.frost => card.power * 2.0 + 20,
                CardMagic.damage => card.power * 2.0,
                CardMagic.buff => card.power * 2.0,
                CardMagic.defense => card.power * 0.45,
                null => 0.0,
              };
            }
          }
          return value + cards.where((c) => !c.isModifier).length * 4;
        }

        choices.sort((a, b) => score(b).compareTo(score(a)));
        final chosen = choices.first;
        for (final id in battle.selectedCardIds.toList()) {
          _require(battle.toggleCard(id), 'could not clear previous selection');
        }
        for (final card in chosen) {
          _require(battle.toggleCard(card.id), 'could not select ${card.id}');
        }
        _require(
          battle.selectionError == null,
          'enumerated illegal combination: ${battle.selectionError}',
        );
        move = battle.playSelected();
        _require(move != null, 'ready selected combination was refused');
        cardMoves++;
        if (chosen.length > 1) multiCardMoves++;
      }
    }
    if (move == null && battle.active) {
      gaugeTicks++;
      move = battle.advance(100);
    }
    if (move != null) {
      if (!move.isHero) enemyMoves++;
      final impact = battle.resolveMove(move);
      _require(impact != null, 'pending move did not resolve');
      final hp = battle.hp, enemyHp = battle.enemyHp;
      _require(
        battle.resolveMove(move) == null,
        'duplicate animation contact resolved twice',
      );
      _require(
        battle.hp == hp && battle.enemyHp == enemyHp,
        'duplicate animation contact changed HP',
      );
      _require(battle.finishMove(move), 'resolved move did not finish');
      _require(!battle.finishMove(move), 'duplicate move finish succeeded');
      impactChecks++;
    }
  }

  void fight(CardBattleSession battle, {int maxSteps = 10000}) {
    var steps = 0;
    while (battle.active && steps++ < maxSteps) step(battle);
    _require(!battle.active, 'battle did not terminate after $maxSteps steps');
    _require(battle.pendingMove == null, 'terminal battle left pending move');
  }
}

class FixedCardRandom implements Random {
  const FixedCardRandom([this.value = 0]);
  final int value;
  @override
  bool nextBool() => value.isEven;
  @override
  double nextDouble() => (value % 100) / 100;
  @override
  int nextInt(int max) => value % max;
}

int checks = 0;
void check(bool value, String message) {
  checks++;
  if (!value) throw StateError('Card regression: $message');
}

const bladeA = BattleCard(
  id: 'blade-a',
  name: '測試劍甲',
  family: CardFamily.blade,
  attack: 12,
  defense: 1,
);
const bladeB = BattleCard(
  id: 'blade-b',
  name: '測試劍乙',
  family: CardFamily.blade,
  attack: 8,
  defense: 2,
);
const shield = BattleCard(
  id: 'shield',
  name: '測試盾',
  family: CardFamily.shield,
  attack: 1,
  defense: 20,
);
const staff = BattleCard(
  id: 'staff',
  name: '測試杖',
  family: CardFamily.staff,
  attack: 10,
  defense: 2,
);
const damageMagic = BattleCard(
  id: 'damage',
  name: '測試火焰',
  family: CardFamily.magic,
  magic: CardMagic.damage,
  power: 9,
);
const healMagic = BattleCard(
  id: 'heal',
  name: '測試治療',
  family: CardFamily.magic,
  magic: CardMagic.heal,
  power: 20,
);
const frostMagic = BattleCard(
  id: 'frost',
  name: '測試冰封',
  family: CardFamily.magic,
  magic: CardMagic.frost,
  power: 8,
);
const defenseMagic = BattleCard(
  id: 'defense',
  name: '測試護盾',
  family: CardFamily.magic,
  magic: CardMagic.defense,
  power: 10,
);
const buffMagic = BattleCard(
  id: 'buff',
  name: '測試祝福',
  family: CardFamily.magic,
  magic: CardMagic.buff,
  power: 10,
);
const probeEnemy = Enemy(
  id: 'card-probe',
  name: '卡牌測試敵人',
  description: '',
  hp: 10000,
  attack: 10,
  reward: 200,
  portrait: 0,
);

CardBattleSession probe({
  Player player = const Player(),
  Enemy enemy = probeEnemy,
  List<BattleCard> cards = const [bladeA, bladeB, staff, shield, damageMagic],
  List<BattleCard>? enemyCards = const [bladeA, bladeB, staff, shield],
  int? timeout,
  int heroInterval = 3600,
  int enemyInterval = 5200,
}) => CardBattleSession(
  player,
  enemy,
  random: const FixedCardRandom(99),
  initialHand: cards,
  initialEnemyHand: enemyCards,
  timeLimitMs: timeout,
  heroIntervalMs: heroInterval,
  enemyIntervalMs: enemyInterval,
);

BattleImpact commit(CardBattleSession b, List<String> ids) {
  final move = b.playCards(ids);
  check(move != null, 'fixture card combination rejected');
  final impact = b.resolveMove(move!);
  check(impact != null, 'fixture move did not resolve');
  check(b.finishMove(move), 'fixture move did not finish');
  return impact!;
}

BattleImpact counter(CardBattleSession b, [int milliseconds = 5200]) {
  final move = b.advance(milliseconds);
  check(
    move != null && !move!.isHero,
    'enemy gauge did not produce an enemy move',
  );
  final hit = b.resolveMove(move!);
  check(hit != null, 'enemy move did not resolve');
  check(b.finishMove(move), 'enemy move did not finish');
  return hit!;
}

void selectionContracts() {
  final b = probe();
  final openingIds = b.hand.map((c) => c.id).join(',');
  final hp = b.hp, enemyHp = b.enemyHp, energy = b.energy;
  check(b.playCards(const []) == null, 'empty move accepted');
  check(b.playCards(['damage']) == null, 'modifier-only move accepted');
  check(
    b.playCards(['blade-a', 'staff']) == null,
    'mixed weapon families accepted',
  );
  check(b.playCards(['blade-a', 'missing']) == null, 'unknown card accepted');
  check(b.playCards(['blade-a', 'blade-a']) == null, 'duplicate card accepted');
  check(
    b.hand.map((c) => c.id).join(',') == openingIds &&
        b.hp == hp &&
        b.enemyHp == enemyHp &&
        b.energy == energy &&
        b.round == 0,
    'invalid move consumed resources or a turn',
  );
  check(!b.toggleCard('missing'), 'unknown selection accepted');
  check(
    b.toggleCard('blade-a') && b.selectedCardIds.contains('blade-a'),
    'valid card could not be selected',
  );
  check(
    b.toggleCard('blade-a') && b.selectedCardIds.isEmpty,
    'second click must deselect without consuming card',
  );
  b.energy = 0;
  final attack = b.playCards(['blade-a', 'damage']);
  check(attack != null, 'magic combo incorrectly gated on legacy SP');
  b.resolveMove(attack!);
  b.finishMove(attack);
  check(b.energy == 0, 'card combo unexpectedly changed legacy SP');
}

void comboContracts() {
  final single = probe(), pair = probe(), modified = probe();
  single.toggleCard('blade-a');
  pair.toggleCard('blade-a');
  pair.toggleCard('blade-b');
  modified.toggleCard('blade-a');
  modified.toggleCard('blade-b');
  modified.toggleCard('damage');
  check(
    single.selectionError == null &&
        pair.selectionError == null &&
        modified.selectionError == null,
    'legal selection reported an error',
  );
  check(
    pair.selectedAttack > single.selectedAttack,
    'same-family combination did not increase power',
  );
  check(
    modified.selectedAttack ==
        pair.selectedAttack * (100 + damageMagic.power) ~/ 100,
    'damage modifier did not multiply the combined attack total',
  );
  final loneHit = commit(single, ['blade-a']);
  final pairHit = commit(pair, ['blade-a', 'blade-b']);
  final magicHit = commit(modified, ['blade-a', 'blade-b', 'damage']);
  check(
    pairHit.damage > loneHit.damage && magicHit.damage > pairHit.damage,
    'previewed multi-card/modifier strength was absent at impact',
  );
  check(
    modified.energy == BattleSession.maxSp,
    'magic modifier unexpectedly changed legacy SP',
  );
  final shieldMagic = probe(
    cards: [shield, defenseMagic, bladeA, bladeB, staff],
  );
  shieldMagic.toggleCard('shield');
  shieldMagic.toggleCard('defense');
  check(
    shieldMagic.selectedDefense ==
        shield.defense * (100 + defenseMagic.power) ~/ 100,
    'defense modifier did not multiply combined defense',
  );
  final buffed = probe(cards: [bladeA, buffMagic, shield, staff, bladeB]);
  final ordinary = probe();
  buffed.toggleCard('blade-a');
  buffed.toggleCard('buff');
  ordinary.toggleCard('blade-a');
  check(
    buffed.selectionPower.buff == buffMagic.power,
    'buff modifier omitted from combo preview',
  );
  commit(buffed, ['blade-a', 'buff']);
  check(
    buffed.heroBuff == buffMagic.power,
    'buff did not persist for next attack',
  );
  buffed.toggleCard('blade-b');
  ordinary.clearSelection();
  ordinary.toggleCard('blade-b');
  check(
    buffed.selectedAttack == ordinary.selectedAttack + buffMagic.power,
    'stored buff did not increase next attack preview',
  );
}

void impactAndRefillContracts() {
  final b = probe();
  final oldIds = b.hand.map((c) => c.id).toSet();
  final oldHp = b.hp, oldEnemyHp = b.enemyHp;
  final move = b.playCards(['blade-a', 'blade-b', 'damage']);
  check(
    move != null && identical(b.pendingMove, move),
    'committed move was not the pending animation',
  );
  check(
    b.hp == oldHp && b.enemyHp == oldEnemyHp,
    'HP changed before animation contact',
  );
  check(!move!.isResolved, 'committed move already marked resolved');
  check(!b.finishMove(move), 'unresolved move finished without impact');
  final handAfterCommit = b.hand.map((c) => c.id).toList();
  check(
    handAfterCommit.length == oldIds.length,
    'played cards did not replenish to the same hand size',
  );
  check(
    !handAfterCommit.any(['blade-a', 'blade-b', 'damage'].contains),
    'spent cards remained usable',
  );
  check(
    handAfterCommit.contains('staff') && handAfterCommit.contains('shield'),
    'unplayed cards were replaced',
  );
  check(
    handAfterCommit.toSet().length == handAfterCommit.length,
    'refill reused a card ID',
  );
  final remaining = b.remainingMilliseconds;
  final heroGauge = b.heroGauge, enemyGauge = b.enemyGauge;
  check(
    b.advance(10000) == null &&
        b.remainingMilliseconds == remaining &&
        b.heroGauge == heroGauge &&
        b.enemyGauge == enemyGauge,
    'animation lock advanced time or gauges',
  );
  check(
    !b.toggleCard('staff') &&
        b.playCards(['staff']) == null &&
        b.useUtility(BattleAction.flee) == null,
    'input was accepted during pending animation',
  );
  final hit = b.resolveMove(move);
  check(
    hit != null && hit!.damage > 0 && move.isResolved,
    'contact failed to apply attack once',
  );
  final afterHp = b.enemyHp, afterSp = b.energy, afterRound = b.round;
  check(
    b.resolveMove(move) == null &&
        b.enemyHp == afterHp &&
        b.energy == afterSp &&
        b.round == afterRound,
    'duplicate contact changed state',
  );
  check(b.finishMove(move), 'resolved move failed to finish');
  check(
    !b.finishMove(move) && b.resolveMove(move) == null,
    'completed move replayed',
  );
  check(
    b.hand.map((c) => c.id).join(',') == handAfterCommit.join(','),
    'contact or finish refilled a second time',
  );
  check(b.pendingMove == null, 'animation lock was not released');
}

void independentGaugeContracts() {
  final b = probe(heroInterval: 1000, enemyInterval: 2000);
  check(
    b.heroReady && b.heroGauge == 1 && b.enemyGauge == 0,
    'opening gauges wrong',
  );
  commit(b, ['blade-a']);
  check(
    !b.heroReady && b.heroGauge == 0 && b.enemyGauge == 0,
    'hero card did not consume only its gauge',
  );
  b.advance(500);
  check(
    (b.heroGauge - 0.5).abs() < 0.001 && (b.enemyGauge - 0.25).abs() < 0.001,
    'normal gauges do not charge at independent configured speeds',
  );
  check(b.playCards(['staff']) == null, 'cooldown hero played another card');
  b.advance(500);
  check(
    b.heroReady && (b.enemyGauge - 0.5).abs() < 0.001,
    'hero readiness reset or advanced enemy gauge incorrectly',
  );
  commit(b, ['staff']);
  check(
    (b.enemyGauge - 0.5).abs() < 0.001,
    'a second hero move reset enemy gauge',
  );
  final oldHp = b.hp;
  final move = b.advance(1000);
  check(
    move != null && !move!.isHero && b.hp == oldHp,
    'enemy readiness was tied to direct hero response or damaged early',
  );
  final hero = b.heroGauge;
  b.resolveMove(move!);
  b.finishMove(move);
  check(b.heroGauge == hero, 'enemy move reset independent hero gauge');
}

void defenseContracts() {
  const wall = BattleCard(
    id: 'wall',
    name: '無傷測試盾',
    family: CardFamily.shield,
    attack: 0,
    defense: 10000,
  );
  final b = probe(cards: [wall, bladeA, bladeB, staff, damageMagic]);
  commit(b, ['wall']);
  check(
    b.heroDefense >= 10000,
    'selected defense did not persist after finish',
  );
  final oldHp = b.hp;
  final first = counter(b);
  check(
    first.damage == 0 && b.hp == oldHp,
    'defense should permit zero damage rather than force one',
  );
  check(b.heroDefense == 0, 'defense was not consumed by next incoming attack');
  final next = counter(b);
  check(
    next.damage > 0 && b.hp < oldHp,
    'one-hit defense incorrectly remained on a second attack',
  );
}

void magicAndMetadataContracts() {
  const frozenFinal = Enemy(
    id: 'frozen-final',
    name: '霜縛試煉',
    description: '',
    hp: 10000,
    attack: 10,
    reward: 0,
    portrait: 0,
    bossStage: 6,
  );
  final freeze = probe(
    enemy: frozenFinal,
    cards: [shield, frostMagic, bladeA, bladeB, staff],
  );
  final move = freeze.playCards(['shield', 'frost']);
  check(
    move != null && move!.actionCue == BattleAction.frost,
    'frost combo lost audio/animation action metadata',
  );
  freeze.resolveMove(move!);
  freeze.finishMove(move);
  final oldHp = freeze.hp;
  final guard = freeze.heroDefense;
  final skipped = counter(freeze);
  check(
    skipped.damage == 0 && freeze.hp == oldHp,
    'frost did not suppress one enemy hit',
  );
  check(
    freeze.heroDefense == guard,
    'freeze skipped action incorrectly consumed defense',
  );
  commit(freeze, ['blade-a']);
  final next = counter(freeze);
  check(
    next.damage >= 0 && freeze.heroDefense == 0,
    'frost persisted more than one action or defense failed to consume',
  );
  final heal = probe(cards: [staff, healMagic, bladeA, bladeB, shield]);
  heal.hp -= 25;
  final beforeHp = heal.hp;
  final healingMove = heal.playCards(['staff', 'heal']);
  check(
    healingMove != null && healingMove!.actionCue == BattleAction.heal,
    'healing combo lost audio/animation action metadata',
  );
  final healingHit = heal.resolveMove(healingMove!);
  heal.finishMove(healingMove);
  check(
    healingHit != null &&
        healingHit!.healing > 0 &&
        heal.hp > beforeHp &&
        heal.hp <= heal.maxHp,
    'healing modifier failed or exceeded max HP',
  );
  final fire = probe();
  final fireMove = fire.playCards(['blade-a', 'damage']);
  check(
    fireMove != null && fireMove!.actionCue != BattleAction.attack,
    'damaging magic combo lost cast metadata',
  );
}

void inventoryContracts() {
  final b = probe();
  final handIds = b.hand.map((c) => c.id).join(',');
  check(
    !b.canUseUtility(BattleAction.potion) &&
        b.useUtility(BattleAction.potion) == null,
    'full-health potion consumed a turn',
  );
  check(
    !b.canUseUtility(BattleAction.attack) &&
        b.useUtility(BattleAction.attack) == null,
    'legacy attack bypass available as a utility',
  );
  b.hp -= 30;
  final potion = b.useUtility(BattleAction.potion);
  check(
    potion != null && potion!.actionCue == BattleAction.potion,
    'valid potion could not be committed',
  );
  final healing = b.resolveMove(potion!);
  check(
    healing != null && healing!.healing == 30 && b.hp == b.maxHp,
    'potion did not restore clamped actual HP',
  );
  check(b.resolveMove(potion) == null, 'potion contact spent twice');
  b.finishMove(potion);
  check(
    b.potions == 1 && b.remainingInventory['potion'] == 1,
    'potion stock not consumed exactly once',
  );
  check(
    b.hand.map((c) => c.id).join(',') == handIds,
    'inventory utility unexpectedly consumed cards',
  );
  b.advance(3600);
  final beforeEther = b.hand.map((c) => c.id).toSet();
  final ether = b.useUtility(BattleAction.ether);
  check(ether != null, 'valid ether could not be committed');
  final recovered = b.resolveMove(ether!);
  b.finishMove(ether);
  check(
    recovered != null &&
        b.heroReady &&
        b.heroGauge == 1 &&
        b.ethers == 0 &&
        b.remainingInventory['ether'] == 0,
    'ether stock or gauge restoration wrong',
  );
  check(
    b.hand.length == beforeEther.length &&
        b.hand.map((c) => c.id).toSet().difference(beforeEther).length == 1,
    'ether did not redraw exactly one card',
  );
  check(
    !b.canUseUtility(BattleAction.ether),
    'depleted ether remained available',
  );
  check(
    const Player().inventory['potion'] == 2,
    'session mutated persistent player inventory in place',
  );
}

void equipmentContracts() {
  const baseline = Player(clearedStages: 5);
  const armed = Player(
    clearedStages: 5,
    weaponId: 'sword',
    inventory: {'sword': 1},
  );
  const magic = Player(
    clearedStages: 5,
    weaponId: 'staff',
    inventory: {'staff': 1},
  );
  const armored = Player(
    clearedStages: 5,
    armorId: 'plate',
    inventory: {'plate': 1},
  );
  final baseAttack = commit(probe(player: baseline), ['blade-a']).damage;
  final gearedAttack = commit(probe(player: armed), ['blade-a']).damage;
  check(
    gearedAttack > baseAttack,
    'legal weapon attack bonus omitted from cards',
  );
  final baseMagic = commit(probe(player: baseline), ['staff']).damage;
  final gearedMagic = commit(probe(player: magic), ['staff']).damage;
  check(gearedMagic > baseMagic, 'legal weapon magic bonus omitted from staff');
  final plain = probe(player: baseline), protected = probe(player: armored);
  check(
    protected.maxHp == plain.maxHp + equipmentHp(armored),
    'equipment HP bonus disappeared',
  );
  final ordinaryHit = counter(plain), protectedHit = counter(protected);
  check(
    protectedHit.damage < ordinaryHit.damage,
    'equipment defense omitted from incoming cards',
  );
  const invalid = Player(weaponId: 'dawnblade', inventory: {'dawnblade': 1});
  check(
    commit(probe(player: invalid), ['blade-a']).damage ==
        commit(probe(), ['blade-a']).damage,
    'class/stage-incompatible weapon applied a card bonus',
  );
}

void timeoutAndClaimContracts() {
  final b = probe(timeout: 1000, enemyInterval: 2000);
  check(b.claim() == null, 'active card battle paid a reward');
  b.advance(1000);
  check(
    !b.active && b.timedOut && b.status == BattleStatus.escaped,
    'normal timer did not terminate battle without a victory',
  );
  final reward = b.claim();
  check(
    reward != null && reward!.money >= 0 && b.claim() == null,
    'timeout settlement was not nonnegative and exactly once',
  );
  final remaining = b.remainingMilliseconds;
  check(
    b.playSelected() == null &&
        b.advance(100000) == null &&
        b.remainingMilliseconds == remaining,
    'terminal timeout accepted another action',
  );
  const tiny = Enemy(
    id: 'tiny',
    name: '一擊敵人',
    description: '',
    hp: 1,
    attack: 1,
    reward: 200,
    portrait: 0,
    experience: 40,
  );
  final win = probe(enemy: tiny);
  final move = win.playCards(['blade-a']);
  check(
    move != null && win.claim() == null,
    'unresolved final hit paid reward',
  );
  win.resolveMove(move!);
  check(win.claim() == null, 'pending victory animation paid early reward');
  win.finishMove(move);
  check(
    win.status == BattleStatus.won && win.earnedExperience == 40,
    'lethal card impact did not preserve win/experience',
  );
  final won = win.claim();
  check(
    won != null &&
        won!.money == tiny.reward &&
        won.stamina == 3 &&
        won.intelligence == 2 &&
        won.morality == 2 &&
        win.claim() == null,
    'victory settlement changed growth/reward or paid twice',
  );
}

void finalTurnContracts() {
  const finalEnemy = Enemy(
    id: 'final',
    name: '最終試煉',
    description: '',
    hp: 10000,
    attack: 10,
    reward: 500,
    portrait: 0,
    bossStage: 6,
  );
  final b = probe(
    enemy: finalEnemy,
    timeout: 1,
    enemyCards: const [
      bladeA,
      bladeB,
      shield,
      staff,
      BattleCard(
        id: 'enemy-extra',
        name: '測試刃',
        family: CardFamily.blade,
        attack: 5,
      ),
    ],
  );
  check(
    b.turnMode && b.heroReady,
    'sixth boss did not use hero-first turn mode',
  );
  b.advance(100000);
  check(
    b.active && !b.timedOut && b.heroReady,
    'final turn mode used normal timer or enemy attacked before hero',
  );
  commit(b, ['blade-a']);
  check(!b.heroReady, 'hero received two consecutive final-boss turns');
  check(b.playCards(['staff']) == null, 'final turn order allowed hero replay');
  counter(b, 1);
  check(
    b.heroReady && b.active && !b.timedOut,
    'final enemy turn failed to restore hero turn',
  );
  commit(b, ['staff']);
  counter(b, 1);
  check(b.heroReady, 'second final turn cycle stalled');
}

void ageAndHandContracts() {
  for (final age in [0, 10, 14]) {
    check(cardHandSizeForAge(age) == 3, 'young hand mapping changed at $age');
  }
  for (final age in [15, 16, 17]) {
    check(cardHandSizeForAge(age) == 4, 'teen hand mapping changed at $age');
  }
  for (final age in [18, 22, 35, 50, 99]) {
    check(cardHandSizeForAge(age) == 5, 'adult hand mapping changed at $age');
    final b = probe(
      player: Player(life: LifeProgress(turns: (age - 18) * 4)),
    );
    check(
      b.handSize == 5 && b.hand.length == 5,
      'playable adult hand has wrong size',
    );
  }
  final b = probe();
  var immutable = false;
  try {
    b.hand.clear();
  } on UnsupportedError {
    immutable = true;
  }
  check(immutable && b.hand.length == 5, 'external caller mutated hand');
  immutable = false;
  try {
    b.enemyHand.clear();
  } on UnsupportedError {
    immutable = true;
  }
  check(immutable, 'external caller mutated enemy hand');
  immutable = false;
  b.toggleCard('blade-a');
  try {
    b.selectedCardIds.clear();
  } on UnsupportedError {
    immutable = true;
  }
  check(
    immutable && b.selectedCardIds.contains('blade-a'),
    'external caller mutated selected IDs',
  );
  final modifiers = probe(
    cards: const [damageMagic, healMagic, frostMagic, defenseMagic, buffMagic],
  );
  check(
    modifiers.hand.length == 5 && modifiers.hand.any((c) => !c.isModifier),
    'modifier-only injected hand stranded player without a weapon',
  );
  for (var seed = 0; seed < 30; seed++) {
    final session = CardBattleSession(
      const Player(stamina: 200),
      probeEnemy,
      random: Random(seed),
    );
    final policy = CardCampaignPolicy();
    for (var steps = 0; steps < 300 && session.active; steps++) {
      policy.step(session);
      check(
        session.hand.length == session.handSize &&
            session.hand.map((c) => c.id).toSet().length ==
                session.hand.length &&
            session.hand.any((c) => !c.isModifier),
        'refill invariant failed for seed $seed at step $steps',
      );
    }
    check(policy.cardMoves > 0, 'seeded draw probe did not commit cards');
  }
}

void foreignAndLegacyContracts() {
  final a = probe(), b = probe();
  final aMove = a.playCards(['blade-a'])!, bMove = b.playCards(['blade-b'])!;
  final beforeHp = b.enemyHp;
  check(
    b.resolveMove(aMove) == null &&
        !b.finishMove(aMove) &&
        b.enemyHp == beforeHp &&
        identical(b.pendingMove, bMove),
    'foreign session move changed state or unlocked another command',
  );
  a.resolveMove(aMove);
  a.finishMove(aMove);
  b.resolveMove(bMove);
  b.finishMove(bMove);
  check(
    !b.canUse(BattleAction.attack) &&
        b.playerAct(BattleAction.attack) == null &&
        b.enemyAct() == null,
    'legacy direct-action bypass remained active',
  );
  var blocked = false;
  try {
    b.act(BattleAction.attack);
  } on UnsupportedError {
    blocked = true;
  }
  check(blocked, 'legacy synchronous action bypass silently succeeded');
  var badInterval = false;
  try {
    probe(heroInterval: 0);
  } on ArgumentError {
    badInterval = true;
  }
  check(badInterval, 'zero gauge interval accepted');
  var duplicateHand = false;
  try {
    probe(cards: [bladeA, bladeA]);
  } on ArgumentError {
    duplicateHand = true;
  }
  check(duplicateHand, 'duplicate initial card IDs accepted');
  var oversized = false;
  try {
    probe(cards: [bladeA, bladeB, shield, staff, damageMagic, healMagic]);
  } on ArgumentError {
    oversized = true;
  }
  check(oversized, 'oversized initial hand accepted');
  var negativeTime = false;
  try {
    b.advance(-1);
  } on ArgumentError {
    negativeTime = true;
  }
  check(negativeTime, 'negative time update accepted');
}

void retainedDefenseAndFrostContracts() {
  final b = probe(heroInterval: 1000, enemyInterval: 5000);
  commit(b, ['shield']);
  check(b.heroDefense == shield.defense, 'shield defense not stored');
  b.advance(1000);
  commit(b, ['blade-a']);
  check(
    b.heroDefense == bladeA.defense,
    'new action failed to replace retained defense with its current value',
  );
  final frost = probe(
    cards: [bladeA, frostMagic, bladeB, staff, shield],
    heroInterval: 1000,
    enemyInterval: 2000,
  );
  commit(frost, ['blade-a', 'frost']);
  check(frost.enemyFrozen, 'normal frost was not applied');
  check(
    frost.advance(1000) == null &&
        frost.heroGauge == 1 &&
        frost.enemyGauge == 0 &&
        frost.enemyFrozen,
    'frost failed to pause enemy gauge independently',
  );
  check(
    frost.advance(800) == null && !frost.enemyFrozen && frost.enemyGauge == 0,
    'normal frost duration did not expire at configured project delay',
  );
  check(
    frost.advance(1000) == null && (frost.enemyGauge - 0.5).abs() < 0.001,
    'enemy gauge did not resume after frost delay',
  );
  final enemy = frost.advance(1000);
  check(enemy != null && !enemy!.isHero, 'delayed enemy action never resumed');
  frost.resolveMove(enemy!);
  frost.finishMove(enemy);
}

String get regressionProjectRoot {
  final scriptRoot = File.fromUri(Platform.script).parent.parent.path;
  return File('$scriptRoot/pubspec.yaml').existsSync()
      ? scriptRoot
      : Directory.current.path;
}

void outcomeContracts() {
  final ordinary = probe(player: const Player(money: 40));
  ordinary.hp = 1;
  counter(ordinary);
  check(
    ordinary.status == BattleStatus.lost,
    'enemy contact failed to produce ordinary defeat',
  );
  final loss = ordinary.claim();
  check(
    loss != null &&
        loss!.money == -40 &&
        ordinary.claim() == null &&
        ordinary.earnedExperience == 0,
    'ordinary defeat changed bounded loss or claimed twice',
  );
  final root = regressionProjectRoot;
  final stages = StageService(
    (jsonDecode(File('$root/assets/data/stages.json').readAsStringSync())
            as List)
        .map((j) => GameStage.fromJson(Map<String, dynamic>.from(j)))
        .toList(),
  );
  const player = Player(
    money: 0,
    stamina: 0,
    intelligence: 0,
    turnsPerStage: 4,
    stageTurns: 4,
    inventory: {},
  );
  final boss = stages.current(player).boss;
  final defeated = probe(player: player, enemy: boss);
  defeated.hp = 1;
  counter(defeated);
  final defeatedReward = defeated.claim();
  check(
    defeated.status == BattleStatus.lost &&
        defeatedReward != null &&
        defeatedReward!.money == 0 &&
        defeatedReward.stamina == 2 &&
        defeatedReward.intelligence == 2,
    'card boss defeat did not preserve exactly one catch-up reward',
  );
  final timeout = probe(player: player, enemy: boss, timeout: 1);
  timeout.advance(1);
  final consolation = timeout.claim();
  check(
    timeout.timedOut &&
        timeout.status == BattleStatus.escaped &&
        consolation != null &&
        consolation!.money == timeout.resultMoney &&
        consolation.money ==
            max(
              CardBattleTuning.minimumConsolationMoney,
              boss.reward ~/ CardBattleTuning.consolationMoneyDivisor,
            ) &&
        consolation.stamina == 2 &&
        consolation.intelligence == 2 &&
        timeout.earnedExperience > 0 &&
        timeout.claim() == null,
    'boss timeout consolation/growth/experience or one-claim contract failed',
  );
  final settled = stages.settle(
    player.apply(consolation!).gainExperience(timeout.earnedExperience),
    boss,
    timeout.status,
  );
  check(
    settled.bossPending &&
        settled.clearedStages == player.clearedStages &&
        settled.stageTurns == player.stageTurns &&
        settled.life.turns == player.life.turns,
    'timeout advanced boss, bypassed map turns, or consumed another season',
  );
  final raw = SaveData(settled, DateTime.utc(2026)).encode();
  check(
    SaveData(
          SaveData.decode(raw, {'unemployed'}).player,
          DateTime.utc(2026),
        ).encode() ==
        raw,
    'timeout reward changed on save/reload',
  );
  final escaped = CardBattleSession(
    const Player(),
    probeEnemy,
    random: const FixedCardRandom(0),
  );
  final flee = escaped.useUtility(BattleAction.flee);
  check(flee != null, 'flee utility unavailable at ready opening');
  escaped.resolveMove(flee!);
  escaped.finishMove(flee);
  final fled = escaped.claim();
  check(
    escaped.status == BattleStatus.escaped &&
        !escaped.timedOut &&
        fled != null &&
        fled!.money == 0 &&
        escaped.earnedExperience == 0 &&
        escaped.claim() == null,
    'flee paid timeout rewards or repeated settlement',
  );
}

void activeRouteContracts() {
  final root = regressionProjectRoot;
  final game = File('$root/lib/presentation/screens/game_screen.dart')
      .readAsStringSync();
  check(
    game.contains('CardBattleSession(') && game.contains('CardBattleScreen('),
    'active game route does not construct card domain and card screen',
  );
  check(
    !RegExp(r'\bBattleSession\s*\(').hasMatch(game) &&
        !RegExp(r'\bBattleScreen\s*\(').hasMatch(game),
    'active game route still constructs legacy direct-action combat',
  );
  final screen = File('$root/lib/presentation/battle/card_battle_screen.dart')
      .readAsStringSync();
  check(
    screen.contains('battle.resolveMove(') &&
        screen.contains('battle.finishMove('),
    'card route does not wire contact and finish phases',
  );
  check(
    screen.contains('void dispose()') && screen.contains('_clock?.cancel()'),
    'card route lacks clock disposal contract',
  );
  // Source checks establish wiring only. They are NOT runtime lifecycle, widget,
  // animation, layout, sound, or disposal test claims.
}

final Map<String, void Function()> cardRegressionCases = {
  'age hand capacities, immutable views and seeded refill guarantees':
      ageAndHandContracts,
  'defeat, boss recovery, timeout persistence and flee outcomes':
      outcomeContracts,
  'foreign/stale moves, malformed fixtures and legacy bypass rejection':
      foreignAndLegacyContracts,
  'retained defense replacement and normal frost gauge delay':
      retainedDefenseAndFrostContracts,
  'active game route and disposal source contracts (not runtime)':
      activeRouteContracts,
  'selection rejects empty, mixed, duplicate and unknown combinations without SP gating':
      selectionContracts,
  'same-family cards and modifiers change preview and contact damage':
      comboContracts,
  'pending contact, single refill, duplicate clicks and phase completion':
      impactAndRefillContracts,
  'ordinary combat charges independent gauges and pauses during impacts':
      independentGaugeContracts,
  'defense is held for one incoming hit and permits zero damage':
      defenseContracts,
  'frost, healing and cast-action metadata survive card combinations':
      magicAndMetadataContracts,
  'inventory utilities clamp healing, consume once and do not consume cards':
      inventoryContracts,
  'legal equipment bonuses apply and incompatible equipment stays inactive':
      equipmentContracts,
  'timer, pending victory and terminal settlement have one claim':
      timeoutAndClaimContracts,
  'sixth boss uses alternate turns without ordinary timer': finalTurnContracts,
};

void main() {
  checks = 0;
  verifyBattleViewport();
  for (final entry in cardRegressionCases.entries) {
    entry.value();
    stdout.writeln('PASS cards: ${entry.key}');
  }
  stdout.writeln(
    'PASS: ${cardRegressionCases.length} card regression groups; '
    '$checks assertions. Pure Dart domain only; Flutter/widget/render/audio runtime untested.',
  );
}
