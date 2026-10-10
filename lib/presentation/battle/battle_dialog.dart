import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models/battle.dart';

class BattleDialog extends StatefulWidget {
  const BattleDialog({super.key, required this.session, required this.onSound});
  final BattleSession session;
  final void Function(String) onSound;
  @override
  State<BattleDialog> createState() => _BattleDialogState();
}
class _BattleDialogState extends State<BattleDialog> {
  bool _busy = false;
  double _lunge = 0;
  final List<String> _log = [];
  BattleSession get battle => widget.session;
  Future<void> _act(BattleAction action) async {
    if (_busy || !battle.active) return;
    setState(() { _busy = true; _lunge = action == BattleAction.attack || action == BattleAction.skill ? 18 : 0; });
    widget.onSound(action == BattleAction.skill ? 'stat_up' : 'click');
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() {
      battle.act(action); _lunge = 0;
      _log.insert(0, battle.message);
      if (_log.length > 20) _log.removeLast();
    });
    widget.onSound(battle.status == BattleStatus.won ? 'promotion' : 'setback');
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (mounted) setState(() => _busy = false);
  }
  Widget _health(String label, int hp, int maxHp, Color color) => Column(children: [
    Text('$label  $hp / $maxHp', textAlign: TextAlign.center),
    const SizedBox(height: 6),
    TweenAnimationBuilder<double>(tween: Tween(end: hp / maxHp), duration: const Duration(milliseconds: 250),
      builder: (context, value, _) => LinearProgressIndicator(value: value,
        minHeight: 9, color: color, backgroundColor: Colors.black12)),
  ]);
  Widget _enemy() {
    // Atlas regions follow the actual generated silhouettes, not equal thirds.
    final widths = [0.282, 0.383, 0.335];
    final centers = [-1.0, -0.086, 1.0];
    final index = battle.enemy.portrait;
    return SizedBox(width: 150, height: 170, child: ClipRect(
      child: OverflowBox(alignment: Alignment(centers[index], 0),
        minWidth: 150 / widths[index], maxWidth: 150 / widths[index],
        child: Image.asset('assets/images/battle/enemies.png',
          width: 150 / widths[index], height: 170, fit: BoxFit.fill))));
  }
  @override
  Widget build(BuildContext context) {
    final title = switch (battle.status) {
      BattleStatus.active => '人生挑戰', BattleStatus.won => '挑戰成功！',
      BattleStatus.lost => '休息一下，再出發', BattleStatus.escaped => '安全撤退',
    };
    return PopScope(canPop: false, child: Dialog(
      insetPadding: const EdgeInsets.all(12), backgroundColor: const Color(0xFFFFFAEE),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
            Text(battle.enemy.description, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _health('阿晨', battle.hp, battle.maxHp, Colors.teal)),
              const SizedBox(width: 24),
              Expanded(child: _health(battle.enemy.name, battle.enemyHp, battle.enemy.hp, Colors.deepOrange)),
            ]),
            Container(height: 195, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFFE0EEE0), Color(0xFFF1DAB5)])),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Expanded(child: AnimatedSlide(offset: Offset(_lunge / 100, 0),
                  duration: const Duration(milliseconds: 180),
                  child: Image.asset('assets/images/characters/unemployed.png', height: 170))),
                const Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                Expanded(child: Center(child: _enemy())),
              ])),
            if (battle.active) Text('專注 ${battle.energy}/3 · 敵方下一招：${battle.intent}'),
            if (!battle.active) Text(switch (battle.status) {
              BattleStatus.won => '獎勵：金錢 +${battle.enemy.reward}、體力 +3、智力 +2',
              BattleStatus.lost => '休養費最多 100 元；永久屬性不減少。',
              _ => '撤退不獲得獎勵，也不扣金錢。',
            }, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (battle.active) Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
              children: [
                for (final item in [(BattleAction.attack, '攻擊'), (BattleAction.skill, '靈光一擊 · 1專注'),
                  (BattleAction.defend, '防禦 · 回復專注'), (BattleAction.flee, '逃跑 · 65%')])
                  FilledButton.tonal(onPressed: _busy || (item.$1 == BattleAction.skill && battle.energy == 0)
                    ? null : () => _act(item.$1), child: Text(item.$2)),
              ])
            else FilledButton(onPressed: _busy ? null : () => Navigator.pop(context, battle.status),
              child: const Text('結算並返回棋盤')),
            const SizedBox(height: 12),
            const Text('體力提升生命與攻擊；智力提升技能；魅力提升會心。',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.brown)),
            const SizedBox(height: 8),
            SizedBox(height: 95, child: ListView(children: [
              for (final line in _log) Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Text(line, textAlign: TextAlign.center)),
              if (_log.isEmpty) Text(battle.message, textAlign: TextAlign.center),
            ])),
          ])),
      )));
  }
}
