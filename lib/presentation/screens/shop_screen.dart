import 'package:flutter/material.dart';

import '../../domain/models/player.dart';
import '../../domain/models/shop_item.dart';
import '../art/equipment_layers.dart';
import '../art/item_illustration.dart';
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
  void dispose() {
    listController.dispose();
    super.dispose();
  }

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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作未完成：$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  EquipmentLook preview(ShopItem item) => EquipmentLook(
    jobId: player.jobId,
    gender: player.gender,
    weapon: item.kind == ShopKind.weapon ? item.id : player.weaponId,
    armor: item.kind == ShopKind.armor ? item.id : player.armorId,
    accessory: item.kind == ShopKind.accessory ? item.id : player.accessoryId,
  );

  void tryOn(ShopItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '工坊試衣鏡',
                    style: TextStyle(
                      color: AtelierPalette.gold,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AtelierPalette.paper,
                      borderRadius: BorderRadius.circular(80),
                      border: Border.all(color: AtelierPalette.line),
                    ),
                    child: Actor3D(
                      look: preview(item),
                      width: 210,
                      height: 250,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(height: 1.7),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '試穿僅供預覽；符合關卡與職業條件後可購買、裝備。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AtelierPalette.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('回到商品目錄'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = shopCatalog.where((s) => s.kind == selectedKind).toList();
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: AtelierPalette.paper,
        appBar: AppBar(
          title: const Text('人生商店'),
          leading: BackButton(
            onPressed: busy ? null : () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: Text(
                  '第 ${player.currentStage} 關',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AtelierPalette.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(
                controller: listController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _welcome(),
                  const SizedBox(height: 18),
                  _account(),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in const [
                        (ShopKind.weapon, '武器', Icons.gavel_outlined),
                        (ShopKind.armor, '防具', Icons.shield_outlined),
                        (ShopKind.accessory, '飾品', Icons.diamond_outlined),
                        (ShopKind.item, '補品', Icons.science_outlined),
                      ])
                        ChoiceChip(
                          key: ValueKey('shop-category-${category.$1.name}'),
                          avatar: Icon(category.$3, size: 17),
                          label: Text(category.$2),
                          selected: selectedKind == category.$1,
                          onSelected: busy
                              ? null
                              : (_) => selectKind(category.$1),
                        ),
                      ChoiceChip(
                        key: const ValueKey('shop-category-training'),
                        avatar: const Icon(
                          Icons.auto_stories_outlined,
                          size: 17,
                        ),
                        label: const Text('屬性培養課程'),
                        selected: selectedKind == ShopKind.training,
                        onSelected: busy
                            ? null
                            : (_) => selectKind(ShopKind.training),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          switch (selectedKind) {
                            ShopKind.weapon => '旅人的兵器架',
                            ShopKind.armor => '縫製一身勇氣',
                            ShopKind.accessory => '隨身的小小祝福',
                            ShopKind.item => '把補給裝進行囊',
                            ShopKind.training => '為明天多一點準備',
                          },
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${items.length} 件選物',
                        style: const TextStyle(
                          color: AtelierPalette.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    switch (selectedKind) {
                      ShopKind.weapon => '武器裝備（一次裝備一件）',
                      ShopKind.armor => '選一件防具，安心走向下一段旅程。',
                      ShopKind.accessory => '飾品一次裝備一件，為角色添上專屬細節。',
                      ShopKind.item => '補品（戰鬥中使用）',
                      ShopKind.training => '屬性培養 · 課程永久提升基礎能力。',
                    },
                    style: const TextStyle(
                      color: AtelierPalette.muted,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: LinearProgressIndicator(),
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 930
                          ? 3
                          : constraints.maxWidth >= 610
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 16) / columns;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final item in items)
                            SizedBox(width: width, child: _itemCard(item)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '工坊手記 · 進階裝備有職業限制；轉職會卸下不相容裝備，收藏仍保留。加成只用於戰鬥。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AtelierPalette.muted,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcome() => Container(
    decoration: BoxDecoration(
      color: AtelierPalette.forest,
      borderRadius: BorderRadius.circular(22),
    ),
    clipBehavior: Clip.antiAlias,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 550;
        final title = Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THE WAYFARER’S EMPORIUM',
                style: TextStyle(
                  color: Color(0xFFCEB57F),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.3,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '旅人選物所',
                style: TextStyle(
                  color: AtelierPalette.cream,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '一件好裝備，陪你走過每一段人生。',
                style: TextStyle(
                  color: AtelierPalette.paper.withValues(alpha: .78),
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: Color(0xFFCEB57F)),
                  SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      '工匠製作  /  冒險者珍藏',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFCEB57F),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        return wide
            ? Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(
                    width: 280,
                    height: 205,
                    child: AtelierFrontage(),
                  ),
                  const SizedBox(width: 20),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(
                    height: 122,
                    width: double.infinity,
                    child: AtelierFrontage(),
                  ),
                  const SizedBox(height: 12),
                ],
              );
      },
    ),
  );

  Widget _account() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AtelierPalette.cream,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AtelierPalette.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 28,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF0E4C6),
                  ),
                  child: const Icon(
                    Icons.toll_outlined,
                    color: AtelierPalette.gold,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '旅途預算',
                        style: TextStyle(
                          fontSize: 11,
                          color: AtelierPalette.muted,
                        ),
                      ),
                      Text(
                        '\$${player.money}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AtelierPalette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              '體力 ${player.stamina}  ·  智力 ${player.intelligence}\n魅力 ${player.charm}  ·  道德 ${player.morality}',
              style: const TextStyle(
                fontSize: 12,
                color: AtelierPalette.muted,
                height: 1.9,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          equipmentFamilies(player.jobId).isEmpty
              ? '目前為入門職業：可使用通用裝備'
              : '目前裝備專長：${equipmentFamilies(player.jobId).map((f) => f.label).join("／")}',
          style: const TextStyle(fontSize: 12, color: AtelierPalette.muted),
        ),
        const Divider(height: 26),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '武器：${weaponName(player.weaponId)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '防具：${weaponName(player.armorId)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '飾品：${weaponName(player.accessoryId)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (player.weaponId != 'none')
              TextButton(
                onPressed: busy ? null : () => action('none', true),
                child: const Text('卸下武器'),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _itemCard(ShopItem item) {
    final owned = player.inventory[item.id] ?? 0;
    final lockReason = equipmentLockReason(player, item);
    final locked = lockReason != null;
    final equipped =
        item.isEquipment && equippedId(player, item.slot!) == item.id;
    final canBuy =
        !busy &&
        !locked &&
        player.money >= item.price &&
        !(item.isEquipment && owned > 0) &&
        !(item.kind == ShopKind.item && owned >= 99);
    final accent = itemAccent(item);
    return Container(
      key: ValueKey('shop-item-${item.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AtelierPalette.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: equipped ? AtelierPalette.forest : AtelierPalette.line,
        ),
        boxShadow: [
          BoxShadow(
            color: AtelierPalette.ink.withValues(alpha: .025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: const Color(0xFFEEE7D6),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      item.unlockStage >= 6
                          ? Icons.auto_awesome
                          : Icons.workspace_premium_outlined,
                      size: 13,
                      color: accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      itemEdition(item),
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    if (item.isEquipment)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          item.classRequirement,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AtelierPalette.muted,
                          ),
                        ),
                      ),
                    if (locked)
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: AtelierPalette.muted,
                      ),
                    if (equipped)
                      const Text(
                        '已裝備',
                        style: TextStyle(
                          color: AtelierPalette.forest,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                ItemIllustration(
                  itemId: item.id,
                  width: double.infinity,
                  height: 175,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: AtelierPalette.muted,
                    fontSize: 12,
                    height: 1.75,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.toll_outlined,
                          size: 17,
                          color: AtelierPalette.gold,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '\$${item.price}',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: AtelierPalette.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.kind != ShopKind.training)
                      Text(
                        '持有：$owned',
                        style: const TextStyle(
                          color: AtelierPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                if (item.isEquipment)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      item.classRequirement,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AtelierPalette.muted,
                      ),
                    ),
                  ),
                if (locked)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '尚未解鎖：$lockReason',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AtelierPalette.clay,
                        height: 1.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: canBuy ? () => action(item.id, false) : null,
                      child: const Text('購買'),
                    ),
                    if (item.isEquipment && owned > 0)
                      OutlinedButton(
                        onPressed: busy || equipped || locked
                            ? null
                            : () => action(item.id, true),
                        child: Text(equipped ? '已裝備' : '裝備'),
                      ),
                    if (item.isEquipment)
                      TextButton(
                        onPressed: busy ? null : () => tryOn(item),
                        child: const Text('試穿'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
