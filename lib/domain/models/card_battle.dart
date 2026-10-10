import 'dart:math';

import 'battle.dart';
import 'player.dart';
import 'shop_item.dart';

/// Every number, card name, refill rule and damage formula in this file is
/// ORIGINAL PROJECT TUNING, not a recovered numeric rule from the 1999 game.
/// The historical structural reference is a hand of cards, same-weapon-family
/// combinations, magic modifiers, independent action gauges and a time limit.
abstract final class CardBattleTuning {
  static const heroIntervalMs = 3600;
  static const enemyIntervalMs = 5200;
  static const timeLimitMs = 90000;
  static const potionHealing = 40;
  static const freezeDelayMs = 1800;
  static const fleePercent = 65;
  static const minimumConsolationMoney = 10;
  static const consolationMoneyDivisor = 12;
  static const minimumConsolationExperience = 5;
  static const consolationExperienceDivisor = 10;
  static const enemyAttackPercent = 75;
  static const enemyCardAttackDivisor = 4;
  static const enemyDefenseDivisor = 2;
  static const enemyMagicDivisor = 2;
  static const finalEnrageAttack = 4;
  static const buffPower = 10;
}

/// The game begins at 18. Younger sizes are available for future life phases.
/// These thresholds are project tuning rather than verified historical data.
int cardHandSizeForAge(int age) => age >= 18
    ? 5
    : age >= 15
    ? 4
    : 3;

enum CardFamily { blade, shield, staff, magic }

enum CardMagic { damage, defense, buff, heal, frost }

enum CardActor { hero, enemy }

extension CardFamilyLabel on CardFamily {
  String get label => switch (this) {
    CardFamily.blade => '刃器',
    CardFamily.shield => '盾器',
    CardFamily.staff => '杖器',
    CardFamily.magic => '魔法',
  };
}

extension CardMagicLabel on CardMagic {
  String get label => switch (this) {
    CardMagic.damage => '增傷',
    CardMagic.defense => '護盾',
    CardMagic.buff => '蓄勢',
    CardMagic.heal => '回復',
    CardMagic.frost => '霜縛',
  };
}

/// A physical card instance. IDs are unique even when two faces are identical.
class BattleCard {
  final String id, name;
  final CardFamily family;
  final int attack, defense, power;
  final CardMagic? magic;
  const BattleCard({
    required this.id,
    required this.name,
    required this.family,
    this.attack = 0,
    this.defense = 0,
    this.magic,
    this.power = 0,
  }) : assert(attack >= 0 && defense >= 0 && power >= 0),
       assert((family == CardFamily.magic) == (magic != null));

  bool get isModifier => family == CardFamily.magic;
  int get spCost => 0; // Modifiers combine freely; legacy SP is unused.
  String get description => isModifier
      ? (magic == CardMagic.frost
            ? '霜縛延後行動｜可搭配任一武器系'
            : '${magic!.label} +$power${magic == CardMagic.damage || magic == CardMagic.defense ? '%' : ''}｜可搭配任一武器系')
      : '${family.label}｜攻 $attack・防 $defense';
}

/// A preview includes card sums, profession/gear, and the current stored buff.
/// Defense is held until the next incoming damaging card attack, then consumed.
class CardPower {
  final CardFamily? family;
  final int attack, defense, healing, buff, spCost;
  final bool frost;
  const CardPower({
    this.family,
    this.attack = 0,
    this.defense = 0,
    this.healing = 0,
    this.buff = 0,
    this.spCost = 0,
    this.frost = false,
  });
}

/// An immutable command plus an observable resolution flag. Only its originating
/// session may resolve it, once, at contact; finish releases the animation lock.
class CardMove {
  final int id;
  final CardActor actor;
  final List<BattleCard> cards;
  final BattleAction actionCue;
  final CardPower power;
  final String label;
  final bool _frozenSkip;
  bool _resolved = false;
  CardMove._({
    required this.id,
    required this.actor,
    required List<BattleCard> cards,
    required this.actionCue,
    required this.power,
    required this.label,
    bool frozenSkip = false,
  }) : cards = List.unmodifiable(cards),
       _frozenSkip = frozenSkip;

