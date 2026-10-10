import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/player.dart';
import '../../domain/models/shop_item.dart';
import '../art/equipment_layers.dart';
import '../art/item_illustration.dart';
import '../three_d/models_3d.dart';
import '../theme/game_design.dart';

String slotLabel(EquipmentSlot s) => switch (s) {
  EquipmentSlot.weapon => '武器',
  EquipmentSlot.armor => '防具',
  EquipmentSlot.accessory => '飾品',
};
IconData slotIcon(EquipmentSlot s) => switch (s) {
  EquipmentSlot.weapon => Icons.gavel_outlined,
  EquipmentSlot.armor => Icons.shield_outlined,
  EquipmentSlot.accessory => Icons.diamond_outlined,
};

class EquipmentScreen extends StatefulWidget {
  final Player player;
  final String jobTitle;
  final Future<Player> Function(String id, EquipmentSlot slot) onEquip;
  const EquipmentScreen({
    super.key,
    required this.player,
    required this.jobTitle,
    required this.onEquip,
  });
  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  late Player player = widget.player;
  EquipmentSlot slot = EquipmentSlot.weapon;
  bool busy = false;

  Future<void> equip(String id) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final updated = await widget.onEquip(id, slot);
      if (mounted) setState(() => player = updated);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('換裝未完成：$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String change(int n) => n > 0 ? '+$n' : '$n';

  @override
  Widget build(BuildContext context) {
    final owned = shopCatalog
        .where((i) => i.slot == slot && (player.inventory[i.id] ?? 0) > 0)
        .toList();
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: AtelierPalette.paper,
        appBar: AppBar(
          title: const Text('人物裝備'),
          leading: BackButton(
            onPressed: busy ? null : () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _characterFolio(),
                  const SizedBox(height: 24),
                  const Text(
                    '隨行裝備',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '每一件珍藏，都在旅程中留下印記。',
                    style: TextStyle(fontSize: 12, color: AtelierPalette.muted),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 670;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final s in EquipmentSlot.values)
                            SizedBox(
                              width: wide
                                  ? (constraints.maxWidth - 24) / 3
                                  : constraints.maxWidth,
                              child: _slotTile(s),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${slotLabel(slot)}收藏',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${owned.length} 件持有',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AtelierPalette.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (equippedId(player, slot) != 'none')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : () => equip('none'),
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 17,
                          ),
                          label: Text('卸下${slotLabel(slot)}'),
                        ),
                      ),
                    ),
                  if (owned.isEmpty) _emptyCollection(),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth > 760 ? 2 : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 16) / columns;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final item in owned)
                            SizedBox(
                              width: width,
                              child: _collectionItem(item),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AtelierPalette.line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AtelierPalette.gold,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '每個欄位可裝備一件。加成只套用於戰鬥，不改變轉職用的基礎屬性。武器、防具與飾品即時顯示於角色，卸下恢復職業服裝。',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.7,
                              color: AtelierPalette.muted,
                            ),
                          ),
                        ),
                      ],
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

  Widget _characterFolio() => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AtelierPalette.forest,
      borderRadius: BorderRadius.circular(22),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final portrait = SizedBox(
          width: 255,
          height: 296,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: FolioEngraving(color: const Color(0xFFDEC88E)),
                ),
              ),
              Positioned(
                bottom: 31,
                child: Container(
                  width: 144,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF102E27),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: const Color(0xFF998551),
                      width: 1,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Actor3D(
                  look: EquipmentLook.fromPlayer(player),
                  width: 208,
                  height: 252,
                ),
              ),
              const Positioned(
                bottom: 10,
                child: Text(
                  'LIVE CHARACTER  /  即時換裝',
                  style: TextStyle(
                    color: Color(0xFFCEB57F),
                    fontSize: 9,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
        final details = Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THE ADVENTURER’S WARDROBE',
                style: TextStyle(
                  color: Color(0xFFCEB57F),
                  letterSpacing: 1.8,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                player.displayName,
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  color: AtelierPalette.cream,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF36574B),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: const Color(0xFF74806A)),
                    ),
                    child: Text(
                      widget.jobTitle,
                      style: const TextStyle(
                        color: Color(0xFFE3CF9F),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'Lv.${player.level}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AtelierPalette.paper,
                    ),
                  ),
                  Text(
                    '\$${player.money}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFB4C0AD),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  _stat(
                    '最大 HP',
                    '${60 + math.min(player.stamina, 200) * 2 + equipmentHp(player)}',
                    Icons.favorite_border,
                  ),
                  _stat(
                    '裝備攻擊',
                    '+${equipmentAttack(player)}',
                    Icons.gavel_outlined,
                  ),
                  _stat(
                    '裝備魔法',
                    '+${equipmentMagic(player)}',
                    Icons.auto_awesome_outlined,
                  ),
                  _stat(
                    '裝備減傷',
                    '${equipmentDefense(player)}',
                    Icons.shield_outlined,
                  ),
                  _stat(
                    '會心加成',
                    '+${equipmentCritical(player)}%',
                    Icons.bolt_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '行囊補給  ·  恢復藥 ${player.inventory['potion'] ?? 0}  /  專注飲 ${player.inventory['ether'] ?? 0}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFBDCCB9),
                  height: 1.7,
                ),
              ),
            ],
          ),
        );
        if (constraints.maxWidth > 650)
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              portrait,
              Expanded(child: details),
            ],
          );
        return Column(children: [portrait, details]);
      },
    ),
  );

  Widget _stat(String title, String value, IconData icon) => Container(
    width: 108.0 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF25483D),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF476452)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFFCEB57F)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(fontSize: 10, color: Color(0xFFBDCCB9)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AtelierPalette.cream,
          ),
        ),
      ],
    ),
  );

  Widget _slotTile(EquipmentSlot s) {
    final current = equippedId(player, s);
    final active = slot == s;
    return Semantics(
      selected: active,
      button: true,
      child: Material(
        color: active ? const Color(0xFFE4E8D8) : AtelierPalette.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: active ? AtelierPalette.forest : AtelierPalette.line,
            width: active ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('equipment-slot-${s.name}'),
          onTap: busy ? null : () => setState(() => slot = s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (current == 'none')
                  Container(
                    width: 61,
                    height: 66,
                    alignment: Alignment.center,
                    child: Icon(
                      slotIcon(s),
                      color: AtelierPalette.gold,
                      size: 28,
                    ),
                  )
                else
                  ItemIllustration(
                    itemId: current,
                    width: 61,
                    height: 66,
                    framed: false,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '目前裝備',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? AtelierPalette.forest
                              : AtelierPalette.muted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${slotLabel(s)}：${weaponName(current)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (active)
                  const Icon(
                    Icons.check_circle,
                    size: 17,
                    color: AtelierPalette.forest,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyCollection() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
    decoration: BoxDecoration(
      color: AtelierPalette.cream,
      border: Border.all(color: AtelierPalette.line),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Icon(slotIcon(slot), size: 36, color: AtelierPalette.gold),
        const SizedBox(height: 14),
        const Text(
          '留一格，給下一份珍藏。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text(
          '尚未持有此類裝備。\n走到第 6 或 16 格商店街購買，之後可在這裡自由換裝。',
          textAlign: TextAlign.center,
          style: TextStyle(
            height: 1.8,
            fontSize: 12,
            color: AtelierPalette.muted,
          ),
        ),
      ],
    ),
  );

  Widget _collectionItem(ShopItem item) {
    final selected = equippedId(player, slot) == item.id;
    final lockReason = equipmentLockReason(player, item);
    final currentId = equippedId(player, slot);
    final current = currentId == 'none' ? null : shopById(currentId);
    return Container(
      key: ValueKey('equipment-item-${item.id}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AtelierPalette.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AtelierPalette.forest : AtelierPalette.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ItemIllustration(itemId: item.id, width: 110, height: 128),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemEdition(item),
                      style: TextStyle(
                        color: itemAccent(item),
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selected
                          ? '正在陪你冒險'
                          : lockReason == null
                          ? '已收藏 · 可裝備'
                          : '已收藏 · 目前不可裝備',
                      style: TextStyle(
                        color: selected
                            ? AtelierPalette.forest
                            : AtelierPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            style: const TextStyle(
              color: AtelierPalette.muted,
              fontSize: 12,
              height: 1.75,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.classRequirement,
            style: const TextStyle(fontSize: 12, color: AtelierPalette.muted),
          ),
          if (lockReason != null)
            Text(
              '無法裝備：$lockReason',
              style: const TextStyle(fontSize: 12, color: AtelierPalette.clay),
            ),
          const SizedBox(height: 14),
          if (!selected) ...[
            const Text(
              '更換後差異',
              style: TextStyle(
                fontSize: 10,
                color: AtelierPalette.muted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _delta('攻擊', item.attack - (current?.attack ?? 0)),
                _delta('魔法', item.magic - (current?.magic ?? 0)),
                _delta('HP', item.hp - (current?.hp ?? 0)),
                _delta('減傷', item.defense - (current?.defense ?? 0)),
                _delta(
                  '會心',
                  item.critical - (current?.critical ?? 0),
                  percent: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy || selected || lockReason != null
                  ? null
                  : () => equip(item.id),
              icon: Icon(
                selected
                    ? Icons.check_circle_outline
                    : Icons.swap_horiz_rounded,
                size: 17,
              ),
              label: Text(selected ? '已裝備' : '裝備'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _delta(String label, int value, {bool percent = false}) {
    final color = value > 0
        ? AtelierPalette.forest
        : value < 0
        ? AtelierPalette.clay
        : AtelierPalette.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: value > 0
            ? const Color(0xFFE9EDDE)
            : value < 0
            ? const Color(0xFFF2E3D8)
            : const Color(0xFFEFEBDF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${change(value)}${percent ? ' 個百分點' : ''}',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
