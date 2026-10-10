import 'player.dart';

/// Current profession determines proficiency; changing careers does not destroy gear.
enum EquipmentFamily { martial, arcane, ranger, craft, arts, care }

extension EquipmentFamilyLabel on EquipmentFamily {
  String get label => switch (this) {
    EquipmentFamily.martial => '武鬥系',
    EquipmentFamily.arcane => '學術魔法系',
    EquipmentFamily.ranger => '遊獵系',
    EquipmentFamily.craft => '工藝商業系',
    EquipmentFamily.arts => '表演藝術系',
    EquipmentFamily.care => '守護醫療系',
  };
}

Set<EquipmentFamily> equipmentFamilies(String jobId) => switch (jobId) {
  'warrior' || 'warlord' => {EquipmentFamily.martial},
  'hero' => {EquipmentFamily.martial, EquipmentFamily.ranger},
  'guardian' || 'paladin' => {EquipmentFamily.martial, EquipmentFamily.care},
  'scholar' || 'mage' || 'archmage' || 'sage' => {EquipmentFamily.arcane},
  'alchemist' => {EquipmentFamily.arcane, EquipmentFamily.craft},
  'mentor' => {EquipmentFamily.arcane, EquipmentFamily.care},
  'ranger' ||
  'ranger_master' ||
  'beast_tamer' ||
  'dragon_tamer' => {EquipmentFamily.ranger},
  'engineer' ||
  'merchant' ||
  'president' ||
  'chef' ||
  'gourmet_master' => {EquipmentFamily.craft},
  'artist' ||
  'bard' ||
  'maestro' ||
  'dancer' ||
  'celestial_dancer' => {EquipmentFamily.arts},
  'doctor' => {EquipmentFamily.care},
  // Root and introductory careers use universal equipment until specializing.
  _ => <EquipmentFamily>{},
};

enum ShopKind { training, weapon, armor, accessory, item }

enum EquipmentSlot { weapon, armor, accessory }

class ShopItem {
  final String id, name, description;
  final int price,
      attack,
      magic,
      defense,
      hp,
      critical,
      unlockStage,
      finalBossPercent;
  final ShopKind kind;
  final Set<EquipmentFamily> families;
  final String? artId;
  String get visualId => artId ?? id;
  String get classRequirement => families.isEmpty
      ? '全職業通用'
      : '職業限定：${families.map((f) => f.label).join("／")}';
  bool allowsJob(String jobId) =>
      families.isEmpty || families.any(equipmentFamilies(jobId).contains);
  final StatDelta effects;
  const ShopItem(
    this.id,
    this.name,
    this.price,
    this.kind,
    this.description, {
    this.families = const {},
    this.artId,
    this.effects = const StatDelta(),
    this.attack = 0,
    this.magic = 0,
    this.defense = 0,
    this.hp = 0,
    this.critical = 0,
    this.unlockStage = 1,
    this.finalBossPercent = 0,
  });
}

extension ShopEquipment on ShopItem {
  bool get isEquipment =>
      [ShopKind.weapon, ShopKind.armor, ShopKind.accessory].contains(kind);
  EquipmentSlot? get slot => switch (kind) {
    ShopKind.weapon => EquipmentSlot.weapon,
    ShopKind.armor => EquipmentSlot.armor,
    ShopKind.accessory => EquipmentSlot.accessory,
    _ => null,
  };
}

String equippedId(Player p, EquipmentSlot slot) => switch (slot) {
  EquipmentSlot.weapon => p.weaponId,
  EquipmentSlot.armor => p.armorId,
  EquipmentSlot.accessory => p.accessoryId,
};

/// Shared by UI, service, combat, and save migration so restrictions cannot drift.
String? equipmentLockReason(Player p, ShopItem item) {
  final reasons = <String>[];
  if (p.currentStage < item.unlockStage)
    reasons.add('通關第 ${item.unlockStage - 1} 關後解鎖');
  if (!item.allowsJob(p.jobId)) reasons.add(item.classRequirement);
  return reasons.isEmpty ? null : reasons.join('；');
}