  bool get isHero => actor == CardActor.hero;
  bool get isResolved => _resolved;
  int get attack => power.attack;
  int get defense => power.defense;
}

/// Pure deterministic card combat. There are no timers or Flutter dependencies.
///
/// Normal fights (including bosses 1–5) advance two independent action gauges.
/// A ready hero may choose when to commit; that never forces an enemy turn.
/// Boss 6 is explicitly a PROJECT turn-mode adaptation using the same cards.
///
/// PROJECT usability adaptation: while [pendingMove] exists, both gauges, frost
/// delays and the countdown pause, including between contact and animation end.
/// A large [advance] stops at the first enemy action or timeout; remaining wall
/// time is discarded because it belongs to the animation being requested.
class CardBattleSession extends BattleSession {
  CardBattleSession(
    super.player,
    super.enemy, {
    super.random,
    super.job,
    List<BattleCard>? initialHand,
    List<BattleCard>? initialEnemyHand,
    int? timeLimitMs,
    int? heroIntervalMs,
    int? enemyIntervalMs,
  }) : heroIntervalMs = heroIntervalMs ?? CardBattleTuning.heroIntervalMs,
       enemyIntervalMs = enemyIntervalMs ?? CardBattleTuning.enemyIntervalMs,
       timeLimitMs = timeLimitMs ?? CardBattleTuning.timeLimitMs {
    if (this.heroIntervalMs <= 0 ||
        this.enemyIntervalMs <= 0 ||
        this.timeLimitMs <= 0) {
      throw ArgumentError(
        'Card battle intervals and time limit must be positive',
      );
    }
    _heroGaugeMs = this.heroIntervalMs;
    _remainingMs = this.timeLimitMs;
    _hand = _initialCards(initialHand, handSize, false);
    _enemyHand = _initialCards(initialEnemyHand, 5, true);
    message = turnMode ? '最終決戰：回合制改編。選擇同系武器牌，可搭配魔法。' : '行動槽各自累積；選擇同系武器牌，可搭配魔法。';
  }

  final int heroIntervalMs, enemyIntervalMs, timeLimitMs;
  late List<BattleCard> _hand, _enemyHand;
  final Set<String> _selectedCardIds = {};
  final Set<String> _issuedCardIds = {};
  late int _heroGaugeMs, _remainingMs;
  int _enemyGaugeMs = 0, _cardSerial = 0, _moveSerial = 0;
  int _heroDefense = 0, _enemyDefense = 0;
  int _heroBuff = 0, _enemyBuff = 0;
  int _heroFreezeMs = 0, _enemyFreezeMs = 0;
  bool _heroTurn = true, _heroTurnFrozen = false, _enemyTurnFrozen = false;
  bool _timedOut = false, _cardClaimed = false;
  CardMove? _pendingMove;

  int get handSize => cardHandSizeForAge(player.life.age);
  List<BattleCard> get hand => List.unmodifiable(_hand);
  List<BattleCard> get enemyHand => List.unmodifiable(_enemyHand);
  Set<String> get selectedCardIds => Set.unmodifiable(_selectedCardIds);
  List<BattleCard> get selectedCards => List.unmodifiable(
    _hand.where((card) => _selectedCardIds.contains(card.id)),
  );
  CardMove? get pendingMove => _pendingMove;
  bool get turnMode => enemy.bossStage == 6;
  bool get timedOut => _timedOut;
  int get remainingMilliseconds => turnMode ? 0 : _remainingMs;
  double get heroGauge => (_heroGaugeMs / heroIntervalMs).clamp(0.0, 1.0);
  double get enemyGauge => (_enemyGaugeMs / enemyIntervalMs).clamp(0.0, 1.0);
  bool get heroReady =>
      active &&
      _pendingMove == null &&
      (turnMode
          ? _heroTurn && !_heroTurnFrozen
          : _heroGaugeMs >= heroIntervalMs && _heroFreezeMs == 0);
  int get heroDefense => _heroDefense;
  int get enemyDefense => _enemyDefense;
  int get heroBuff => _heroBuff;
  int get enemyBuff => _enemyBuff;
  @override
  bool get enemyFrozen => _enemyFreezeMs > 0 || _enemyTurnFrozen;
  @override
  bool get awaitingEnemy =>
      _pendingMove?.actor == CardActor.enemy ||
      (turnMode && !_heroTurn && active);
  @override
  String get intent => enemyFrozen
      ? '霜縛延遲行動'
      : turnMode
      ? (_heroTurn ? '等待你的卡牌行動' : '準備卡牌行動')
      : '行動槽滿時，自動打出同系組合';

