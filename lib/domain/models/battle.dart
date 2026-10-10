import 'dart:math';
import 'player.dart';
import 'job.dart';
import 'shop_item.dart';

enum BattleAction { attack, skill, frost, heal, burst, defend, potion, ether, flee }
enum BattleStatus { active, won, lost, escaped }

class Enemy {
  final int bossStage;
  final String specialName;
  bool get isBoss => bossStage > 0;
  final String id, name, description;
  final int hp, attack, reward, portrait, experience, maxSp, minTier;
  const Enemy({required this.id, required this.name, required this.description,
    required this.hp, required this.attack, required this.reward, required this.portrait,
    this.bossStage = 0, this.specialName = '蓄力重擊', this.experience = 40, this.maxSp = 3, this.minTier = 0});
  factory Enemy.fromJson(Map<String, dynamic> j) {
    for (final key in ['hp', 'attack', 'reward', 'portrait']) {
      if (j[key] is! int || (j[key] as int) < 0) throw FormatException('Invalid enemy $key');
    }
    final bossStage = j['bossStage'] ?? 0;
    if(bossStage is! int || bossStage < 0 || bossStage > 6) throw const FormatException('Invalid boss stage');
    final xp = j['experience'] ?? 40, sp = j['maxSp'] ?? 3;
    final tier = j['minTier'] ?? 0;
    if (tier is! int || tier < 0 || tier > 3) throw const FormatException('Invalid encounter tier');
    if (j['hp'] == 0 || j['portrait'] > 17 || xp is! int || xp < 0 || sp is! int || sp < 1) {
      throw const FormatException('Invalid enemy range');
    }
    return Enemy(bossStage:bossStage, specialName:j['specialName'] as String? ?? '蓄力重擊', id: j['id'] as String, name: j['name'] as String,
      description: j['description'] as String, hp: j['hp'] as int,
      attack: j['attack'] as int, reward: j['reward'] as int, portrait: j['portrait'] as int,
      experience: xp, maxSp: sp, minTier: tier);
  }
}

/// One impact, resolved at the animation's contact frame.
class BattleImpact {
  final bool targetsPlayer;
  final int damage, healing, spRecovered;
  final String message;
  const BattleImpact({required this.targetsPlayer, this.damage = 0,
    this.healing = 0, this.spRecovered = 0, required this.message});
  String get floatingText => damage > 0 ? '-$damage' : healing > 0 ? '+$healing HP'
    : spRecovered > 0 ? '+$spRecovered SP' : message.contains('冰封') ? '冰封' : message.contains('撤退') ? '撤退' : '防禦';
}

/// Each side resolves separately. UI can animate impacts without early counters.
class BattleSession {
  BattleSession(this.player, this.enemy, {Random? random, this.job}) : random = random ?? Random() {
    potions = player.inventory['potion'] ?? 0; ethers = player.inventory['ether'] ?? 0;
    maxHp = 60 + min(player.stamina, 200) * 2 + equipmentHp(player);
    hp = maxHp; enemyHp = enemy.hp;
    enemySp = min(2, enemy.maxSp);
  }
  final Player player;
  final Enemy enemy;
  final Job? job;
  String get skillName => job?.skillName ?? '靈光斬';
  final Random random;
  late final int maxHp;
  late int hp, enemyHp, enemySp;
  static const maxSp = 3;
  int energy = maxSp, round = 0;
  late int potions, ethers;
  bool _frozen = false;
  Map<String,int> get remainingInventory => Map.unmodifiable({...player.inventory,'potion':potions,'ether':ethers});
  BattleStatus status = BattleStatus.active;
  bool _claimed = false, _awaitingEnemy = false, _guarding = false;
  String message = '選擇行動，迎接人生挑戰！';
  bool get active => status == BattleStatus.active;
  bool get enemyFrozen => _frozen;
  bool get awaitingEnemy => _awaitingEnemy;
  int get earnedExperience => status == BattleStatus.won ? enemy.experience : 0;
  bool get finalEnraged => enemy.bossStage == 6 && enemyHp <= enemy.hp ~/ 2;
  String get intent => enemySp >= enemy.maxSp ? enemy.specialName : '普通攻擊（SP +1）';
  bool canUse(BattleAction a) => active && !_awaitingEnemy && (switch (a) {
    BattleAction.skill => energy > 0,
    BattleAction.frost => energy >= 2,
    BattleAction.heal => energy >= 2 && hp < maxHp,
    BattleAction.burst => energy >= 3,
    BattleAction.potion => potions > 0 && hp < maxHp,
    BattleAction.ether => ethers > 0 && energy < maxSp,
    _ => true,
  });