Iterable<ShopItem> equippedItems(Player p) sync* {
  for (final slot in EquipmentSlot.values) {
    final id = equippedId(p, slot);
    final matches = shopCatalog.where((i) => i.id == id && i.slot == slot);
    if (matches.isNotEmpty && equipmentLockReason(p, matches.first) == null)
      yield matches.first;
  }
}

/// Old saves and career changes keep all purchased goods, but remove unusable slots.
Player sanitizeEquipment(Player p) {
  String valid(EquipmentSlot slot) {
    final id = equippedId(p, slot);
    final matches = shopCatalog.where((i) => i.id == id && i.slot == slot);
    return matches.isNotEmpty && equipmentLockReason(p, matches.first) == null
        ? id
        : 'none';
  }

  return p.copyWith(
    weaponId: valid(EquipmentSlot.weapon),
    armorId: valid(EquipmentSlot.armor),
    accessoryId: valid(EquipmentSlot.accessory),
  );
}

int equipmentAttack(Player p) =>
    equippedItems(p).fold(0, (a, i) => a + i.attack);
int equipmentMagic(Player p) => equippedItems(p).fold(0, (a, i) => a + i.magic);
int equipmentDefense(Player p) =>
    equippedItems(p).fold(0, (a, i) => a + i.defense);
int equipmentHp(Player p) => equippedItems(p).fold(0, (a, i) => a + i.hp);
int equipmentCritical(Player p) =>
    equippedItems(p).fold(0, (a, i) => a + i.critical);