  CardPower get selectionPower => _powerFor(selectedCards, true);
  int get selectedAttack => selectionPower.attack;
  int get selectedDefense => selectionPower.defense;
  String? get selectionError => _selectionError(selectedCards);

  /// Selection is editable during recharge, but not during an animation.
  bool toggleCard(String id) {
    if (!active || _pendingMove != null || !_hand.any((c) => c.id == id)) {
      return false;
    }
    if (!_selectedCardIds.remove(id)) _selectedCardIds.add(id);
    return true;
  }

  void clearSelection() {
    if (_pendingMove == null) _selectedCardIds.clear();
  }

  String? _selectionError(List<BattleCard> cards) {
    if (cards.isEmpty) return '請至少選擇一張武器牌';
    final weapons = cards.where((c) => !c.isModifier).toList();
    if (weapons.isEmpty) return '魔法牌必須搭配武器牌';
    if (weapons.map((c) => c.family).toSet().length != 1) {
      return '一次只能使用同一武器系；魔法牌可自由搭配';
    }
    return null;
  }

  CardMove? playSelected() => playCards(_selectedCardIds.toList());

  /// Commits once: remove selected instances, refill, reset this
  /// actor's gauge, and create a move. HP/defense change only at [resolveMove].
  CardMove? playCards(Iterable<String> ids) {
    if (!heroReady) return null;
    final requested = ids.toList();
    if (requested.toSet().length != requested.length ||
        requested.any((id) => !_hand.any((card) => card.id == id)))
      return null;
    final cards = _hand.where((c) => requested.contains(c.id)).toList();
    final error = _selectionError(cards);
    if (error != null) {
      message = error;
      return null;
    }
    return _commitCards(cards, true);
  }

  bool canUseUtility(BattleAction action) =>
      heroReady &&
      (switch (action) {
        BattleAction.potion => potions > 0 && hp < maxHp,
        BattleAction.ether => ethers > 0,
        BattleAction.flee => true,
        _ => false,
      });

  CardMove? useUtility(BattleAction action) {
    if (!canUseUtility(action)) return null;
    if (action == BattleAction.potion) potions--;
    if (action == BattleAction.ether) ethers--;
    final label = switch (action) {
      BattleAction.potion => '恢復藥',
      BattleAction.ether => '專注飲',
      _ => '撤退',
    };
    round++;
    _heroGaugeMs = 0;
    _selectedCardIds.clear();
    return _pendingMove = CardMove._(
      id: ++_moveSerial,
      actor: CardActor.hero,
      cards: [],
      actionCue: action,
      power: const CardPower(),
      label: label,
    );
  }

  /// Advances active simulation time only. Enemy AI commits immediately when
  /// its own gauge becomes ready, independent of whether the hero acted.
  CardMove? advance(int milliseconds) {
    if (milliseconds < 0)
      throw ArgumentError.value(milliseconds, 'milliseconds');
    if (!active || _pendingMove != null) return null;
    if (turnMode) {
      if (_heroTurn && _heroTurnFrozen) return _commitFrozenSkip(true);
      if (!_heroTurn)
        return _enemyTurnFrozen ? _commitFrozenSkip(false) : _commitEnemy();
      return null;
    }
    final untilEnemy = max(0, enemyIntervalMs - _enemyGaugeMs) + _enemyFreezeMs;
    final delta = min(milliseconds, min(_remainingMs, untilEnemy));
    _remainingMs -= delta;
    final heroDelay = min(delta, _heroFreezeMs);
    _heroFreezeMs -= heroDelay;
    _heroGaugeMs = min(heroIntervalMs, _heroGaugeMs + delta - heroDelay);
    final enemyDelay = min(delta, _enemyFreezeMs);
    _enemyFreezeMs -= enemyDelay;
    _enemyGaugeMs = min(enemyIntervalMs, _enemyGaugeMs + delta - enemyDelay);
    if (_remainingMs <= 0) {
      _remainingMs = 0;
      _timedOut = true;
      status = BattleStatus.escaped;
      _selectedCardIds.clear();
      message = '時間到，挑戰未完成。獲得少量歷練與慰勞金。';
      return null;
    }
    if (_enemyGaugeMs >= enemyIntervalMs && _enemyFreezeMs == 0) {
      return _commitEnemy();
    }
    return null;
  }