  BattleImpact? playerAct(BattleAction action) {
    if (!canUse(action)) return null;
    round++; _guarding = false;
    late BattleImpact hit;
    if (action == BattleAction.flee) {
      if (random.nextInt(100) < 65) {
        status = BattleStatus.escaped;
        message = '成功撤退，保留實力。';
        return BattleImpact(targetsPlayer: true, message: message);
      }
      hit = const BattleImpact(targetsPlayer: true, message: '撤退失敗！');
    } else if (action == BattleAction.potion) {
      potions--;
      final heal = min(40, maxHp-hp); hp += heal;
      hit = BattleImpact(targetsPlayer: true, healing: heal, message: '使用恢復藥，HP +$heal。');
    } else if (action == BattleAction.ether) {
      ethers--;
      final recovered = maxSp-energy; energy = maxSp;
      hit = BattleImpact(targetsPlayer: true, spRecovered: recovered, message: '使用專注飲，SP +$recovered。');
    } else if (action == BattleAction.heal) {
      energy -= 2;
      final restored=min(maxHp-hp,24+min(player.intelligence,200)~/3+equipmentMagic(player));
      hp+=restored;
      hit=BattleImpact(targetsPlayer:true,healing:restored,message:'生命綻放，HP +$restored。');
    } else if (action == BattleAction.defend) {
      _guarding = true;
      final recovered = energy < maxSp ? 1 : 0; energy += recovered;
      hit = BattleImpact(targetsPlayer: true, spRecovered: recovered, message: '沉著應對：本回合減傷，SP +$recovered。');
    } else {
      final skill = [BattleAction.skill,BattleAction.frost,BattleAction.burst].contains(action);
      if (skill) { energy -= action == BattleAction.frost ? 2 : action == BattleAction.burst ? 3 : 1; } else { energy = min(maxSp, energy+1); }
      var base = skill ? (job?.skillPower(player) ?? 18 + min(player.intelligence,200) ~/ 3)
        : (job?.attackPower(player) ?? 10 + min(player.stamina,200) ~/ 4);
      base += skill ? equipmentMagic(player) : equipmentAttack(player);
      if(action==BattleAction.frost){base=base*7~/10;_frozen=true;}
      if(action==BattleAction.burst)base=base*16~/10;
      final name=action==BattleAction.frost?'冰封束縛':action==BattleAction.burst?'星辰爆發':skillName;
      final critical = random.nextInt(100) < min(50,min(35,5+player.charm ~/ 5)+equipmentCritical(player));
      final rawDamage = base + random.nextInt(5) + (critical ? base ~/ 2 : 0);
      final bonus = enemy.bossStage==6 ? finalBossWeaponBonus(player) : 0;
      final damage = min(enemyHp,rawDamage*(100+bonus)~/100);
      enemyHp -= damage;
      hit = BattleImpact(targetsPlayer: false, damage: damage,
        message: '${skill ? name : "普通攻擊"}${critical ? "・會心" : ""}，造成 $damage 傷害。');
      if (enemyHp == 0) status = BattleStatus.won;
    }
    _awaitingEnemy = active;
    message = hit.message;
    return hit;
  }

  BattleImpact? enemyAct() {
    if (!active || !_awaitingEnemy) return null;
    _awaitingEnemy = false;
    if(_frozen){
      _frozen=false;
      const hit=BattleImpact(targetsPlayer:false,message:'敵人被冰封，跳過一次反擊。');
      message+='\n${hit.message}';return hit;
    }
    final heavy = enemySp >= enemy.maxSp;
    if (heavy) { enemySp = 0; } else { enemySp = min(enemy.maxSp, enemySp+1); }
    final power = enemy.attack + (finalEnraged ? 8 : 0);
    final raw = power + random.nextInt(4) + (heavy ? power : 0);
    final reduced = max(1,raw-equipmentDefense(player));
    final damage = min(hp, _guarding ? max(1,reduced ~/ 3) : reduced);
    hp -= damage; _guarding = false;
    if (hp == 0) status = BattleStatus.lost;
    final hit = BattleImpact(targetsPlayer: true, damage: damage,
      message: '${enemy.name}${heavy ? "使出${enemy.specialName}" : "反擊"}，受到 $damage 傷害。');
    message += '\n${hit.message}';
    return hit;
  }

  // Synchronous convenience for domain tests; screen uses separate phases.
  void act(BattleAction action) {
    if (playerAct(action) != null) enemyAct();
  }
  StatDelta? claim() {
    if (active || _claimed) return null;
    _claimed = true;
    return switch (status) {
      BattleStatus.won => StatDelta(money: enemy.reward, stamina: 3, intelligence: 2, morality: 2),
      BattleStatus.lost => StatDelta(money: -min(100,player.money)),
      _ => const StatDelta(),
    };
  }
}
