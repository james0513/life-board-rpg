import 'package:flutter/material.dart';
import '../../domain/models/player.dart';
import '../../domain/models/shop_item.dart';
import '../components/tile_component.dart';
import '../art/atlas_portrait.dart';
import '../art/equipment_layers.dart';
import '../theme/game_design.dart';

/// Presentation only: the same board stays alive across responsive layouts.
class GameDashboard extends StatelessWidget {
  const GameDashboard({super.key, required this.player, required this.job,
    required this.board, required this.controls, required this.history});
  final Player player;
  final String job;
  final Widget board;
  final Widget controls;
  final List<String> history;

  Widget _card(String title, Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: const Color(0xFFFFFCF4),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFCEBA8E)),
      boxShadow: const [BoxShadow(color:Color(0x127A5830),blurRadius:18,offset:Offset(0,6))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Container(width: 4, height: 22, decoration: BoxDecoration(color: GameDesign.gold, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: .6, color: GameDesign.ink)))]),
        const SizedBox(height: 16), child,
      ]));

  Widget _stat(String name, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(children: [Icon(icon, size: 20, color: const Color(0xFF648577)),
      const SizedBox(width: 10), Expanded(child: Text(name)),
      Flexible(child: Text(value, textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
    ]));

  Widget _profile() => _card('我的人生', Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(height: 170, decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE5EBD9), Color(0xFFF8EDCE)], begin: Alignment.topLeft, end: Alignment.bottomRight), border: Border.all(color: GameDesign.line), borderRadius: BorderRadius.circular(16)),
        child: Stack(fit: StackFit.expand, children: [const CustomPaint(painter: FolioEngraving()), CareerPortrait(equipment:EquipmentLook.fromPlayer(player),jobId: player.jobId, gender:player.gender, height: 170)])),
      const SizedBox(height: 12),
      Text(player.displayName, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      Text('Lv.${player.level} · EXP ${player.experience % 100}/100', textAlign: TextAlign.center),
      Text(job, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF648577))),
      const SizedBox(height: 12), const Divider(),
      _stat('年齡 / 世代', '${player.life.age} 歲 / 第 ${player.life.generation} 世', Icons.calendar_month_outlined),
      _stat('EQ / 壓力', '${player.life.eq} / ${player.life.stress}', Icons.psychology_outlined),
      _stat('體力', '${player.stamina}', Icons.favorite_outline),
      _stat('智力', '${player.intelligence}', Icons.school_outlined),
      _stat('魅力', '${player.charm}', Icons.auto_awesome_outlined),
      _stat('道德', '${player.morality}', Icons.balance_outlined),
      _stat('金錢', '\$${player.money}', Icons.account_balance_wallet_outlined),
      const Divider(),
      Text('武器：${weaponName(player.weaponId)}\n防具：${weaponName(player.armorId)}\n飾品：${weaponName(player.accessoryId)}',style:const TextStyle(height:1.7)),
      const Divider(),
      Text('目前位置  ${player.position + 1} / 20', textAlign: TextAlign.center),
    ]));

  Widget _legend() => Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 6,
    children: [for (var i = 0; i < TileComponent.labels.length; i++) Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: TileComponent.colors[i], borderRadius: BorderRadius.circular(3), border: Border.all(color: Colors.black12))),
      const SizedBox(width: 4), Text(TileComponent.labels[i]),
    ])]);

  Widget _journal() => _card('人生記事', Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('本次遊玩 · 最新在上', style: TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 16),
      if (history.isEmpty) const Text('旅程即將開始。\n擲骰後，這裡會留下你的每一步。',
        style: TextStyle(height: 1.7)),
      for (final entry in history) Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF3EFE4),
          borderRadius: BorderRadius.circular(12)),
        child: Text(entry, style: const TextStyle(height: 1.6))),
    ]));

  void _openPanel(BuildContext context, bool profile) {
    showDialog<void>(context: context, builder: (dialogContext) => Dialog(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(alignment: Alignment.centerRight, child: IconButton(
            tooltip: '關閉', onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close))),
          Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: profile ? _profile() : _journal())),
        ])),
    ));
  }

  Widget _panelButtons(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
    OutlinedButton.icon(key: const ValueKey('open-profile'), onPressed: () => _openPanel(context, true),
      icon: const Icon(Icons.person_outline), label: const Text('我的人生')),
    OutlinedButton.icon(key: const ValueKey('open-journal'), onPressed: () => _openPanel(context, false),
      icon: const Icon(Icons.history), label: const Text('人生記事')),
  ]);

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final wide = constraints.maxWidth >= 850;
    if (wide) {
      return Padding(padding: const EdgeInsets.all(12), child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: Column(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: GameDesign.ivory.withValues(alpha: .94), borderRadius: BorderRadius.circular(30), border: Border.all(color: GameDesign.line)), child: _legend()),
            Expanded(child: SizedBox.expand(child: board)),

          ])),
          const SizedBox(width: 20),
          SizedBox(width: 300, child: SingleChildScrollView(child: Column(children: [
            _card('旅人的回合', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(width: 74, height: 90, decoration: BoxDecoration(
                  color: const Color(0xFFECEBD9), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: GameDesign.line)),
                  child: CareerPortrait(equipment: EquipmentLook.fromPlayer(player), jobId: player.jobId,
                    gender: player.gender, width: 74, height: 90)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(player.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('$job · Lv.${player.level}', style: const TextStyle(color: GameDesign.muted)),
                  const SizedBox(height: 4),
                  Text('${player.life.age} 歲 · 第 ${player.life.generation} 世', style: const TextStyle(fontSize: 12, color: GameDesign.muted)),
                ])),
              ]),
              const Divider(), controls,
            ])),
            const SizedBox(height: 12),
            _panelButtons(context),
          ]))),
        ]));
    }
    return Padding(padding: const EdgeInsets.all(8), child: Column(children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        Text('${player.displayName} · $job　體力 ${player.stamina}　智力 ${player.intelligence}　魅力 ${player.charm}　道德 ${player.morality}　金錢 \$${player.money}'),
      ])),
      Expanded(flex: 3, child: SizedBox.expand(child: board)),
      Flexible(flex: 2, child: SingleChildScrollView(child: controls)),
      _panelButtons(context),
    ]));
  });
}
