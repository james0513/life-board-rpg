import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/battle.dart';
import '../../domain/models/shop_item.dart';
import '../art/atlas_portrait.dart';
import '../art/equipment_layers.dart';
import 'spell_effect.dart';
import '../services/battle_audio_cues.dart';
import '../three_d/models_3d.dart';
import '../widgets/chapter_backdrop.dart';


/// Full-screen route; results remain visible until the save succeeds.
class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key, required this.session, required this.onSound,
    required this.onSettle});
  final BattleSession session;
  final void Function(String) onSound;
  final Future<bool> Function() onSettle;
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}
class _BattleScreenState extends State<BattleScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  bool _busy = false, _heroAttacks = true, _strike = false, _saveFailed = false;
  BattleImpact? _impact;
  bool _magic = false;
  String? _element;
  double get _contact => _magic ? .6 : .25;
  String _message = '你的回合：選擇下方指令。';
  BattleSession get battle => widget.session;
  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 820));
  }
  @override
  void dispose() { _motion.dispose(); super.dispose(); }

  Future<void> _animate({required bool hero, required bool strike, bool magic = false, String? element, String? cue,
      required BattleImpact? Function() resolve}) async {
    setState(() { _heroAttacks = hero; _strike = strike; _magic = magic; _element=element; _impact = null; });
    _motion.duration = Duration(milliseconds: magic ? 1100 : 820);
    if (cue != null) widget.onSound(cue);
    final animation = _motion.forward(from: 0).orCancel.then<void>((_) {}, onError: (Object _) {});
    await Future<void>.delayed(Duration(milliseconds: magic ? 660 : 205));
    if (!mounted) return;
    setState(() { _impact = resolve(); _message = _impact?.message ?? _message; });
    if ((_impact?.damage ?? 0) > 0) widget.onSound(hero ? (magic ? 'hit_magic' : 'hit_enemy') : 'hit_hero');
    await animation;
  }
  Future<void> _act(BattleAction action) async {
    if (_busy || !battle.canUse(action)) return;
    setState(() => _busy = true);
    try {
      await _animate(hero: true, cue: playerActionCue(action, battle.player.weaponId, battle.player.jobId),
        strike: action == BattleAction.attack, magic: [BattleAction.skill,BattleAction.frost,BattleAction.heal,BattleAction.burst].contains(action),
        element: action==BattleAction.frost?'ice':action==BattleAction.heal?'heal':action==BattleAction.burst?'burst':null,
        resolve: () => battle.playerAct(action));
      if (!mounted) return;
      if (battle.awaitingEnemy) {
        await Future<void>.delayed(const Duration(milliseconds: 160));
        if (!mounted) return;
        await _animate(hero: false, cue: enemyActionCue(battle), strike: !battle.enemyFrozen, resolve: battle.enemyAct);
      }
      if (!mounted) return;
      if (!battle.active) widget.onSound(battle.status == BattleStatus.won ? 'promotion' : 'event');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _submenu(bool items) async {
    if (_busy || !battle.active) return;
    setState(() => _busy = true);
    final selected = await showModalBottomSheet<BattleAction>(context: context,
      builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(items ? '道具 · 持有背包' : '技能／魔法',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (items) ...[
            _option('恢復藥 ×${battle.potions}', 'HP +40，使用後敵人仍會行動', BattleAction.potion),
            _option('專注飲 ×${battle.ethers}', 'SP 回滿，使用後敵人仍會行動', BattleAction.ether),
          ] else ...[
            _option(battle.skillName, '1 SP · ${battle.job?.skillFormula ?? "智力提升威力"}，裝備魔法 +${equipmentMagic(battle.player)}', BattleAction.skill),
            _option('冰封束縛', '2 SP · 70% 魔法傷害，跳過敵人一次反擊', BattleAction.frost),
            _option('生命綻放', '2 SP · 恢復 HP，智力及法杖提升治療量', BattleAction.heal),
            _option('星辰爆發', '3 SP · 160% 魔法傷害', BattleAction.burst),
            _option('沉著應對', '無消耗，SP +1，本回合受到傷害降為約 1/3', BattleAction.defend),
          ],
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消，不消耗回合')),
        ])))));
    if (!mounted) return;
    setState(() => _busy = false);
    if (selected != null) await _act(selected);
  }
  Widget _option(String name, String detail, BattleAction action) => ListTile(
    title: Text(name), subtitle: Text(detail), enabled: battle.canUse(action),
    onTap: battle.canUse(action) ? () => Navigator.pop(context, action) : null);

  Future<void> _finish() async {
    if (_busy || battle.active) return;
    setState(() { _busy = true; _saveFailed = false; });
    var saved = false;
    try { saved = await widget.onSettle(); } catch (_) { saved = false; }
    if (!mounted) return;
    if (saved) { Navigator.of(context).pop(); }
    else { setState(() { _busy = false; _saveFailed = true; }); }
  }

  Widget _bar(String label, int value, int maximum, Color color) => Padding(
    padding: const EdgeInsets.only(top: 6), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), Text('$value / $maximum'),
      ]),
      const SizedBox(height: 4),
      TweenAnimationBuilder<double>(tween: Tween(end: value/maximum),
        duration: const Duration(milliseconds: 260),
        builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 9,
          color: color, backgroundColor: Colors.black12)),
    ]));
  Widget _status(bool hero) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFFFFCF4), borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!hero && battle.finalEnraged) const Text('命運暴走：攻擊 +8', style: TextStyle(color:Colors.red)),
      Text(hero ? '${battle.player.displayName} · ${battle.job?.title ?? "待業"} · Lv.${battle.player.level}' : battle.enemy.name,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      if(hero) Text('武器：${weaponName(battle.player.weaponId)} · 防具：${weaponName(battle.player.armorId)}\n飾品：${weaponName(battle.player.accessoryId)}',style:const TextStyle(fontSize:12)),
      _bar('HP', hero ? battle.hp : battle.enemyHp, hero ? battle.maxHp : battle.enemy.hp, Colors.teal),
      _bar('SP', hero ? battle.energy : battle.enemySp,
        hero ? BattleSession.maxSp : battle.enemy.maxSp, Colors.indigo),
    ]));

  Widget _portrait(bool hero, double width, double height) {
    if (hero) return CareerPortrait(equipment:EquipmentLook.fromPlayer(battle.player),jobId: battle.player.jobId,gender:battle.player.gender, width: width, height: height);
    return Actor3D(enemy:battle.enemy.isBoss?battle.enemy.bossStage-1:battle.enemy.portrait,
      boss:battle.enemy.isBoss,width:width,height:height);
  }

  Widget _arena(double height) => LayoutBuilder(builder: (context, box) {
    final width = box.maxWidth;
    final actorWidth = math.min(210.0, width*.26);
    final actorHeight = math.min(height*.78, 245.0);
    return SizedBox(height: height, child: ClipRRect(borderRadius: BorderRadius.circular(22),
      child: Stack(children: [
        Positioned.fill(child: ChapterBackdrop(stage:battle.player.currentStage)),
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0x22FFFFFF),const Color(0x44807060)])))),
        Positioned(left: 0, right: 0, bottom: 16, child: Container(height: 26, color: const Color(0x335F7456))),
        AnimatedBuilder(animation: _motion, builder: (_, __) {
          final t = _motion.value;
          final lunge = !_strike ? 0.0 : t < .25 ? t/.25 : t < .55 ? 1-(t-.25)/.3 : 0.0;
          final progress = ((t-_contact)/(1-_contact)).clamp(0.0,1.0).toDouble();
          return Stack(children: [
            for (final hero in [true,false]) Builder(builder: (_) {
              final x = width*(hero ? .22 : .78) - actorWidth/2;
              final attacking = hero == _heroAttacks;
              final target = _impact != null && _impact!.targetsPlayer == hero;
              final hit = target && _impact!.damage > 0 && t >= _contact && t < _contact + .25;
              final flash = hit && ((t*22).floor().isEven);
              final move = attacking ? lunge*width*.34*(hero ? 1 : -1) : 0.0;
              return Positioned(left: x+move, bottom: 26,
                child: Transform.rotate(angle: attacking && _strike ? lunge*(hero ? .12 : -.12) : 0,
                  child: Opacity(opacity: flash ? .25 : 1,
                    child: _portrait(hero,actorWidth,actorHeight))));
            }),
            if (_strike && _impact != null && _impact!.damage > 0 && t >= .25 && t < .65)
              Positioned(left: width*(_impact!.targetsPlayer ? .22 : .78)-45,
                bottom: actorHeight*.45, child: CustomPaint(size: const Size(90,90),
                  painter: _Slash(progress: ((t-.25)/.4).clamp(0.0,1.0).toDouble()))),
            if (_magic && _motion.isAnimating) Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: SpellEffect(progress: t, jobId: battle.player.jobId, element:_element,reducedEffects:MediaQuery.disableAnimationsOf(context))))),
            if (_impact != null && t >= _contact && (_impact!.damage > 0 || _impact!.healing > 0 || _impact!.spRecovered > 0))
              Positioned(left: width*(_impact!.targetsPlayer ? .22 : .78)-65,
                bottom: actorHeight*.72+30+progress*50,
                child: Opacity(opacity: 1-progress, child: SizedBox(width: 130,
                  child: Text(_impact!.floatingText, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900,
                      color: _impact!.damage > 0 ? const Color(0xFFC54038) : const Color(0xFF007E60),
                      shadows: const [Shadow(color: Colors.white, blurRadius: 4)]))))),
          ]);
        }),
      ])));
  });
  Widget _result() {
    final title = switch (battle.status) {
      BattleStatus.won => '戰鬥勝利', BattleStatus.lost => '戰鬥失敗',
      BattleStatus.escaped => '撤退成功', _ => '',
    };
    final money = battle.status == BattleStatus.won ? battle.enemy.reward
      : battle.status == BattleStatus.lost ? -math.min(100,battle.player.money) : 0;
    return Container(padding: const EdgeInsets.all(18), margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(color: const Color(0xFFFFF2CE), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text(title, style: const TextStyle(fontSize: 25,fontWeight: FontWeight.bold)),
        Text('經驗值 +${battle.earnedExperience}　金錢 ${money >= 0 ? "+" : ""}$money'),
        if (battle.status == BattleStatus.won) const Text('體力 +3　智力 +2　道德 +2'),
        if (battle.player.gainExperience(battle.earnedExperience).level > battle.player.level)
          Text('升級！Lv.${battle.player.level} → Lv.${battle.player.gainExperience(battle.earnedExperience).level}'),
        if (_saveFailed) const Text('存檔未成功，請重試；不會重複領取獎勵。', style: TextStyle(color: Colors.red)),
      ]));
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: false, child: Scaffold(
    backgroundColor: const Color(0xFFF0EBDF),
    appBar: AppBar(automaticallyImplyLeading: false, title: Text(battle.enemy.isBoss ? '第 ${battle.enemy.bossStage} 關 · 魔王戰' : '人生挑戰 · 回合制戰鬥'),
      actions: [Padding(padding: const EdgeInsets.all(16), child: Text('回合 ${battle.round+1}'))]),
    body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1180),
      child: LayoutBuilder(builder: (context, size) => SingleChildScrollView(
        padding: const EdgeInsets.all(16), child: Column(children: [
          Row(children: [Expanded(child: _status(true)), const SizedBox(width: 12), Expanded(child: _status(false))]),
          const SizedBox(height: 12),
          _arena((size.maxHeight-220).clamp(180.0,360.0).toDouble()),
          const SizedBox(height: 12),
          Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
          if (battle.active) Text('敵方意圖：${battle.intent}', style: const TextStyle(color: Colors.brown)),
          if (!battle.active && !_busy) _result(),
        ])))),
    )),
    bottomNavigationBar: SafeArea(child: Container(padding: const EdgeInsets.all(14),
      color: const Color(0xFFFFFCF4), child: battle.active ? Wrap(
        alignment: WrapAlignment.center, spacing: 10, runSpacing: 8, children: [
          FilledButton.icon(onPressed: _busy ? null : () => _act(BattleAction.attack),
            icon: const Icon(Icons.flash_on), label: const Text('普通攻擊')),
          FilledButton.tonalIcon(onPressed: _busy ? null : () => _submenu(false),
            icon: const Icon(Icons.auto_awesome), label: const Text('技能／魔法')),
          FilledButton.tonalIcon(onPressed: _busy ? null : () => _submenu(true),
            icon: const Icon(Icons.inventory_2_outlined), label: const Text('道具')),
          OutlinedButton.icon(onPressed: _busy ? null : () => _act(BattleAction.flee),
            icon: const Icon(Icons.directions_run), label: const Text('逃跑 65%')),
        ]) : FilledButton(onPressed: _busy ? null : _finish,
          child: Text(_busy ? '處理中…' : _saveFailed ? '重試存檔並返回' : '結算並返回大地圖')))),
  ));
}
class _Slash extends CustomPainter {
  const _Slash({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 1-progress)
      ..strokeWidth = 8*(1-progress)+2..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width*.1,size.height*.9),Offset(size.width*.9,size.height*.1),paint);
    paint..color = const Color(0xFFFFC957).withValues(alpha: 1-progress)..strokeWidth = 3;
    canvas.drawLine(Offset(size.width*.2,size.height),Offset(size.width,size.height*.2),paint);
  }
  @override
  bool shouldRepaint(covariant _Slash oldDelegate) => oldDelegate.progress != progress;
}
