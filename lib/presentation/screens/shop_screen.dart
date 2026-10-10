import 'package:flutter/material.dart';
import '../../domain/models/player.dart';
import '../../domain/models/shop_item.dart';
import '../art/equipment_layers.dart';
import '../three_d/models_3d.dart';

class ShopScreen extends StatefulWidget {
  final Player player;
  final Future<Player> Function(String id, bool equip) onAction;
  const ShopScreen({super.key, required this.player, required this.onAction});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}
class _ShopScreenState extends State<ShopScreen> {
  late Player player = widget.player;
  bool busy = false;
  ShopKind selectedKind = ShopKind.weapon;
  final ScrollController listController = ScrollController();
  @override
  void dispose() { listController.dispose(); super.dispose(); }
  void selectKind(ShopKind kind) {
    setState(() => selectedKind = kind);
    if (listController.hasClients) listController.jumpTo(0);
  }
  Future<void> action(String id, bool equip) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final next = await widget.onAction(id, equip);
      if (mounted) setState(() => player = next);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作未完成：$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  EquipmentLook preview(ShopItem item)=>EquipmentLook(jobId:player.jobId,gender:player.gender,
    weapon:item.kind==ShopKind.weapon?item.id:player.weaponId,
    armor:item.kind==ShopKind.armor?item.id:player.armorId,
    accessory:item.kind==ShopKind.accessory?item.id:player.accessoryId);
  @override
  Widget build(BuildContext context) => PopScope(canPop: !busy, child: Scaffold(
    appBar: AppBar(title: const Text('人生商店'), leading: BackButton(onPressed: busy ? null : () => Navigator.pop(context))),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760),
      child: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('金錢：\$${player.money}　裝備：${weaponName(player.weaponId)}', style: Theme.of(context).textTheme.titleLarge),
        Text('防具：${weaponName(player.armorId)}　飾品：${weaponName(player.accessoryId)}'),
        Text('體力 ${player.stamina} · 智力 ${player.intelligence} · 魅力 ${player.charm} · 道德 ${player.morality}'),
        if (player.weaponId != 'none') TextButton(onPressed: busy ? null : () => action('none', true), child: const Text('卸下武器')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final category in const [
            (ShopKind.weapon, '武器', Icons.gavel),
            (ShopKind.armor, '防具', Icons.shield_outlined),
            (ShopKind.accessory, '飾品', Icons.diamond_outlined),
            (ShopKind.item, '補品', Icons.medical_services_outlined),
          ]) ChoiceChip(
            key: ValueKey('shop-category-${category.$1.name}'),
            avatar: Icon(category.$3, size: 18),
            label: Text(category.$2),
            selected: selectedKind == category.$1,
            onSelected: busy ? null : (_) => selectKind(category.$1),
          ),
        ]),
        TextButton.icon(onPressed: busy ? null : () => selectKind(ShopKind.training),
          icon: const Icon(Icons.school_outlined), label: const Text('屬性培養課程')),
        if (busy) const LinearProgressIndicator(),
      ])),
      Expanded(child: ListView(controller: listController, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
        for (final kind in [selectedKind]) ...[
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(switch(kind) {
            ShopKind.training => '屬性培養', ShopKind.weapon => '武器裝備（一次裝備一件）', ShopKind.armor => '防具', ShopKind.accessory => '飾品', ShopKind.item => '補品（戰鬥中使用）',
          }, style: Theme.of(context).textTheme.titleMedium)),
          for (final item in shopCatalog.where((s) => s.kind == kind)) Card(key: ValueKey('shop-item-${item.id}'), child: Padding(
            padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item.name}　\$${item.price}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if(item.isEquipment) Actor3D(look:preview(item),width:100,height:116),
              Text(item.description),
              if(player.currentStage<item.unlockStage)Text('尚未解鎖：通關第 ${item.unlockStage-1} 關後販售',style:const TextStyle(color:Colors.brown)),
              if (kind != ShopKind.training) Text('持有：${player.inventory[item.id] ?? 0}'),
              Wrap(spacing: 12, children: [
                FilledButton(onPressed: busy || player.currentStage < item.unlockStage || player.money < item.price ||
                  (item.isEquipment && (player.inventory[item.id] ?? 0) > 0) ||
                  (kind == ShopKind.item && (player.inventory[item.id] ?? 0) >= 99)
                    ? null : () => action(item.id, false), child: const Text('購買')),
                if (item.isEquipment && (player.inventory[item.id] ?? 0) > 0)
                  OutlinedButton(onPressed: busy || equippedId(player,item.slot!) == item.id ? null : () => action(item.id, true),
                    child: Text(equippedId(player,item.slot!) == item.id ? '已裝備' : '裝備')),
              ]),
            ]))),
        ],
      ])),
      ])),
    ),
  ));
}
