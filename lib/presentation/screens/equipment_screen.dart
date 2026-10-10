import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/player.dart';
import '../../domain/models/shop_item.dart';
import '../art/atlas_portrait.dart';
import '../art/equipment_layers.dart';

String slotLabel(EquipmentSlot s)=>switch(s){EquipmentSlot.weapon=>'武器',EquipmentSlot.armor=>'防具',EquipmentSlot.accessory=>'飾品'};
IconData slotIcon(EquipmentSlot s)=>switch(s){EquipmentSlot.weapon=>Icons.flash_on,EquipmentSlot.armor=>Icons.shield_outlined,EquipmentSlot.accessory=>Icons.diamond_outlined};
class EquipmentScreen extends StatefulWidget {
  final Player player;
  final String jobTitle;
  final Future<Player> Function(String id,EquipmentSlot slot) onEquip;
  const EquipmentScreen({super.key,required this.player,required this.jobTitle,required this.onEquip});
  @override
  State<EquipmentScreen> createState()=>_EquipmentScreenState();
}
class _EquipmentScreenState extends State<EquipmentScreen> {
  late Player player=widget.player;
  EquipmentSlot slot=EquipmentSlot.weapon;
  bool busy=false;
  Future<void> equip(String id) async {
    if(busy)return;
    setState(()=>busy=true);
    try {
      final updated=await widget.onEquip(id,slot);
      if(mounted)setState(()=>player=updated);
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('換裝未完成：$e')));
    } finally {if(mounted)setState(()=>busy=false);}
  }
  String change(int n)=>n>0?'+$n':'$n';
  String comparison(ShopItem next) {
    final currentId=equippedId(player,slot);
    final current=currentId=='none'?null:shopById(currentId);
    return '更換後差異：攻擊 ${change(next.attack-(current?.attack??0))} · 魔法 ${change(next.magic-(current?.magic??0))}\n'
      'HP ${change(next.hp-(current?.hp??0))} · 減傷 ${change(next.defense-(current?.defense??0))} · 會心 ${change(next.critical-(current?.critical??0))} 個百分點';
  }
  @override
  Widget build(BuildContext context) {
    final owned=shopCatalog.where((i)=>i.slot==slot && (player.inventory[i.id]??0)>0).toList();
    return PopScope(canPop:!busy,child:Scaffold(
      appBar:AppBar(title:const Text('人物裝備'),leading:BackButton(onPressed:busy?null:()=>Navigator.pop(context))),
      body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:960),child:ListView(
        padding:const EdgeInsets.all(20),children:[
          Card(child:Padding(padding:const EdgeInsets.all(18),child:Wrap(spacing:24,runSpacing:16,crossAxisAlignment:WrapCrossAlignment.center,children:[
            Container(width:150,height:180,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFE4D5B5),Color(0xFFF9F2E3)]),borderRadius:BorderRadius.circular(20)),
              child:CareerPortrait(equipment:EquipmentLook.fromPlayer(player),jobId:player.jobId,gender:player.gender,width:150,height:180)),
            Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${player.displayName} · ${widget.jobTitle}',style:Theme.of(context).textTheme.titleLarge),
              Text('Lv.${player.level}　金錢 \$${player.money}'),
              const SizedBox(height:12),
              Text('最大 HP：${60+math.min(player.stamina,200)*2+equipmentHp(player)}'),
              Text('裝備攻擊 +${equipmentAttack(player)} · 魔法 +${equipmentMagic(player)}'),
              Text('裝備減傷 ${equipmentDefense(player)} · 會心 +${equipmentCritical(player)} 個百分點'),
              Text('恢復藥 ${player.inventory['potion']??0} · 專注飲 ${player.inventory['ether']??0}'),
            ]),
          ]))),
          const SizedBox(height:16),
          Wrap(spacing:8,runSpacing:8,children:[for(final s in EquipmentSlot.values)
            ChoiceChip(avatar:Icon(slotIcon(s),size:18),label:Text('${slotLabel(s)}：${weaponName(equippedId(player,s))}'),selected:slot==s,
              onSelected:busy?null:(_)=>setState(()=>slot=s))]),
          const SizedBox(height:12),
          if(busy)const LinearProgressIndicator(),
          if(equippedId(player,slot)!='none')Align(alignment:Alignment.centerLeft,
            child:OutlinedButton(onPressed:busy?null:()=>equip('none'),child:Text('卸下${slotLabel(slot)}'))),
          if(owned.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('尚未持有此類裝備。\n走到第 6 或 16 格商店街購買，之後可在這裡自由換裝。')),
          for(final item in owned) Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Icon(slotIcon(slot)),const SizedBox(width:10),Expanded(child:Text(item.name,style:Theme.of(context).textTheme.titleMedium))]),
            const SizedBox(height:8),Text(item.description),
            if(equippedId(player,slot)!=item.id)Text(comparison(item),style:const TextStyle(height:1.6,color:Color(0xFF617361))),
            const SizedBox(height:8),FilledButton(onPressed:busy||equippedId(player,slot)==item.id?null:()=>equip(item.id),
              child:Text(equippedId(player,slot)==item.id?'已裝備':'裝備')),
          ]))),
          const Padding(padding:EdgeInsets.symmetric(vertical:18),child:Text('每個欄位可裝備一件。加成只套用於戰鬥，不改變轉職用的基礎屬性。武器、防具與飾品即時顯示於角色，卸下恢復職業服裝。')),
        ]))),
    ));
  }
}
