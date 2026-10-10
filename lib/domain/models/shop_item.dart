import 'player.dart';
enum ShopKind { training, weapon, armor, accessory, item }
enum EquipmentSlot { weapon, armor, accessory }
class ShopItem {
  final String id,name,description;
  final int price,attack,magic,defense,hp,critical,unlockStage,finalBossPercent;
  final ShopKind kind;
  final StatDelta effects;
  const ShopItem(this.id,this.name,this.price,this.kind,this.description,
    {this.effects=const StatDelta(),this.attack=0,this.magic=0,this.defense=0,this.hp=0,this.critical=0,this.unlockStage=1,this.finalBossPercent=0});
}
extension ShopEquipment on ShopItem {
  bool get isEquipment => [ShopKind.weapon,ShopKind.armor,ShopKind.accessory].contains(kind);
  EquipmentSlot? get slot => switch(kind) {
    ShopKind.weapon=>EquipmentSlot.weapon, ShopKind.armor=>EquipmentSlot.armor,
    ShopKind.accessory=>EquipmentSlot.accessory, _=>null,
  };
}
String equippedId(Player p,EquipmentSlot slot)=>switch(slot){
 EquipmentSlot.weapon=>p.weaponId,EquipmentSlot.armor=>p.armorId,EquipmentSlot.accessory=>p.accessoryId,
};
Iterable<ShopItem> equippedItems(Player p)=>EquipmentSlot.values.map((s)=>equippedId(p,s)).where((id)=>id!='none').map(shopById);
int equipmentAttack(Player p)=>equippedItems(p).fold(0,(a,i)=>a+i.attack);
int equipmentMagic(Player p)=>equippedItems(p).fold(0,(a,i)=>a+i.magic);
int equipmentDefense(Player p)=>equippedItems(p).fold(0,(a,i)=>a+i.defense);
int equipmentHp(Player p)=>equippedItems(p).fold(0,(a,i)=>a+i.hp);
int equipmentCritical(Player p)=>equippedItems(p).fold(0,(a,i)=>a+i.critical);
const shopCatalog=[
  ShopItem('train_stamina','體能課程',250,ShopKind.training,'永久體力 +5',effects:StatDelta(stamina:5)),
  ShopItem('train_intelligence','研習課程',250,ShopKind.training,'永久智力 +5',effects:StatDelta(intelligence:5)),
  ShopItem('train_charm','表達課程',250,ShopKind.training,'永久魅力 +5',effects:StatDelta(charm:5)),
  ShopItem('train_morality','社區服務計畫',300,ShopKind.training,'投入資源，永久道德 +5',effects:StatDelta(morality:5)),
  ShopItem('sword','精鋼短劍',600,ShopKind.weapon,'普通攻擊基礎傷害 +8',attack:8),
  ShopItem('staff','星晶法杖',700,ShopKind.weapon,'魔法基礎傷害 +10',magic:10),
  ShopItem('spellblade','符文劍',1100,ShopKind.weapon,'普通攻擊 +6、魔法 +6',attack:6,magic:6),
  ShopItem('longbow','翡翠長弓',950,ShopKind.weapon,'普通攻擊 +10、會心率 +5 個百分點',attack:10,critical:5),
  ShopItem('dawnblade','破曉巨劍',2400,ShopKind.weapon,'第六關解鎖｜攻擊 +32、魔法 +10；對最終魔王傷害 +25%',attack:32,magic:10,unlockStage:6,finalBossPercent:25),
  ShopItem('astral_staff','星界法杖',2600,ShopKind.weapon,'第六關解鎖｜攻擊 +8、魔法 +38；對最終魔王傷害 +25%',attack:8,magic:38,unlockStage:6,finalBossPercent:25),
  ShopItem('fate_bow','命運長弓',2500,ShopKind.weapon,'第六關解鎖｜攻擊 +26、魔法 +16、會心 +12 個百分點；對最終魔王傷害 +20%',attack:26,magic:16,critical:12,unlockStage:6,finalBossPercent:20),
  ShopItem('ember_spear','焰羽長槍',1250,ShopKind.weapon,'第二關｜攻擊 +15、會心 +3 個百分點',attack:15,critical:3,unlockStage:2),
  ShopItem('frost_wand','霜月魔杖',1400,ShopKind.weapon,'第三關｜魔法 +19、最大 HP +8',magic:19,hp:8,unlockStage:3),
  ShopItem('thunder_hammer','雷霆戰鎚',1850,ShopKind.weapon,'第四關｜攻擊 +24、減傷 +2',attack:24,defense:2,unlockStage:4),
  ShopItem('moon_blades','月影雙刃',1950,ShopKind.weapon,'第五關｜攻擊 +19、魔法 +8、會心 +10 個百分點',attack:19,magic:8,critical:10,unlockStage:5),
  ShopItem('ranger_cloak','森語斗篷',700,ShopKind.armor,'第二關｜減傷 +3、會心 +4 個百分點',defense:3,critical:4,unlockStage:2),
  ShopItem('scholar_coat','秘典學者服',1100,ShopKind.armor,'第三關｜魔法 +9、減傷 +3、最大 HP +15',magic:9,defense:3,hp:15,unlockStage:3),
  ShopItem('flame_armor','赤焰戰甲',1750,ShopKind.armor,'第四關｜攻擊 +6、減傷 +8、最大 HP +35',attack:6,defense:8,hp:35,unlockStage:4),
  ShopItem('astral_robe','星穹聖袍',2050,ShopKind.armor,'第五關｜魔法 +15、減傷 +5、最大 HP +25',magic:15,defense:5,hp:25,unlockStage:5),
  ShopItem('ruby_ring','赤心戒指',650,ShopKind.accessory,'第二關｜攻擊 +5、最大 HP +10',attack:5,hp:10,unlockStage:2),
  ShopItem('sapphire_pendant','深藍月墜',1000,ShopKind.accessory,'第三關｜魔法 +10、最大 HP +12',magic:10,hp:12,unlockStage:3),
  ShopItem('guardian_brooch','守誓胸章',1300,ShopKind.accessory,'第四關｜減傷 +5、最大 HP +30',defense:5,hp:30,unlockStage:4),
  ShopItem('wing_charm','天翼護符',1600,ShopKind.accessory,'第五關｜攻擊 +5、魔法 +5、會心 +12 個百分點',attack:5,magic:5,critical:12,unlockStage:5),
  ShopItem('coat','旅行皮甲',450,ShopKind.armor,'減傷 +3、最大 HP +15',defense:3,hp:15),
  ShopItem('robe','星紋法袍',850,ShopKind.armor,'減傷 +2、魔法 +5、最大 HP +10',defense:2,magic:5,hp:10),
  ShopItem('plate','守護鎧甲',1300,ShopKind.armor,'減傷 +7、最大 HP +30',defense:7,hp:30),
  ShopItem('ring','靈光戒指',500,ShopKind.accessory,'魔法 +5',magic:5),
  ShopItem('pendant','生命項鍊',550,ShopKind.accessory,'最大 HP +25',hp:25),
  ShopItem('charm','幸運徽章',750,ShopKind.accessory,'普通攻擊 +3、會心率 +8 個百分點',attack:3,critical:8),
  ShopItem('potion','恢復藥',80,ShopKind.item,'戰鬥中恢復 40 HP'),
  ShopItem('ether','專注飲',120,ShopKind.item,'戰鬥中補滿 SP'),
];
ShopItem shopById(String id)=>shopCatalog.firstWhere((s)=>s.id==id,
  orElse:()=>throw ArgumentError('商品不存在：$id'));
int weaponAttack(String id)=>id=='none'?0:shopById(id).attack;
int weaponMagic(String id)=>id=='none'?0:shopById(id).magic;
String weaponName(String id)=>id=='none'?'未裝備':shopById(id).name;

int finalBossWeaponBonus(Player p)=>p.weaponId=='none'?0:shopById(p.weaponId).finalBossPercent;