  CardMove _commitCards(List<BattleCard> cards, bool hero) {
    final power = _powerFor(cards, hero);
    final cue = _cueFor(cards);
    final label =
        '${power.family!.label}組合${cards.any((c) => c.isModifier) ? '・魔法' : ''}';
    if (hero) {
      _hand.removeWhere((c) => cards.any((selected) => selected.id == c.id));
      _refill(_hand, handSize, false);
      _selectedCardIds.clear();
      _heroGaugeMs = 0;
      round++;
    } else {
      _enemyHand.removeWhere(
        (c) => cards.any((selected) => selected.id == c.id),
      );
      _refill(_enemyHand, 5, true);
      _enemyGaugeMs = 0;
    }
    return _pendingMove = CardMove._(
      id: ++_moveSerial,
      actor: hero ? CardActor.hero : CardActor.enemy,
      cards: cards,
      actionCue: cue,
      power: power,
      label: label,
    );
  }

  CardMove _commitFrozenSkip(bool hero) {
    if (hero) {
      _heroTurnFrozen = false;
      _heroGaugeMs = 0;
    } else {
      _enemyTurnFrozen = false;
      _enemyGaugeMs = 0;
    }
    return _pendingMove = CardMove._(
      id: ++_moveSerial,
      actor: hero ? CardActor.hero : CardActor.enemy,
      cards: [],
      actionCue: BattleAction.frost,
      power: const CardPower(),
      label: '霜縛・暫停行動',
      frozenSkip: true,
    );
  }

  CardMove _commitEnemy() {
    // Every refill guarantees a weapon, so a legal move always exists.
    List<BattleCard> best = [];
    var bestScore = -1;
    for (final family in [
      CardFamily.blade,
      CardFamily.shield,
      CardFamily.staff,
    ]) {
      final candidate = _enemyHand.where((c) => c.family == family).toList();
      if (candidate.isEmpty) continue;
      for (final modifier in _enemyHand.where((c) => c.isModifier)) {
        if (modifier.magic == CardMagic.heal && enemyHp == enemy.hp) continue;
        candidate.add(modifier);
      }
      final power = _powerFor(candidate, false);
      final score =
          power.attack +
          power.defense ~/ 2 +
          min(enemy.hp - enemyHp, power.healing) +
          power.buff ~/ 2;
      if (score > bestScore) {
        best = candidate;
        bestScore = score.toInt();
      }
    }
    return _commitCards(best, false);
  }

