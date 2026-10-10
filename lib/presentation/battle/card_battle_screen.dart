import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/battle.dart';
import '../../domain/models/card_battle.dart';
import 'card_art.dart';
import 'battle_viewport.dart';
import '../../domain/models/shop_item.dart';
import '../art/atlas_portrait.dart';
import '../art/equipment_layers.dart';
import 'spell_effect.dart';
import '../services/battle_audio_cues.dart';
import '../three_d/models_3d.dart';
import '../three_d/scene_3d.dart';
import '../widgets/chapter_backdrop.dart';
import '../theme/game_design.dart';

/// Timed card encounter. Numbers and final-boss turn variant are project tuning.
class CardBattleScreen extends StatefulWidget {
  const CardBattleScreen({
    super.key,
    required this.session,
    required this.onSound,
    required this.onSettle,
    this.onToggleSound,
    this.soundEnabled,
    this.soundError,
  });
  final CardBattleSession session;
  final void Function(String) onSound;
  final Future<bool> Function() onSettle;
  final Future<void> Function()? onToggleSound;
  final bool Function()? soundEnabled;
  final String? Function()? soundError;
  @override
  State<CardBattleScreen> createState() => _CardBattleScreenState();
}

class _CardBattleScreenState extends State<CardBattleScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  Timer? _clock;
  bool _busy = false, _heroAttacks = true, _strike = false, _saveFailed = false;
  bool _paused = false, _background = false;
  BattleImpact? _impact;
  CardMove? _lastMove;
  bool _magic = false;
  String? _element;
  double get _contact => _magic ? .6 : .25;
  String _message = '選同系武器，再搭配魔法牌；行動條蓄滿即可出牌。';
  CardBattleSession get battle => widget.session;
  bool get _canInteract => !_busy && !_paused && !_background && battle.active;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _background = lifecycle != null && lifecycle != AppLifecycleState.resumed;
    _paused = _background;
    if (battle.active) {
      _clock = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _background = state != AppLifecycleState.resumed;
      if (_background) _paused = true;
    });
  }

  // The framework reports browser-window focus separately from app lifecycle.
  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.state == ViewFocusState.unfocused && mounted) {
      setState(() => _paused = true);
    }
  }

  void _tick() {
    if (!mounted || !battle.active) {
      _clock?.cancel();
      return;
    }
    if (!_canInteract) return;
    final move = battle.advance(50);
    if (!battle.active) _clock?.cancel();
    setState(() {});
    if (move != null) unawaited(_perform(move));
  }

  void _pauseOrResume() {
    if (_background || _busy || !battle.active) return;
    setState(() {
      _paused = !_paused;
    });
  }

  void _select(String id) {
    if (!_canInteract) return;
    setState(() {
      battle.toggleCard(id);
    });
    widget.onSound('click');
  }

  void _play() {
    if (!_canInteract) return;
    final move = battle.playSelected();
    if (move != null) unawaited(_perform(move));
  }

  void _utility(BattleAction action) {
    if (!_canInteract) return;
    final move = battle.useUtility(action);
    if (move != null) unawaited(_perform(move));
  }

  Future<void> _perform(CardMove move) async {
    if (!mounted || _busy) return;
    setState(() {
      _busy = true;
      _lastMove = move;
    });
    final hero = move.isHero;
    final magic = [
      BattleAction.skill,
      BattleAction.frost,
      BattleAction.heal,
      BattleAction.burst,
    ].contains(move.actionCue);
    try {
      await _animate(
        hero: hero,
        strike: move.actionCue == BattleAction.attack,
        magic: magic,
        cue: hero
            ? playerActionCue(
                move.actionCue,
                battle.player.weaponId,
                battle.player.jobId,
              )
            : magic
            ? (battle.enemy.isBoss ? 'boss_spell' : 'monster_spell')
            : (battle.enemy.isBoss ? 'boss_swing' : 'monster_claw'),
        element: move.actionCue == BattleAction.frost
            ? 'ice'
            : move.actionCue == BattleAction.heal
            ? 'heal'
            : move.actionCue == BattleAction.burst
            ? 'burst'
            : null,
        resolve: () => battle.resolveMove(move),
      );
      if (!mounted) return;
      battle.finishMove(move);
      if (!battle.active) {
        _clock?.cancel();
        widget.onSound(
          battle.status == BattleStatus.won ? 'promotion' : 'event',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _animate({
    required bool hero,
    required bool strike,
    bool magic = false,
    String? element,
    String? cue,
    required BattleImpact? Function() resolve,
  }) async {
    setState(() {
      _heroAttacks = hero;
      _strike = strike;
      _magic = magic;
      _element = element;
      _impact = null;
    });
    _motion.duration = magic
        ? castAnimationDuration
        : const Duration(milliseconds: 820);
    if (cue != null) widget.onSound(cue);
    final animation = _motion
        .forward(from: 0)
        .orCancel
        .then<void>((_) {}, onError: (Object _) {});
    await Future<void>.delayed(magic ? castContactDelay : physicalContactDelay);
    if (!mounted) return;
    setState(() {
      _impact = resolve();
      _message = _impact?.message ?? _message;
    });
    if ((_impact?.damage ?? 0) > 0)
      widget.onSound(hero ? (magic ? 'hit_magic' : 'hit_enemy') : 'hit_hero');
    await animation;
  }

  Future<void> _finish() async {
    if (_busy || battle.active) return;
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    var saved = false;
    try {
      saved = await widget.onSettle();
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _saveFailed = true;
      });
    }
  }

  Widget _bar(String label, int value, int maximum, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label  $value / $maximum',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          height: 1.2,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 3),
      TweenAnimationBuilder<double>(
        tween: Tween(end: value / maximum),
        duration: const Duration(milliseconds: 260),
        builder: (_, v, __) => LinearProgressIndicator(
          value: v,
          minHeight: 7,
          color: color,
          backgroundColor: Colors.black12,
        ),
      ),
    ],
  );

  Widget _status(bool hero) => Container(
    key: ValueKey(hero ? 'hero-status' : 'enemy-status'),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: GameDesign.ivory,
      border: Border.all(color: GameDesign.line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: hero
              ? '${battle.player.displayName} · ${battle.job?.title ?? "待業"} · Lv.${battle.player.level}'
              : battle.enemy.name,
          child: Text(
            hero
                ? '${battle.player.displayName} · Lv.${battle.player.level}'
                : battle.enemy.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              height: 1.2,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 3),
        _bar(
          'HP',
          hero ? battle.hp : battle.enemyHp,
          hero ? battle.maxHp : battle.enemy.hp,
          Colors.teal,
        ),
        const SizedBox(height: 4),
        _bar(
          '行動',
          ((hero ? battle.heroGauge : battle.enemyGauge) * 100).round(),
          100,
          hero ? GameDesign.gold : Colors.deepOrange,
        ),
        const SizedBox(height: 3),
        Text(
          '防禦 ${hero ? battle.heroDefense : battle.enemyDefense}'
          '${!hero && battle.finalEnraged ? " · 暴走 +${CardBattleTuning.finalEnrageAttack}" : ""}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            height: 1.2,
            fontSize: 12,
            color: !hero && battle.finalEnraged ? Colors.red : GameDesign.muted,
          ),
        ),
      ],
    ),
  );

  Future<void> _showDetails() async {
    if (_busy) return;
    if (battle.active) setState(() => _paused = true);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('戰況與牌效'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${battle.player.displayName} · ${battle.job?.title ?? "待業"}',
              ),
              Text(
                '武器：${weaponName(battle.player.weaponId)}\n防具：${weaponName(battle.player.armorId)}\n飾品：${weaponName(battle.player.accessoryId)}',
              ),
              const SizedBox(height: 12),
              Text(_message),
              if (_lastMove != null)
                Text(
                  '${_lastMove!.isHero ? "你" : battle.enemy.name}：${_lastMove!.label}',
                ),
              const SizedBox(height: 12),
              for (final card in battle.selectedCards)
                Text('${card.name}：${card.description}'),
              const Text('防禦抵擋下一次攻擊後消耗。'),
              if (widget.soundError?.call() != null)
                const Text('聲音未能播放，請點喇叭重試。'),
              if (battle.active) const Text('關閉後，按右上角「交鋒」繼續。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _portrait(bool hero, double width, double height) {
    if (hero)
      return CareerPortrait(
        equipment: EquipmentLook.fromPlayer(battle.player),
        jobId: battle.player.jobId,
        gender: battle.player.gender,
        width: width,
        height: height,
      );
    return Actor3D(
      enemy: battle.enemy.isBoss
          ? battle.enemy.bossStage - 1
          : battle.enemy.portrait,
      boss: battle.enemy.isBoss,
      width: width,
      height: height,
    );
  }

  Widget _arena(double height) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth;
      final actorWidth = math.min(210.0, width * .26);
      final actorHeight = math.min(height * .78, 245.0);
      return SizedBox(
        key: const ValueKey('battle-arena'),
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: ChapterBackdrop(stage: battle.player.currentStage),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0x22FFFFFF),
                        const Color(0x44807060),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DuelFloor(
                      actorWidth: actorWidth,
                      actorHeight: actorHeight,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: GameDesign.ink.withValues(alpha: .82),
                      border: Border.all(color: GameDesign.gold),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      battle.enemy.isBoss ? '命運試煉 · BOSS' : '旅途交鋒 · ENCOUNTER',
                      style: const TextStyle(
                        color: GameDesign.ivory,
                        fontSize: 10,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _motion,
                builder: (_, __) {
                  final t = _motion.value;
                  final lunge = !_strike
                      ? 0.0
                      : t < .25
                      ? t / .25
                      : t < .55
                      ? 1 - (t - .25) / .3
                      : 0.0;
                  final progress = ((t - _contact) / (1 - _contact))
                      .clamp(0.0, 1.0)
                      .toDouble();
                  return Stack(
                    children: [
                      for (final hero in [true, false])
                        Builder(
                          builder: (_) {
                            final x =
                                width * (hero ? .22 : .78) - actorWidth / 2;
                            final attacking = hero == _heroAttacks;
                            final target =
                                _impact != null &&
                                _impact!.targetsPlayer == hero;
                            final hit =
                                target &&
                                _impact!.damage > 0 &&
                                t >= _contact &&
                                t < _contact + .25;
                            final flash = hit && ((t * 22).floor().isEven);
                            final move = attacking
                                ? lunge * width * .34 * (hero ? 1 : -1)
                                : 0.0;
                            return Positioned(
                              left: x + move,
                              bottom: 26,
                              child: Transform.rotate(
                                angle: attacking && _strike
                                    ? lunge * (hero ? .12 : -.12)
                                    : 0,
                                child: Opacity(
                                  opacity: flash ? .25 : 1,
                                  child: _portrait(
                                    hero,
                                    actorWidth,
                                    actorHeight,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      if (_strike &&
                          _impact != null &&
                          _impact!.damage > 0 &&
                          t >= .25 &&
                          t < .65)
                        Positioned(
                          left:
                              width * (_impact!.targetsPlayer ? .22 : .78) - 45,
                          bottom: actorHeight * .45,
                          child: CustomPaint(
                            size: const Size(90, 90),
                            painter: _Slash(
                              progress: ((t - .25) / .4)
                                  .clamp(0.0, 1.0)
                                  .toDouble(),
                            ),
                          ),
                        ),
                      if (_magic && _motion.isAnimating)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: SpellEffect(
                                progress: t,
                                jobId: _heroAttacks
                                    ? battle.player.jobId
                                    : 'mage',
                                fromEnemy: !_heroAttacks,
                                element: _element,
                                reducedEffects: MediaQuery.disableAnimationsOf(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_impact != null &&
                          t >= _contact &&
                          (_impact!.damage > 0 ||
                              _impact!.healing > 0 ||
                              _impact!.spRecovered > 0))
                        Positioned(
                          left:
                              width * (_impact!.targetsPlayer ? .22 : .78) - 65,
                          bottom: (actorHeight * .72 + 30 + progress * 50)
                              .clamp(
                                0.0,
                                math.max(
                                  0.0,
                                  height -
                                      math.max(
                                        50.0,
                                        MediaQuery.textScalerOf(context)
                                                .scale(29) *
                                            1.3,
                                      ) -
                                      8,
                                ),
                              ),
                          child: Opacity(
                            opacity: 1 - progress,
                            child: SizedBox(
                              width: 130,
                              child: Text(
                                _impact!.floatingText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 29,
                                  fontWeight: FontWeight.w900,
                                  color: _impact!.damage > 0
                                      ? const Color(0xFFC54038)
                                      : const Color(0xFF007E60),
                                  shadows: const [
                                    Shadow(color: Colors.white, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _result() {
    final title = battle.timedOut
        ? '時間到 · 平手'
        : switch (battle.status) {
            BattleStatus.won => '戰鬥勝利',
            BattleStatus.lost => '戰鬥失敗',
            BattleStatus.escaped => '撤退成功',
            _ => '',
          };
    final money = battle.resultMoney;
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2CE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          Text(
            '經驗值 +${battle.earnedExperience}　金錢 ${money >= 0 ? "+" : ""}$money',
          ),
          if (battle.timedOut) const Text('本作平手獎勵；魔王未勝利不會換關。'),
          if (battle.status == BattleStatus.won)
            const Text('體力 +3　智力 +2　道德 +2'),
          if (battle.status == BattleStatus.lost && battle.enemy.isBoss)
            const Text('試煉心得：體力 +2、智力 +2；不扣金幣，可整備後重試'),
          if (battle.player.gainExperience(battle.earnedExperience).level >
              battle.player.level)
            Text(
              '升級！Lv.${battle.player.level} → Lv.${battle.player.gainExperience(battle.earnedExperience).level}',
            ),
          if (_saveFailed)
            const Text(
              '存檔未成功，請重試；不會重複領取獎勵。',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }

  Color _familyColor(CardFamily family) => switch (family) {
    CardFamily.blade => const Color(0xFF994D3C),
    CardFamily.shield => const Color(0xFF386C71),
    CardFamily.staff => const Color(0xFF68528A),
    CardFamily.magic => const Color(0xFFB4812E),
  };

  Widget _card(BattleCard card) {
    final selected = battle.selectedCardIds.contains(card.id);
    final color = _familyColor(card.family);
    return Semantics(
      button: true,
      selected: selected,
      label: '${card.name}，${card.description}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: 104,
        margin: EdgeInsets.only(
          top: selected ? 0 : 7,
          bottom: selected ? 7 : 0,
        ),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .13) : GameDesign.ivory,
          border: Border.all(
            color: selected ? color : GameDesign.line,
            width: selected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: selected ? .2 : .08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('card-${card.id}'),
            borderRadius: BorderRadius.circular(12),
            onTap: _canInteract ? () => _select(card.id) : null,
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          card.isModifier ? 'MAGIC' : card.family.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            height: 1.2,
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .7,
                          ),
                        ),
                      ),
                      Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        size: 14,
                        color: color,
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 42,
                    width: 65,
                    child: CustomPaint(
                      painter: BattleCardArt(card.family, color),
                    ),
                  ),
                  Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      height: 1.2,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.isModifier
                        ? card.magic == CardMagic.frost
                              ? '霜縛 · 延後行動'
                              : '${card.magic!.label} +${card.power}${card.magic == CardMagic.damage || card.magic == CardMagic.defense ? '%' : ''}'
                        : '⚔ ${card.attack}   ◆ ${card.defense}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      height: 1.2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _handPanel(double width) {
    final actions = <Widget>[
      FilledButton.icon(
        key: const ValueKey('play-cards'),
        onPressed:
            _canInteract && battle.heroReady && battle.selectionError == null
            ? _play
            : null,
        icon: const Icon(Icons.play_arrow, size: 18),
        label: Text(
          _busy
              ? '交鋒中'
              : battle.heroReady
              ? '出牌'
              : '蓄力中',
        ),
      ),
      OutlinedButton(
        key: const ValueKey('battle-potion'),
        onPressed: _canInteract && battle.canUseUtility(BattleAction.potion)
            ? () => _utility(BattleAction.potion)
            : null,
        child: Text('恢復藥 ${battle.potions}'),
      ),
      OutlinedButton(
        key: const ValueKey('battle-ether'),
        onPressed: _canInteract && battle.canUseUtility(BattleAction.ether)
            ? () => _utility(BattleAction.ether)
            : null,
        child: Text('專注飲 ${battle.ethers}'),
      ),
      TextButton(
        key: const ValueKey('battle-flee'),
        onPressed: _canInteract && battle.canUseUtility(BattleAction.flee)
            ? () => _utility(BattleAction.flee)
            : null,
        child: const Text('撤退 65%'),
      ),
    ];
    Widget actionRow(List<Widget> buttons) => Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: SizedBox(height: 48, child: buttons[i])),
        ],
      ],
    );
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 4),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(height: 1.2, fontSize: 12, fontWeight: FontWeight.w700),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    );
    return Container(
      key: const ValueKey('battle-hand-panel'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: GameDesign.ivory,
        border: Border.all(color: GameDesign.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '手牌 · 同系＋魔法',
                  maxLines: 1,
                  style: TextStyle(
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '攻 ${battle.selectedAttack} / 防 ${battle.selectedDefense}',
                style: const TextStyle(
                  height: 1.2,
                  fontSize: 12,
                  color: GameDesign.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height:
                124 *
                math.max(1.0, MediaQuery.textScalerOf(context).scale(14) / 14),
            child: SingleChildScrollView(
              key: const ValueKey('battle-card-rail'),
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final card in battle.hand)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _card(card),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Tooltip(
            message: battle.selectedCards
                .map((c) => '${c.name}：${c.description}')
                .join('；'),
            child: Text(
              battle.selectionError ??
                  '已選 ${battle.selectedCards.length} 張 · 可出牌',
              key: const ValueKey('battle-selection'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                height: 1.2,
                fontSize: 12,
                color: GameDesign.forest,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Theme(
            data: Theme.of(context).copyWith(
              filledButtonTheme: FilledButtonThemeData(style: style),
              outlinedButtonTheme: OutlinedButtonThemeData(style: style),
              textButtonTheme: TextButtonThemeData(style: style),
            ),
            child: width < BattleViewport.narrowHandWidth
                ? Column(
                    children: [
                      actionRow(actions.take(2).toList()),
                      const SizedBox(height: 4),
                      actionRow(actions.skip(2).toList()),
                    ],
                  )
                : actionRow(actions),
          ),
        ],
      ),
    );
  }

  Widget _arenaWithPause(double height) => Stack(
    children: [
      _arena(height),
      if (_paused && battle.active)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: GameDesign.ink.withValues(alpha: .82),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '交鋒已暫停',
                  style: TextStyle(
                    color: GameDesign.ivory,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('resume-card-battle'),
                  onPressed: _background || _busy ? null : _pauseOrResume,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('繼續交鋒'),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _battleCanvas(BattleViewport layout) {
    Widget field() => Column(
      children: [
        SizedBox(
          height: layout.statusHeight,
          child: Row(
            children: [
              Expanded(child: _status(true)),
              const SizedBox(width: 8),
              Expanded(child: _status(false)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) => _arenaWithPause(box.maxHeight),
          ),
        ),
        SizedBox(
          height: layout.messageHeight,
          child: Center(
            child: Text(
              widget.soundError?.call() != null ? '聲音未能播放，請點喇叭重試。' : _message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
    return SizedBox(
      width: layout.canvasWidth,
      height: layout.canvasHeight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: layout.sideBySide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: field()),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: layout.handWidth,
                    child: _handPanel(layout.handWidth),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(child: field()),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: layout.handHeight,
                    child: _handPanel(layout.handWidth),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _activeBody() => LayoutBuilder(
    builder: (context, box) {
      final layout = BattleViewport.plan(
        box.maxWidth,
        box.maxHeight,
        textScale: MediaQuery.textScalerOf(context).scale(14) / 14,
      );
      if (!layout.needsScroll) return _battleCanvas(layout);
      // Deliberate accessibility fallback: retain readable controls on tiny or
      // heavily zoomed windows. Only this explicit mode scrolls vertically.
      return Column(
        children: [
          const SizedBox(
            height: 28,
            child: Center(
              child: Text(
                '視窗較小：可捲動',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('battle-small-viewport-scroll'),
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: layout.canvasWidth,
                child: SingleChildScrollView(child: _battleCanvas(layout)),
              ),
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: GameDesign.paper,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 56,
        titleSpacing: 10,
        title: Text(
          battle.turnMode ? '終章 · 輪流卡牌試煉' : '卡牌交鋒',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (MediaQuery.sizeOf(context).width >= 440 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18.2 &&
              widget.onToggleSound != null)
            IconButton(
              tooltip: (widget.soundEnabled?.call() ?? false) ? '關閉音效' : '開啟音效',
              icon: Icon(
                (widget.soundEnabled?.call() ?? false)
                    ? Icons.volume_up
                    : Icons.volume_off,
              ),
              onPressed: () async {
                try {
                  await widget.onToggleSound!();
                } catch (_) {}
                if (mounted) setState(() {});
              },
            ),
          if (MediaQuery.sizeOf(context).width >= 440 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18.2)
            IconButton(
              tooltip: '戰況與牌效',
              onPressed: _busy ? null : _showDetails,
              icon: const Icon(Icons.info_outline),
            ),
          if (MediaQuery.sizeOf(context).width < 440 ||
              MediaQuery.textScalerOf(context).scale(14) > 18.2)
            PopupMenuButton<String>(
              tooltip: '戰鬥更多操作',
              onSelected: (action) async {
                if (action == 'details') {
                  await _showDetails();
                  return;
                }
                try {
                  await widget.onToggleSound?.call();
                } catch (_) {}
                if (mounted) setState(() {});
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'details',
                  enabled: !_busy,
                  child: const Text('戰況與牌效'),
                ),
                if (widget.onToggleSound != null)
                  PopupMenuItem(
                    value: 'sound',
                    child: Text(
                      (widget.soundEnabled?.call() ?? false) ? '關閉音效' : '開啟音效',
                    ),
                  ),
              ],
            ),
          TextButton.icon(
            key: const ValueKey('pause-card-battle'),
            onPressed: _busy || !battle.active || _background
                ? null
                : _pauseOrResume,
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause, size: 20),
            label: Text(_paused ? '交鋒' : '暫停', maxLines: 1),
            style: TextButton.styleFrom(
              minimumSize: const Size(76, 48),
              textStyle: const TextStyle(fontSize: 13, height: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                battle.turnMode
                    ? '第 ${battle.round + 1} 手'
                    : '${(battle.remainingMilliseconds / 1000).ceil()} 秒',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: battle.active || _busy
            ? _activeBody()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(children: [_result()]),
              ),
      ),
      bottomNavigationBar: battle.active
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: FilledButton(
                  key: const ValueKey('settle-card-battle'),
                  onPressed: _busy ? null : _finish,
                  child: Text(
                    _busy
                        ? '處理中…'
                        : _saveFailed
                        ? '重試存檔並返回'
                        : '結算並返回大地圖',
                  ),
                ),
              ),
            ),
    ),
  );
}

/// Framed tabletop arena, drawn below the animated actors and hit effects.
class _DuelFloor extends CustomPainter {
  const _DuelFloor({required this.actorWidth, required this.actorHeight});
  final double actorWidth, actorHeight;
  @override
  void paint(Canvas canvas, Size size) {
    // Same portrait camera and bottom placement as Actor3D, so the engraved
    // plinth meets the feet across both narrow and wide battle arenas.
    const camera = Camera3D(
      eye: V3(-2.6, 2.3, 5),
      target: V3(0, 1, 0),
      focal: 2.25,
    );
    final feet = camera.project(
      const V3(0, .035, 0),
      Size(actorWidth, actorHeight),
    );
    final y = size.height - 26 - actorHeight + (feet?.dy ?? actorHeight);
    final pen = Paint()
      ..color = const Color(0x38FFF1C8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final x in [.22, .78]) {
      final oval = Rect.fromCenter(
        center: Offset(size.width * x, y),
        width: size.width * .26,
        height: 30,
      );
      canvas.drawOval(
        oval.shift(const Offset(0, 5)),
        Paint()..color = const Color(0x24213F37),
      );
      canvas.drawOval(oval, Paint()..color = const Color(0x3678876A));
      canvas.drawOval(oval, pen);
      canvas.drawOval(oval.deflate(5), pen);
    }
    final border = RRect.fromRectAndRadius(
      Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
      const Radius.circular(16),
    );
    canvas.drawRRect(border, pen..color = const Color(0xA0E6CE9A));
    for (final x in [20.0, size.width - 20])
      for (final y in [20.0, size.height - 20]) {
        final gem = Path()
          ..moveTo(x, y - 4)
          ..lineTo(x + 4, y)
          ..lineTo(x, y + 4)
          ..lineTo(x - 4, y)
          ..close();
        canvas.drawPath(gem, Paint()..color = const Color(0xFFD7B56B));
      }
  }

  @override
  bool shouldRepaint(covariant _DuelFloor oldDelegate) =>
      oldDelegate.actorWidth != actorWidth ||
      oldDelegate.actorHeight != actorHeight;
}

class _Slash extends CustomPainter {
  const _Slash({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 1 - progress)
      ..strokeWidth = 8 * (1 - progress) + 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .1, size.height * .9),
      Offset(size.width * .9, size.height * .1),
      paint,
    );
    paint
      ..color = const Color(0xFFFFC957).withValues(alpha: 1 - progress)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(size.width * .2, size.height),
      Offset(size.width, size.height * .2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _Slash oldDelegate) =>
      oldDelegate.progress != progress;
}