const shopCatalog = [
  ShopItem(
    'train_stamina',
    '體能課程',
    250,
    ShopKind.training,
    '永久體力 +5',
    effects: StatDelta(stamina: 5),
  ),
  ShopItem(
    'train_intelligence',
    '研習課程',
    250,
    ShopKind.training,
    '永久智力 +5',
    effects: StatDelta(intelligence: 5),
  ),
  ShopItem(
    'train_charm',
    '表達課程',
    250,
    ShopKind.training,
    '永久魅力 +5',
    effects: StatDelta(charm: 5),
  ),
  ShopItem(
    'train_morality',
    '社區服務計畫',
    300,
    ShopKind.training,
    '投入資源，永久道德 +5',
    effects: StatDelta(morality: 5),
  ),
  ShopItem('sword', '精鋼短劍', 600, ShopKind.weapon, '普通攻擊基礎傷害 +8', attack: 8),
  ShopItem('staff', '星晶法杖', 700, ShopKind.weapon, '魔法基礎傷害 +10', magic: 10),
  ShopItem(
    'spellblade',
    '符文劍',
    1100,
    ShopKind.weapon,
    '普通攻擊 +6、魔法 +6',
    attack: 6,
    magic: 6,
  ),
  ShopItem(
    'longbow',
    '翡翠長弓',
    950,
    ShopKind.weapon,
    '普通攻擊 +10、會心率 +5 個百分點',
    attack: 10,
    critical: 5,
  ),
  ShopItem(
    'dawnblade',
    '破曉巨劍',
    2400,
    ShopKind.weapon,
    '第六關解鎖｜攻擊 +32、魔法 +10；對最終魔王傷害 +25%',
    attack: 32,
    magic: 10,
    unlockStage: 6,
    finalBossPercent: 25,
    families: {EquipmentFamily.martial},
  ),
  ShopItem(
    'astral_staff',
    '星界法杖',
    2600,
    ShopKind.weapon,
    '第六關解鎖｜攻擊 +8、魔法 +38；對最終魔王傷害 +25%',
    attack: 8,
    magic: 38,
    unlockStage: 6,
    finalBossPercent: 25,
    families: {EquipmentFamily.arcane, EquipmentFamily.care},
  ),
  ShopItem(
    'fate_bow',
    '命運長弓',
    2500,
    ShopKind.weapon,
    '第六關解鎖｜攻擊 +26、魔法 +16、會心 +12 個百分點；對最終魔王傷害 +20%',
    attack: 26,
    magic: 16,
    critical: 12,
    unlockStage: 6,
    finalBossPercent: 20,
    families: {EquipmentFamily.ranger, EquipmentFamily.arts},
  ),
  ShopItem(
    'ember_spear',
    '焰羽長槍',
    1250,
    ShopKind.weapon,
    '第二關｜攻擊 +15、會心 +3 個百分點',
    attack: 15,
    critical: 3,
    unlockStage: 2,
    families: {EquipmentFamily.martial, EquipmentFamily.ranger},
  ),
  ShopItem(
    'frost_wand',
    '霜月魔杖',
    1400,
    ShopKind.weapon,
    '第三關｜魔法 +19、最大 HP +8',
    magic: 19,
    hp: 8,
    unlockStage: 3,
    families: {EquipmentFamily.arcane, EquipmentFamily.care},
  ),
  ShopItem(
    'thunder_hammer',
    '雷霆戰鎚',
    1850,
    ShopKind.weapon,
    '第四關｜攻擊 +24、減傷 +2',
    attack: 24,
    defense: 2,
    unlockStage: 4,
    families: {EquipmentFamily.martial, EquipmentFamily.craft},
  ),
  ShopItem(
    'moon_blades',
    '月影雙刃',
    1950,
    ShopKind.weapon,
    '第五關｜攻擊 +19、魔法 +8、會心 +10 個百分點',
    attack: 19,
    magic: 8,
    critical: 10,
    unlockStage: 5,
    families: {EquipmentFamily.ranger, EquipmentFamily.arts},
  ),
  ShopItem(
    'ranger_cloak',
    '森語斗篷',
    700,
    ShopKind.armor,
    '第二關｜減傷 +3、會心 +4 個百分點',
    defense: 3,
    critical: 4,
    unlockStage: 2,
    families: {EquipmentFamily.ranger},
  ),
  ShopItem(
    'scholar_coat',
    '秘典學者服',
    1100,
    ShopKind.armor,
    '第三關｜魔法 +9、減傷 +3、最大 HP +15',
    magic: 9,
    defense: 3,
    hp: 15,
    unlockStage: 3,
    families: {EquipmentFamily.arcane, EquipmentFamily.care},
  ),
  ShopItem(
    'flame_armor',
    '赤焰戰甲',
    1750,
    ShopKind.armor,
    '第四關｜攻擊 +6、減傷 +8、最大 HP +35',
    attack: 6,
    defense: 8,
    hp: 35,
    unlockStage: 4,
    families: {EquipmentFamily.martial, EquipmentFamily.craft},
  ),
  ShopItem(
    'astral_robe',
    '星穹聖袍',
    2050,
    ShopKind.armor,
    '第五關｜魔法 +15、減傷 +5、最大 HP +25',
    magic: 15,
    defense: 5,
    hp: 25,
    unlockStage: 5,
    families: {EquipmentFamily.arcane, EquipmentFamily.arts},
  ),
  ShopItem(
    'ruby_ring',
    '赤心戒指',
    650,
    ShopKind.accessory,
    '第二關｜攻擊 +5、最大 HP +10',
    attack: 5,
    hp: 10,
    unlockStage: 2,
    families: {EquipmentFamily.martial, EquipmentFamily.craft},
  ),
  ShopItem(
    'sapphire_pendant',
    '深藍月墜',
    1000,
    ShopKind.accessory,
    '第三關｜魔法 +10、最大 HP +12',
    magic: 10,
    hp: 12,
    unlockStage: 3,
    families: {EquipmentFamily.arcane, EquipmentFamily.care},
  ),
  ShopItem(
    'guardian_brooch',
    '守誓胸章',
    1300,
    ShopKind.accessory,
    '第四關｜減傷 +5、最大 HP +30',
    defense: 5,
    hp: 30,
    unlockStage: 4,
    families: {EquipmentFamily.martial, EquipmentFamily.care},
  ),
  ShopItem(
    'wing_charm',
    '天翼護符',
    1600,
    ShopKind.accessory,
    '第五關｜攻擊 +5、魔法 +5、會心 +12 個百分點',
    attack: 5,
    magic: 5,
    critical: 12,
    unlockStage: 5,
    families: {EquipmentFamily.ranger, EquipmentFamily.arts},
  ),
  ShopItem(
    'coat',
    '旅行皮甲',
    450,
    ShopKind.armor,
    '減傷 +3、最大 HP +15',
    defense: 3,
    hp: 15,
  ),
  ShopItem(
    'robe',
    '星紋法袍',
    850,
    ShopKind.armor,
    '減傷 +2、魔法 +5、最大 HP +10',
    defense: 2,
    magic: 5,
    hp: 10,
  ),
  ShopItem(
    'plate',
    '守護鎧甲',
    1300,
    ShopKind.armor,
    '減傷 +7、最大 HP +30',
    defense: 7,
    hp: 30,
  ),
  ShopItem('ring', '靈光戒指', 500, ShopKind.accessory, '魔法 +5', magic: 5),
  ShopItem('pendant', '生命項鍊', 550, ShopKind.accessory, '最大 HP +25', hp: 25),
  ShopItem(
    'charm',
    '幸運徽章',
    750,
    ShopKind.accessory,
    '普通攻擊 +3、會心率 +8 個百分點',
    attack: 3,
    critical: 8,
  ),
  ShopItem(
    'practice_blade',
    '練習木劍',
    180,
    ShopKind.weapon,
    '攻擊 +3',
    attack: 3,
    unlockStage: 1,
    artId: 'sword',
  ),
  ShopItem(
    'travel_vest',
    '行旅布衣',
    160,
    ShopKind.armor,
    '減傷 +1、最大 HP +5',
    defense: 1,
    hp: 5,
    unlockStage: 1,
    artId: 'coat',
  ),
  ShopItem(
    'woven_token',
    '編織平安結',
    140,
    ShopKind.accessory,
    '最大 HP +6',
    hp: 6,
    unlockStage: 1,
    artId: 'pendant',
  ),
  ShopItem(
    'duelist_sabre',
    '決鬥軍刀',
    1000,
    ShopKind.weapon,
    '攻擊 +13、會心 +4%',
    attack: 13,
    critical: 4,
    families: {EquipmentFamily.martial},
    unlockStage: 2,
    artId: 'sword',
  ),
  ShopItem(
    'bastion_mail',
    '堡壘重甲',
    1650,
    ShopKind.armor,
    '減傷 +9、最大 HP +20',
    defense: 9,
    hp: 20,
    families: {EquipmentFamily.martial},
    unlockStage: 4,
    artId: 'plate',
  ),
  ShopItem(
    'war_banner',
    '戰意勳章',
    2100,
    ShopKind.accessory,
    '攻擊 +13、減傷 +3',
    attack: 13,
    defense: 3,
    families: {EquipmentFamily.martial},
    unlockStage: 6,
    artId: 'guardian_brooch',
  ),
  ShopItem(
    'rune_sceptre',
    '秘文權杖',
    1050,
    ShopKind.weapon,
    '魔法 +15',
    magic: 15,
    families: {EquipmentFamily.arcane},
    unlockStage: 2,
    artId: 'staff',
  ),
  ShopItem(
    'rune_mantle',
    '奧文披衣',
    1550,
    ShopKind.armor,
    '魔法 +12、減傷 +4',
    magic: 12,
    defense: 4,
    families: {EquipmentFamily.arcane},
    unlockStage: 4,
    artId: 'robe',
  ),
  ShopItem(
    'sage_sigil',
    '賢者印記',
    2200,
    ShopKind.accessory,
    '魔法 +18、最大 HP +15',
    magic: 18,
    hp: 15,
    families: {EquipmentFamily.arcane},
    unlockStage: 6,
    artId: 'ring',
  ),
  ShopItem(
    'trail_bow',
    '獵風短弓',
    1100,
    ShopKind.weapon,
    '攻擊 +12、會心 +7%',
    attack: 12,
    critical: 7,
    families: {EquipmentFamily.ranger},
    unlockStage: 2,
    artId: 'longbow',
  ),
  ShopItem(
    'beast_hide',
    '靈獸獵衣',
    1550,
    ShopKind.armor,
    '最大 HP +32、減傷 +4、會心 +4%',
    hp: 32,
    defense: 4,
    critical: 4,
    families: {EquipmentFamily.ranger},
    unlockStage: 4,
    artId: 'ranger_cloak',
  ),
  ShopItem(
    'dragon_fang',
    '龍牙護符',
    2200,
    ShopKind.accessory,
    '攻擊 +10、最大 HP +25、會心 +8%',
    attack: 10,
    hp: 25,
    critical: 8,
    families: {EquipmentFamily.ranger},
    unlockStage: 6,
    artId: 'charm',
  ),
  ShopItem(
    'forge_hammer',
    '匠心重鎚',
    1050,
    ShopKind.weapon,
    '攻擊 +11、魔法 +5、減傷 +1',
    attack: 11,
    magic: 5,
    defense: 1,
    families: {EquipmentFamily.craft},
    unlockStage: 2,
    artId: 'thunder_hammer',
  ),
  ShopItem(
    'guild_apron',
    '公會工裝',
    1500,
    ShopKind.armor,
    '攻擊 +7、減傷 +5、最大 HP +20',
    attack: 7,
    defense: 5,
    hp: 20,
    families: {EquipmentFamily.craft},
    unlockStage: 4,
    artId: 'coat',
  ),
  ShopItem(
    'master_seal',
    '宗師金印',
    2100,
    ShopKind.accessory,
    '攻擊 +9、魔法 +9、減傷 +2',
    attack: 9,
    magic: 9,
    defense: 2,
    families: {EquipmentFamily.craft},
    unlockStage: 6,
    artId: 'ruby_ring',
  ),
  ShopItem(
    'rhythm_blade',
    '音律細劍',
    1050,
    ShopKind.weapon,
    '攻擊 +8、魔法 +8、會心 +4%',
    attack: 8,
    magic: 8,
    critical: 4,
    families: {EquipmentFamily.arts},
    unlockStage: 2,
    artId: 'spellblade',
  ),
  ShopItem(
    'stage_silk',
    '流光舞衣',
    1550,
    ShopKind.armor,
    '魔法 +8、減傷 +3、會心 +8%',
    magic: 8,
    defense: 3,
    critical: 8,
    families: {EquipmentFamily.arts},
    unlockStage: 4,
    artId: 'astral_robe',
  ),
  ShopItem(
    'encore_jewel',
    '安可星鑽',
    2150,
    ShopKind.accessory,
    '魔法 +10、會心 +14%',
    magic: 10,
    critical: 14,
    families: {EquipmentFamily.arts},
    unlockStage: 6,
    artId: 'wing_charm',
  ),
  ShopItem(
    'mercy_staff',
    '慈心法杖',
    1050,
    ShopKind.weapon,
    '魔法 +11、最大 HP +20',
    magic: 11,
    hp: 20,
    families: {EquipmentFamily.care},
    unlockStage: 2,
    artId: 'staff',
  ),
  ShopItem(
    'sanctuary_coat',
    '庇護長衣',
    1600,
    ShopKind.armor,
    '減傷 +6、最大 HP +40',
    defense: 6,
    hp: 40,
    families: {EquipmentFamily.care},
    unlockStage: 4,
    artId: 'scholar_coat',
  ),
  ShopItem(
    'oath_pendant',
    '生命誓墜',
    2150,
    ShopKind.accessory,
    '魔法 +8、減傷 +4、最大 HP +35',
    magic: 8,
    defense: 4,
    hp: 35,
    families: {EquipmentFamily.care},
    unlockStage: 6,
    artId: 'pendant',
  ),
  ShopItem('potion', '恢復藥', 80, ShopKind.item, '戰鬥中恢復 40 HP'),
  ShopItem('ether', '專注飲', 120, ShopKind.item, '卡牌戰：換入一張魔法牌，行動條回滿'),
];
ShopItem shopById(String id) => shopCatalog.firstWhere(
  (s) => s.id == id,
  orElse: () => throw ArgumentError('商品不存在：$id'),
);
int weaponAttack(String id) => id == 'none' ? 0 : shopById(id).attack;
int weaponMagic(String id) => id == 'none' ? 0 : shopById(id).magic;
String weaponName(String id) => id == 'none' ? '未裝備' : shopById(id).name;

int finalBossWeaponBonus(Player p) =>
    equippedItems(p)
        .where((i) => i.kind == ShopKind.weapon)
        .fold(0, (total, item) => total + item.finalBossPercent);