  CardPower _powerFor(List<BattleCard> cards, bool hero) {
    final weapons = cards.where((c) => !c.isModifier).toList();
    if (weapons.isEmpty) return const CardPower();
    final family = weapons.first.family;
    final arcane = family == CardFamily.staff;
    var attack = cards.fold<int>(0, (a, c) => a + c.attack);
    var defense = cards.fold<int>(0, (a, c) => a + c.defense);
    var healing = 0, buff = 0, spCost = 0;
    var damagePercent = 0, defensePercent = 0;
    var frost = false;
    if (hero) {
      attack += arcane
          ? (job?.skillPower(player) ??
                    18 + min(player.intelligence, 200) ~/ 3) +
                equipmentMagic(player)
          : (job?.attackPower(player) ?? 10 + min(player.stamina, 200) ~/ 4) +
                equipmentAttack(player);
      attack += _heroBuff;
    } else {
      attack =
          attack ~/ CardBattleTuning.enemyCardAttackDivisor +
          enemy.attack * CardBattleTuning.enemyAttackPercent ~/ 100 +
          _enemyBuff +
          (finalEnraged ? CardBattleTuning.finalEnrageAttack : 0);
      defense ~/= CardBattleTuning.enemyDefenseDivisor;
    }
    for (final modifier in cards.where((c) => c.isModifier)) {
      spCost += modifier.spCost;
      final power = hero
          ? modifier.power
          : max(1, modifier.power ~/ CardBattleTuning.enemyMagicDivisor);
      switch (modifier.magic!) {
        case CardMagic.damage:
          damagePercent += modifier.power;
        case CardMagic.defense:
          defensePercent += modifier.power;
        case CardMagic.buff:
          buff += power;
        case CardMagic.heal:
          healing +=
              power +
              (hero
                  ? min(player.intelligence, 200) ~/ 5 +
                        equipmentMagic(player) ~/ 2
                  : 0);
        case CardMagic.frost:
          frost = true;
      }
    }
    // Magic percentages multiply the combined attack/defense totals. Their
    // specific percentages and profession/gear integration are project tuning.
    attack = attack * (100 + damagePercent) ~/ 100;
    defense = defense * (100 + defensePercent) ~/ 100;
    return CardPower(
      family: family,
      attack: max(1, attack),
      defense: defense,
      healing: healing,
      buff: buff,
      frost: frost,
      spCost: spCost,
    );
  }

  BattleAction _cueFor(List<BattleCard> cards) {
    if (cards.any((c) => c.magic == CardMagic.frost)) return BattleAction.frost;
    if (cards.any((c) => c.magic == CardMagic.heal)) return BattleAction.heal;
    if (cards.any((c) => c.isModifier || c.family == CardFamily.staff))
      return BattleAction.skill;
    if (cards.first.family == CardFamily.shield) return BattleAction.defend;
    return BattleAction.attack;
  }

  /// The contact frame is the ONLY place HP, shield or frost effects change.
  /// An old, foreign, duplicate, or already finished move cannot resolve again.
  BattleImpact? resolveMove(CardMove move) {
    if (!identical(_pendingMove, move) || move._resolved || !active)
      return null;
    move._resolved = true;
    if (move._frozenSkip) {
      return _record(
        BattleImpact(
          targetsPlayer: move.isHero,
          message: '${move.isHero ? '你' : enemy.name}受到霜縛，這次無法行動。',
        ),
      );
    }
    if (move.cards.isEmpty) return _resolveUtility(move);
    final hero = move.isHero;
    final p = move.power;
    if (hero) {
      _heroDefense = p.defense;
      _heroBuff = p.buff;
    } else {
      _enemyDefense = p.defense;
      _enemyBuff = p.buff;
    }
    var rawDamage = p.attack;
    var critical = false;
    if (hero) {
      final chance = min(
        50,
        min(35, 5 + player.charm ~/ 5) + equipmentCritical(player),
      );
      critical = random.nextInt(100) < chance;
      if (critical) rawDamage += rawDamage ~/ 2;
      if (enemy.bossStage == 6)
        rawDamage = rawDamage * (100 + finalBossWeaponBonus(player)) ~/ 100;
    }
    final reduction = hero
        ? _enemyDefense
        : _heroDefense + equipmentDefense(player);
    final damage = min(hero ? enemyHp : hp, max(0, rawDamage - reduction));
    // Even a fully blocked damaging attack consumes the retained defense.
    if (hero) {
      enemyHp -= damage;
      _enemyDefense = 0;
    } else {
      hp -= damage;
      _heroDefense = 0;
    }
    final healing = min(p.healing, hero ? maxHp - hp : enemy.hp - enemyHp);
    if (hero)
      hp += healing;
    else
      enemyHp += healing;
    if (p.frost) {
      if (turnMode) {
        if (hero)
          _enemyTurnFrozen = true;
        else
          _heroTurnFrozen = true;
      } else if (hero) {
        _enemyFreezeMs = CardBattleTuning.freezeDelayMs;
      } else {
        _heroFreezeMs = CardBattleTuning.freezeDelayMs;
      }
    }
    if (enemyHp == 0)
      status = BattleStatus.won;
    else if (hp == 0)
      status = BattleStatus.lost;
    final effects = [
      '造成 $damage 傷害',
      if (p.defense > 0) '保留 ${hero ? _heroDefense : _enemyDefense} 防禦至下次受擊',
      if (healing > 0) '自身 HP +$healing',
      if (p.buff > 0) '下次攻擊 +${p.buff}',
      if (p.frost) turnMode ? '對手暫停一次行動' : '對手行動延後',
    ];
    return _record(
      BattleImpact(
        targetsPlayer: !hero,
        damage: damage,
        healing: healing,
        message:
            '${hero ? '你' : enemy.name}打出${move.label}${critical ? '・會心' : ''}，${effects.join('，')}。',
      ),
    );
  }

  BattleImpact _resolveUtility(CardMove move) {
    if (move.actionCue == BattleAction.potion) {
      final restored = min(CardBattleTuning.potionHealing, maxHp - hp);
      hp += restored;
      return _record(
        BattleImpact(
          targetsPlayer: true,
          healing: restored,
          message: '使用恢復藥，HP +$restored。',
        ),
      );
    }
    if (move.actionCue == BattleAction.ether) {
      // Project adaptation for the existing consumable: exchange one card for
      // a magic modifier and refill the action gauge, without an SP economy.
      var replace = _hand.indexWhere((card) => card.isModifier);
      if (replace < 0) {
        replace = 0;
        for (var i = 1; i < _hand.length; i++) {
          if (_hand[i].attack < _hand[replace].attack) replace = i;
        }
      }
      final replacement = _magic(
        CardMagic.values[random.nextInt(CardMagic.values.length)],
        false,
      );
      _hand[replace] = replacement;
      _heroGaugeMs = heroIntervalMs;
      return _record(
        BattleImpact(
          targetsPlayer: true,
          message: '使用專注飲，換入${replacement.name}，行動槽回滿。',
        ),
      );
    }
    final escaped = random.nextInt(100) < CardBattleTuning.fleePercent;
    if (escaped) status = BattleStatus.escaped;
    return _record(
      BattleImpact(
        targetsPlayer: true,
        message: escaped ? '成功撤退，保留實力。' : '撤退失敗，等待行動槽恢復。',
      ),
    );
  }

  BattleImpact _record(BattleImpact impact) {
    message = impact.message;
    return impact;
  }

  /// Cannot finish before contact, and cannot accidentally unlock a newer move.
  bool finishMove(CardMove move) {
    if (!identical(_pendingMove, move) || !move._resolved) return false;
    _pendingMove = null;
    if (active && turnMode) {
      _heroTurn = !move.isHero;
      _heroGaugeMs = _heroTurn ? heroIntervalMs : 0;
      _enemyGaugeMs = _heroTurn ? 0 : enemyIntervalMs;
    }
    return true;
  }

  int get resultMoney => active
      ? 0
      : timedOut
      ? max(
          CardBattleTuning.minimumConsolationMoney,
          enemy.reward ~/ CardBattleTuning.consolationMoneyDivisor,
        )
      : switch (status) {
          BattleStatus.won => enemy.reward,
          BattleStatus.lost => enemy.isBoss ? 0 : -min(100, player.money),
          _ => 0,
        };

  @override
  int get earnedExperience => timedOut
      ? max(
          CardBattleTuning.minimumConsolationExperience,
          enemy.experience ~/ CardBattleTuning.consolationExperienceDivisor,
        )
      : super.earnedExperience;

  @override
  StatDelta? claim() {
    if (active || _pendingMove != null || _cardClaimed) return null;
    _cardClaimed = true;
    if (timedOut)
      return StatDelta(
        money: resultMoney,
        stamina: enemy.isBoss ? 2 : 0,
        intelligence: enemy.isBoss ? 2 : 0,
      );
    return super.claim();
  }

  // Do not let callers accidentally enter the legacy direct-action engine.
  // Card gameplay and tests use playCards/useUtility + resolveMove/finishMove.
  @override
  bool canUse(BattleAction action) => canUseUtility(action);
  @override
  BattleImpact? playerAct(BattleAction action) => null;
  @override
  BattleImpact? enemyAct() => null;
  @override
  void act(BattleAction action) =>
      throw UnsupportedError('Use card moves and their contact/finish phases');

  List<BattleCard> _initialCards(
    List<BattleCard>? provided,
    int size,
    bool foe,
  ) {
    if (provided != null) {
      if (provided.length > size ||
          provided.map((c) => c.id).toSet().length != provided.length ||
          provided.any(
            (c) =>
                c.id.isEmpty ||
                c.attack < 0 ||
                c.defense < 0 ||
                c.power < 0 ||
                (c.family == CardFamily.magic) != (c.magic != null),
          )) {
        throw ArgumentError('Invalid initial card hand');
      }
      _issuedCardIds.addAll(provided.map((card) => card.id));
      final result = List<BattleCard>.of(provided);
      _refill(result, size, foe);
      return result;
    }
    // A readable opening: a same-family pair, two alternatives, one modifier.
    final cards = [
      _weapon(CardFamily.blade, 0, foe),
      _weapon(CardFamily.blade, 1, foe),
      if (size >= 4) _weapon(CardFamily.shield, 0, foe),
      _weapon(CardFamily.staff, 0, foe),
      if (size >= 5)
        _magic(CardMagic.values[random.nextInt(CardMagic.values.length)], foe),
    ];
    return cards.take(size).toList();
  }

  void _refill(List<BattleCard> cards, int size, bool foe) {
    while (cards.length < size) {
      final needsWeapon =
          cards.isEmpty ||
          (cards.length == size - 1 && cards.every((c) => c.isModifier));
      // 25% modifiers, otherwise evenly drawn original weapon faces.
      BattleCard next;
      if (!needsWeapon && random.nextInt(4) == 0) {
        next = _magic(
          CardMagic.values[random.nextInt(CardMagic.values.length)],
          foe,
        );
      } else {
        next = _weapon(
          CardFamily.values[random.nextInt(3)],
          random.nextInt(2),
          foe,
        );
      }
      // Injectable test hands may use generated-looking IDs.
      while (cards.any((c) => c.id == next.id)) {
        next = BattleCard(
          id: _nextId(foe),
          name: next.name,
          family: next.family,
          attack: next.attack,
          defense: next.defense,
          magic: next.magic,
          power: next.power,
        );
      }
      cards.add(next);
    }
    if (cards.every((c) => c.isModifier)) {
      cards[cards.length - 1] = _weapon(CardFamily.blade, 0, foe);
    }
  }

  String _nextId(bool foe) {
    String id;
    do {
      id = '${foe ? 'enemy' : 'hero'}_card_${++_cardSerial}';
    } while (!_issuedCardIds.add(id));
    return id;
  }

  BattleCard _weapon(CardFamily family, int variant, bool foe) {
    final (name, attack, defense) = switch (family) {
      CardFamily.blade => variant == 0 ? ('晨光刃', 12, 3) : ('迴風刃', 9, 5),
      CardFamily.shield => variant == 0 ? ('岩紋盾', 5, 16) : ('葉脈盾', 7, 12),
      CardFamily.staff => variant == 0 ? ('星芽杖', 10, 5) : ('流螢杖', 8, 7),
      CardFamily.magic => throw ArgumentError('A magic card is not a weapon'),
    };
    return BattleCard(
      id: _nextId(foe),
      name: name,
      family: family,
      attack: attack,
      defense: defense,
    );
  }

  BattleCard _magic(CardMagic magic, bool foe) {
    final (name, power) = switch (magic) {
      CardMagic.damage => ('焰星印', 20),
      CardMagic.defense => ('晶壁印', 35),
      CardMagic.buff => ('昂揚印', CardBattleTuning.buffPower),
      CardMagic.heal => ('甘露印', 24),
      CardMagic.frost => ('霜環印', 1),
    };
    return BattleCard(
      id: _nextId(foe),
      name: name,
      family: CardFamily.magic,
      magic: magic,
      power: power,
    );
  }
}
