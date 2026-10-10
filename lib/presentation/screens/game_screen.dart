import 'dart:async';

import '../../domain/models/stage.dart';
import '../../domain/services/stage_service.dart';
import 'shop_screen.dart';
import 'equipment_screen.dart';
import 'victory_screen.dart';
import 'life_journal_screen.dart';
import 'life_story_screen.dart';
import '../widgets/story_choice_dialog.dart';
import '../../domain/models/age_board.dart';
import '../../domain/models/acceptance_scenarios.dart';
import '../../domain/services/story_service.dart';
import '../../domain/services/life_service.dart';
import '../../domain/services/shop_service.dart';

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../../domain/models/battle.dart';
import '../../domain/models/card_battle.dart';
import '../battle/card_battle_screen.dart';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/player_controller.dart';
import '../../application/turn_controller.dart';
import '../../application/content_providers.dart';
import '../../application/save_providers.dart';
import '../../domain/models/player.dart';
import '../game/life_game.dart';
import '../services/game_audio.dart';
import '../services/battle_audio_cues.dart';
import '../widgets/game_dashboard.dart';
import '../widgets/choice_event_dialog.dart';
import '../widgets/dice_display.dart';
import '../widgets/career_dialog.dart';
import '../widgets/card_battle_tutorial.dart';
import '../art/atlas_portrait.dart';
import '../three_d/models_3d.dart';
import '../widgets/chapter_backdrop.dart';
import '../theme/game_design.dart';
import '../art/equipment_layers.dart';
import '../../domain/models/board_tile.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});
  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  LifeGame? _game;
  final _boardKey = GlobalKey();
  final List<String> _history = [];
  int _turnNumber = 0;
  int? _diceFace;
  List<Enemy> _enemies = [];
  late StageService _stages;

  void _record(String message) {
    if (!mounted) return;
    setState(() {
      _history.insert(0, message);
      if (_history.length > 60) _history.removeLast();
    });
  }

  final GameAudio _audio = GameAudio();
  bool _entered = false;
  bool _soundOn = false;
  bool _audioBusy = false;
  bool _busy = true;
  bool _contentReady = false;
  bool _bossInFlight = false;
  String? _loadError;
  String? _saveError;
  String _saveMessage = '尚未存檔';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_initialize);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _game?.resumeEngine();
      unawaited(_audio.setForeground(true));
    } else {
      _game?.pauseEngine();
      unawaited(_audio.setForeground(false));
    }
  }

  LifeGame _createBoard(int position) => LifeGame(
    age: ref.read(playerProvider).life.age,
    equipment: EquipmentLook.fromPlayer(ref.read(playerProvider)),
    stage: ref.read(playerProvider).currentStage,
    initialPosition: position,
    jobId: ref.read(playerProvider).jobId,
    gender: ref.read(playerProvider).gender,
    onBoardReady: () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    },
  );

  Future<void> _toggleAudio() async {
    if (_audioBusy) return;
    setState(() => _audioBusy = true);
    await _audio.setEnabled(_audio.error != null || !_audio.enabled);
    if (!mounted) return;
    setState(() {
      _soundOn = _audio.enabled;
      _audioBusy = false;
    });
    if (_audio.error != null)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('聲音未能啟動，請再點一次音樂按鈕。遊戲仍可繼續。')));
  }

  void _enterGame() {
    setState(() => _entered = true);
    unawaited(_audio.music(stageMusic(ref.read(playerProvider).currentStage)));
    unawaited(_audio.sfx('click'));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_runPendingBoss()),
    );
  }

  Widget _soundButton() => IconButton(
    tooltip: _soundOn ? '關閉音樂與音效' : '開啟音樂與音效',
    onPressed: _audioBusy ? null : _toggleAudio,
    icon: Icon(_soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded),
  );

  Widget _titleScreen() => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const ChapterBackdrop(stage: 1),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xB5F5EFDF), Color(0x00F5EFDF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(alignment: Alignment.topRight, child: _soundButton()),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: GameDesign.ivory.withValues(alpha: .95),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: GameDesign.line),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x24313529),
                                blurRadius: 36,
                                offset: Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.explore_outlined,
                                    color: GameDesign.gold,
                                    size: 26,
                                  ),
                                  SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      'LIFE BOARD  /  CHRONICLES',
                                      style: TextStyle(
                                        fontSize: 11,
                                        letterSpacing: 1.7,
                                        color: GameDesign.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                '人生棋盤',
                                style: TextStyle(
                                  fontSize: 44,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3,
                                  color: GameDesign.ink,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: 64,
                                height: 3,
                                color: GameDesign.gold,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                '擲骰走過四季，學會一生的本領。\n把這一世的成長，帶往下一世。',
                                style: TextStyle(
                                  fontSize: 17,
                                  height: 1.8,
                                  color: GameDesign.muted,
                                ),
                              ),
                              const SizedBox(height: 26),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _enterGame,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('開始／繼續人生'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _canCustomize
                                      ? _chooseCharacter
                                      : null,
                                  icon: const Icon(Icons.person_outline),
                                  label: const Text('選擇男女角色'),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Divider(height: 1),
                              Row(
                                children: [
                                  CareerPortrait(
                                    equipment: EquipmentLook.fromPlayer(
                                      ref.watch(playerProvider),
                                    ),
                                    jobId: ref.watch(playerProvider).jobId,
                                    gender: ref.watch(playerProvider).gender,
                                    width: 66,
                                    height: 88,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _saveMessage,
                                      style: const TextStyle(
                                        color: GameDesign.muted,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                '六章旅途・四季成長・一生收藏',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  color: GameDesign.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _initialize() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _loadError = null;
    });
    try {
      await ref.read(contentReadyProvider.future);
      final enemyJson = jsonDecode(
        await rootBundle.loadString('assets/data/enemies.json'),
      ) as List;
      _enemies = enemyJson
          .map((e) => Enemy.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final stageJson = jsonDecode(
        await rootBundle.loadString('assets/data/stages.json'),
      ) as List;
      _stages = StageService(
        stageJson
            .map((j) => GameStage.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList(),
      );
      if (_enemies.isEmpty) throw const FormatException('敵人資料不可為空');
      for (final event in await ref.read(tileEventManagerProvider).load()) {
        for (final option in event.options) {
          if (option.battleEnemyId != null &&
              !_enemies.any((e) => e.id == option.battleEnemyId)) {
            throw const FormatException('事件指定的敵人不存在');
          }
        }
      }
      if (!mounted) return;
      _contentReady = true;
      final ids = ref.read(jobManagerProvider).jobs.map((j) => j.id).toSet();
      final saved = await ref.read(saveRepositoryProvider).load(ids);
      if (!mounted) return;
      final player = saved?.player ?? const Player();
      _turnNumber = player.life.turns;
      ref.read(playerProvider.notifier).replace(player);
      setState(() {
        _game = _createBoard(player.position);
        _saveMessage = saved == null ? '新遊戲：完成回合後自動存檔' : '已讀取上次進度';
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkpoint() async {
    try {
      _game?.changeAge(ref.read(playerProvider).life.age);
      await ref.read(saveRepositoryProvider).save(ref.read(playerProvider));
      if (mounted)
        setState(() {
          _saveError = null;
          _saveMessage = '已自動存檔';
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _saveError = error.toString();
          _saveMessage = '存檔失敗，請重試';
        });
    }
  }

  Future<void> _retrySave() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _checkpoint();
      if (_saveError == null) unawaited(_audio.sfx('save'));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _runPendingBoss();
      }
    }
  }

  Future<void> _restart() async {
    if (_busy ||
        !_contentReady ||
        ref.read(turnProvider).phase != TurnPhase.idle)
      return;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('重新開始？'),
          content: const Text(
            '目前存檔將被全新第一世取代。位置、屬性、金錢、職業、裝備、人生關係、房屋、所有心得及歷代結局記錄都會重置。若想保留一項心得，請取消並到人生手帳選擇轉生。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('重新開始'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      // Persist first. If writing fails, keep the existing on-screen progress.
      await ref.read(saveRepositoryProvider).reset();
      if (!mounted) return;
      ref.read(playerProvider.notifier).replace(const Player());
      ref.invalidate(turnProvider);
      final game = _game;
      if (game == null) {
        _game = _createBoard(0);
      } else if (game.isBoardReady) {
        game.pawn.resetTo(game.pawnCenter(0));
        game.changeCareer('unemployed', gender: CharacterGender.male);
        game.changeStage(1);
        game.changeAge(18);
        game.changeEquipment(const EquipmentLook());
      } else {
        // Disable restart during normal board loading; this branch is defensive.
        _game = _createBoard(0);
      }
      setState(() {
        _loadError = null;
        _saveError = null;
        _saveMessage = '已建立新存檔';
        _history.clear();
        _turnNumber = 0;
        _diceFace = null;
      });
      unawaited(_audio.sfx('save'));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('重新開始失敗，進度未重置：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canCustomize =>
      !_busy &&
      _saveError == null &&
      ref.read(turnProvider).phase == TurnPhase.idle;

  Future<Player> _persistPlayer(Player candidate) async {
    await ref.read(saveRepositoryProvider).save(candidate);
    if (!mounted) return candidate;
    ref.read(playerProvider.notifier).replace(candidate);
    _game?.changeEquipment(EquipmentLook.fromPlayer(candidate));
    _game?.changeAge(candidate.life.age);
    setState(() => _saveMessage = '已自動存檔');
    return candidate;
  }

  Future<void> _prepareBoss() async {
    if (!_canCustomize || !ref.read(playerProvider).bossPending) return;
    setState(() => _busy = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ShopScreen(
            player: ref.read(playerProvider),
            onAction: (id, equip) async {
              final current = ref.read(playerProvider);
              const service = ShopService();
              return _persistPlayer(
                equip ? service.equip(current, id) : service.buy(current, id),
              );
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openShop() async {
    final turn = ref.read(turnProvider);
    if (turn.phase != TurnPhase.resolving || !turn.shopChoice) return;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ShopScreen(
            player: ref.read(playerProvider),
            onAction: (id, equip) async {
              final current = ref.read(playerProvider);
              const service = ShopService();
              return _persistPlayer(
                equip ? service.equip(current, id) : service.buy(current, id),
              );
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        ref.read(turnProvider.notifier).finishShop();
        _record('離開商店街');
        await _checkpoint();
      }
    }
  }

  Future<void> _loadAcceptanceScenario() async {
    if (!acceptanceMode || !_canCustomize) return;
    setState(() => _busy = true);
    try {
      var closing = false;
      void dismiss(BuildContext ctx, String? id) {
        if (closing) return;
        closing = true;
        Navigator.pop(ctx, id);
      }

      final id = await showDialog<String>(
        context: context,
        builder: (ctx) => PopScope<String>(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) closing = true;
          },
          child: AlertDialog(
            title: const Text('載入驗收情境'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('只取代獨立驗收存檔，不讀寫正式遊戲的存檔。請選擇要測試的階段。'),
                    for (final entry in acceptanceScenarioLabels.entries)
                      ListTile(
                        title: Text(entry.value),
                        onTap: () => dismiss(ctx, entry.key),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => dismiss(ctx, null),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      );
      if (id == null || !mounted) return;
      final saved = await _persistPlayer(acceptanceScenario(id));
      if (!mounted) return;
      ref.invalidate(turnProvider);
      final game = _game;
      if (game != null && game.isBoardReady) {
        game.pawn.resetTo(game.pawnCenter(saved.position));
        game.changeCareer(saved.jobId, gender: saved.gender);
        game.changeEquipment(EquipmentLook.fromPlayer(saved));
        game.changeStage(saved.currentStage);
        game.changeAge(saved.life.age);
      } else {
        _game = _createBoard(saved.position);
      }
      setState(() {
        _history.clear();
        _turnNumber = saved.life.turns;
        _diceFace = null;
      });
      _record('驗收情境：${acceptanceScenarioLabels[id]}');
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('驗收情境載入失敗：$error')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _runPendingBoss();
      }
    }
  }

  Future<void> _openLifeStory() async {
    if (!_canCustomize) return;
    setState(() => _busy = true);
    try {
      await Navigator.of(context).push<Player>(
        MaterialPageRoute<Player>(
          builder: (_) => LifeStoryScreen(
            player: ref.read(playerProvider),
            jobTitle: (id) => ref.read(jobManagerProvider).byId(id).title,
            onRelationship: (action, npcId) => _persistPlayer(
              const StoryService().perform(
                ref.read(playerProvider),
                action,
                npcId: npcId,
              ),
            ),
            onStoryChoice: (chainId, expectedStep, optionId) => _persistPlayer(
              const StoryService().chooseStory(
                ref.read(playerProvider),
                chainId,
                optionId,
                expectedStep: expectedStep,
              ),
            ),
            onConclude: (endingId) => _persistPlayer(
              const StoryService().concludeLife(
                ref.read(playerProvider),
                endingId,
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLifeJournal() async {
    if (!_canCustomize) return;
    setState(() => _busy = true);
    try {
      await Navigator.of(context).push<Player>(
        MaterialPageRoute<Player>(
          builder: (_) => LifeJournalScreen(
            player: ref.read(playerProvider),
            jobTitle: (id) => ref.read(jobManagerProvider).byId(id).title,
            onAction: (action) async {
              final candidate = const StoryService().settleSeason(
                const LifeService().lifeAction(
                  ref.read(playerProvider),
                  action,
                ),
              );
              final saved = await _persistPlayer(candidate);
              _record(
                '${saved.life.age} 歲・${saved.life.season}季：${const LifeService().actionDescription(action)}',
              );
              return saved;
            },
            onReincarnate: (skill) async {
              final candidate = const StoryService().reincarnate(
                ref.read(playerProvider),
                inheritSkill: skill,
              );
              final saved = await _persistPlayer(candidate);
              if (!mounted) return saved;
              ref.invalidate(turnProvider);
              final game = _game;
              if (game != null && game.isBoardReady) {
                game.pawn.resetTo(game.pawnCenter(0));
                game.changeCareer(saved.jobId, gender: saved.gender);
                game.changeStage(saved.currentStage);
                game.changeEquipment(EquipmentLook.fromPlayer(saved));
              } else {
                _game = _createBoard(0);
              }
              setState(() {
                _turnNumber = 0;
                _diceFace = null;
                _history.clear();
              });
              _record(
                '第 ${saved.life.generation} 世開始。${skill == null ? "不攜帶天賦，重新探索。" : "繼承 ${ref.read(jobManagerProvider).byId(skill).title} 天賦。"}',
              );
              unawaited(_audio.music(stageMusic(saved.currentStage)));
              return saved;
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEquipment() async {
    if (!_canCustomize) return;
    setState(() => _busy = true);
    try {
      final player = ref.read(playerProvider);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EquipmentScreen(
            player: player,
            jobTitle: ref.read(jobManagerProvider).byId(player.jobId).title,
            onEquip: (id, slot) => _persistPlayer(
              const ShopService().equip(
                ref.read(playerProvider),
                id,
                slot: slot,
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseCharacter() async {
    if (!_canCustomize) return;
    setState(() => _busy = true);
    try {
      final player = ref.read(playerProvider);
      final selected = await showDialog<CharacterGender>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('選擇角色'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('男女角色能力相同，保留目前職業、屬性與背包。'),
                for (final gender in CharacterGender.values)
                  ListTile(
                    leading: CareerPortrait(
                      equipment: EquipmentLook.fromPlayer(player),
                      jobId: player.jobId,
                      gender: gender,
                      width: 42,
                      height: 56,
                    ),
                    title: Text(
                      gender == CharacterGender.male ? '男生 · 阿晨' : '女生 · 小晴',
                    ),
                    trailing: player.gender == gender
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(ctx, gender),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        ),
      );
      if (selected == null || !mounted || selected == player.gender) return;
      await _persistPlayer(player.copyWith(gender: selected));
      if (mounted) _game?.changeCareer(player.jobId, gender: selected);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('角色切換未完成：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runPendingBoss() async {
    if (!mounted ||
        !_entered ||
        _busy ||
        _bossInFlight ||
        _saveError != null ||
        !_contentReady ||
        ref.read(turnProvider).phase != TurnPhase.idle ||
        !ref.read(playerProvider).bossPending)
      return;
    setState(() {
      _busy = true;
      _bossInFlight = true;
    });
    try {
      await _runBattle(null, isStageBoss: true);
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _bossInFlight = false;
        });
    }
  }

  Future<void> _roll() async {
    if (ref.read(playerProvider).bossPending) {
      await _runPendingBoss();
      return;
    }
    final game = _game;
    if (_busy || _saveError != null || game == null || !game.isBoardReady)
      return;
    final turns = ref.read(turnProvider.notifier);
    final from = ref.read(playerProvider).position;
    final steps = turns.beginTurn();
    if (steps == null) return;
    setState(() => _busy = true);
    _turnNumber = ref.read(playerProvider).life.turns + 1;

    unawaited(_audio.sfx('dice'));
    try {
      for (var tick = 0; tick < 12; tick++) {
        if (!mounted) return;
        setState(() => _diceFace = (tick % 6) + 1);
        await Future<void>.delayed(Duration(milliseconds: 45 + tick * 6));
      }
      if (!mounted) return;
      setState(() => _diceFace = steps);
      turns.finishRoll();
      _record('第 $_turnNumber 回合 · 擲出 $steps 點');
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (!mounted) return;
      final moved = await game.move(
        from: from,
        steps: steps,
        onPosition: (index) {
          if (mounted) {
            ref.read(playerProvider.notifier).moveTo(index);
            unawaited(_audio.sfx('step'));
          }
        },
      );
      if (!mounted || !moved) return;
      await turns.land();
      if (!mounted) return;
      final resolution = ref.read(turnProvider);
      if (resolution.phase != TurnPhase.resolving) {
        _record(
          '抵達第 ${ref.read(playerProvider).position + 1} 格\n${resolution.message}',
        );
        unawaited(_audio.sfx('stat_up'));
        await _checkpoint();
        return;
      }
      if (resolution.shopChoice) {
        _record('抵達第 ${ref.read(playerProvider).position + 1} 格 · 商店街');
        await _openShop();
        return;
      }
      if (resolution.battleChoice) {
        await _runBattle(resolution.battleEnemyId);
        return;
      }
      if (resolution.storyEvent != null) {
        final optionId = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => StoryChoiceDialog(chapter: resolution.storyEvent!),
        );
        if (!mounted) return;
        if (optionId != null && turns.finishStory(optionId)) {
          _record(ref.read(turnProvider).message);
          await _checkpoint();
        }
        return;
      }
      if (resolution.choiceEvent != null) {
        final event = resolution.choiceEvent!;
        unawaited(_audio.sfx('event'));
        final selectedOption = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ChoiceEventDialog(
            event: event,
            livingCost: const StoryService().livingCost(
              ref.read(playerProvider),
            ),
            workPercent: event.kind == TileKind.work
                ? ref
                      .read(jobManagerProvider)
                      .byId(ref.read(playerProvider).jobId)
                      .workPercent
                : 100,
          ),
        );
        if (!mounted) return;
        if (selectedOption != null && turns.finishChoice(selectedOption)) {
          _record(ref.read(turnProvider).message);
          if (ref.read(turnProvider).battleChoice) {
            await _runBattle(ref.read(turnProvider).battleEnemyId);
          } else {
            await _checkpoint();
          }
        }
        return;
      }
      String? selected;
      if (resolution.careerChoice) {
        unawaited(_audio.music('evening'));
        final jobs = ref.read(jobManagerProvider);
        final player = ref.read(playerProvider);
        selected = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => CareerDialog(player: player, jobs: jobs),
        );
      }
      if (mounted) {
        turns.finishResolution(targetJobId: selected);
        _game?.changeCareer(ref.read(playerProvider).jobId);
        if (resolution.careerChoice) {
          _record(ref.read(turnProvider).message);
          unawaited(
            _audio.music(stageMusic(ref.read(playerProvider).currentStage)),
          );
          unawaited(_audio.sfx(selected == null ? 'click' : 'promotion'));
          await _checkpoint();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _runPendingBoss();
      }
    }
  }

  Future<void> _runBattle(String? enemyId, {bool isStageBoss = false}) async {
    final tier = ref
        .read(jobManagerProvider)
        .byId(ref.read(playerProvider).jobId)
        .tier;
    final pool = _enemies.where((e) => e.minTier <= tier).toList();
    var enemy = enemyId == null
        ? pool[Random().nextInt(pool.length)]
        : _enemies.firstWhere((e) => e.id == enemyId);
    final player = ref.read(playerProvider);
    final stage = _stages.current(player);
    if (isStageBoss) {
      if (!stage.bossReady(player)) return;
      enemy = stage.boss;
    }
    if (!enemy.isBoss) enemy = _stages.scaleEnemy(enemy, player);
    final battle = CardBattleSession(
      player,
      enemy,
      job: ref.read(jobManagerProvider).byId(player.jobId),
    );
    var applied = false;
    _record('遭遇 ${enemy.name}');
    _game?.pauseEngine();
    unawaited(_audio.music(enemy.isBoss ? 'boss' : 'battle'));
    try {
      await Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 380),
          pageBuilder: (_, __, ___) => CardBattleScreen(
            session: battle,
            onSound: (name) => unawaited(_audio.sfx(name)),
            onToggleSound: _toggleAudio,
            soundEnabled: () => _audio.enabled,
            soundError: () => _audio.error,
            onSettle: () async {
              if (!mounted || battle.active) return false;
              if (!applied) {
                final reward = battle.claim();
                if (reward == null) return false;
                final result = battle.timedOut
                    ? '與 ${enemy.name} 戰至平手：EXP +${battle.earnedExperience}，${reward.summary}'
                    : switch (battle.status) {
                        BattleStatus.won =>
                          '戰勝 ${enemy.name}：EXP +${battle.earnedExperience}，${reward.summary}',
                        BattleStatus.lost =>
                          '戰敗：EXP +0，${reward.summary.isEmpty ? "無金錢損失" : reward.summary}',
                        _ => '已從 ${enemy.name} 撤退，無獎懲',
                      };
                if (isStageBoss) {
                  // A threshold boss is separate from its already-completed map turn.
                  ref
                      .read(playerProvider.notifier)
                      .replace(
                        ref
                            .read(playerProvider)
                            .apply(reward)
                            .gainExperience(battle.earnedExperience)
                            .copyWith(inventory: battle.remainingInventory),
                      );
                } else {
                  ref
                      .read(turnProvider.notifier)
                      .finishBattle(
                        reward,
                        result,
                        experience: battle.earnedExperience,
                        inventory: battle.remainingInventory,
                      );
                }
                final progressed = _stages.settle(
                  ref.read(playerProvider),
                  enemy,
                  battle.status,
                );
                ref.read(playerProvider.notifier).replace(progressed);
                _game?.changeStage(progressed.currentStage);
                if (progressed.clearedStages > player.clearedStages &&
                    _game!.isBoardReady) {
                  _game!.pawn.resetTo(_game!.pawnCenter(0));
                }
                applied = true;
                _record(result);
              }
              await _checkpoint();
              return mounted && _saveError == null;
            },
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
      if (mounted &&
          ref.read(playerProvider).clearedStages > player.clearedStages) {
        final updated = ref.read(playerProvider);
        if (updated.campaignComplete) {
          await _showEnding(updated);
        } else {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                updated.campaignComplete ? '六關全破！' : '第 ${stage.id} 關通關',
              ),
              content: Text(
                updated.campaignComplete
                    ? '你擊敗了命運編織者，取回選擇人生的自由！可以繼續在星界養成與購物。'
                    : '已解鎖第 ${updated.currentStage} 關：${_stages.current(updated).title}。\n屬性、職業、裝備與背包均保留。${updated.currentStage == 6 ? '\n終章武器已解鎖：走到商店格購買並裝備，可提高對最終魔王的傷害。' : ''}',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('繼續冒險'),
                ),
              ],
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        _game?.resumeEngine();
        unawaited(
          _audio.music(stageMusic(ref.read(playerProvider).currentStage)),
        );
      }
    }
  }

  Future<void> _showEnding(Player player) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => VictoryScreen(
        player: player,
        jobTitle: ref.read(jobManagerProvider).byId(player.jobId).title,
      ),
    ),
  );
  Future<void> _replayEnding() async {
    if (!_canCustomize || !ref.read(playerProvider).campaignComplete) return;
    setState(() => _busy = true);
    try {
      await _showEnding(ref.read(playerProvider));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showStages() async {
    final p = ref.read(playerProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('六關人生旅程'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('每張地圖完成 ${p.turnsPerStage} 回合後自動迎戰魔王，僅勝利可前進。'),
              const Text('地圖開始前可選 4／8／12 回合；進行中不可更改。'),
              Wrap(
                spacing: 8,
                children: [
                  for (final count in [4, 8, 12])
                    ChoiceChip(
                      label: Text('$count 回合'),
                      selected: p.turnsPerStage == count,
                      onSelected: p.stageTurns == 0 && !p.campaignComplete
                          ? (_) async {
                              Navigator.pop(ctx);
                              setState(() => _busy = true);
                              try {
                                await _persistPlayer(
                                  _stages.configureTurns(
                                    ref.read(playerProvider),
                                    count,
                                  ),
                                );
                              } catch (e) {
                                if (mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('設定未儲存：$e')),
                                  );
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            }
                          : null,
                    ),
                ],
              ),
              for (final s in _stages.stages)
                ListTile(
                  leading: Icon(
                    s.id <= p.clearedStages
                        ? Icons.check_circle
                        : s.id == p.currentStage
                        ? Icons.flag
                        : Icons.lock,
                  ),
                  title: Text(
                    '${s.id}. ${s.title} · ${s.id == 6 ? "最終魔王" : "普通魔王"}',
                  ),
                  subtitle: Text('${s.boss.name}\n${s.story}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_audio.dispose());
    super.dispose();
  }

  Future<void> _showCardBattleTutorial() async {
    if (!_canCustomize || ModalRoute.of(context)?.isCurrent != true) return;
    await showDialog<void>(
      context: context,
      builder: (_) => const CardBattleTutorialDialog(),
    );
  }

  List<Widget> _appActions(Player player, TurnState turn) {
    if (MediaQuery.sizeOf(context).width >= 1000)
      return [
        TextButton.icon(
          key: const ValueKey('board-card-tutorial'),
          onPressed: _canCustomize ? _showCardBattleTutorial : null,
          icon: const Icon(Icons.style_outlined),
          label: const Text('戰鬥卡牌教學'),
        ),
        if (acceptanceMode)
          IconButton(
            tooltip: '載入獨立驗收情境',
            onPressed: _canCustomize ? _loadAcceptanceScenario : null,
            icon: const Icon(Icons.science_outlined),
          ),
        if (player.campaignComplete)
          IconButton(
            tooltip: '重看破關畫面',
            onPressed: _canCustomize ? _replayEnding : null,
            icon: const Icon(Icons.emoji_events_outlined),
          ),
        IconButton(
          tooltip: '人物裝備',
          onPressed: _canCustomize ? _openEquipment : null,
          icon: const Icon(Icons.shield_outlined),
        ),
        IconButton(
          tooltip: '六關旅程',
          onPressed: _canCustomize ? _showStages : null,
          icon: const Icon(Icons.flag_outlined),
        ),
        IconButton(
          tooltip: '選擇角色',
          onPressed: _canCustomize ? _chooseCharacter : null,
          icon: const Icon(Icons.person),
        ),
        _soundButton(),
        TextButton(
          onPressed:
              !_busy && turn.phase == TurnPhase.idle && _game!.isBoardReady
              ? _restart
              : null,
          child: const Text('重新開始'),
        ),
      ];
    final canRestart =
        !_busy && turn.phase == TurnPhase.idle && _game!.isBoardReady;
    return [
      _soundButton(),
      PopupMenuButton<String>(
        tooltip: '更多遊戲操作',
        onSelected: (action) {
          switch (action) {
            case 'card-tutorial':
              _showCardBattleTutorial();
            case 'acceptance':
              _loadAcceptanceScenario();
            case 'victory':
              _replayEnding();
            case 'equipment':
              _openEquipment();
            case 'stages':
              _showStages();
            case 'character':
              _chooseCharacter();
            case 'restart':
              _restart();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            key: const ValueKey('board-card-tutorial'),
            value: 'card-tutorial',
            enabled: _canCustomize,
            child: const Text('戰鬥卡牌教學'),
          ),
          if (acceptanceMode)
            PopupMenuItem(
              value: 'acceptance',
              enabled: _canCustomize,
              child: const Text('載入獨立驗收情境'),
            ),
          if (player.campaignComplete)
            PopupMenuItem(
              value: 'victory',
              enabled: _canCustomize,
              child: const Text('重看破關畫面'),
            ),
          PopupMenuItem(
            value: 'equipment',
            enabled: _canCustomize,
            child: const Text('人物裝備'),
          ),
          PopupMenuItem(
            value: 'stages',
            enabled: _canCustomize,
            child: const Text('六關旅程'),
          ),
          PopupMenuItem(
            value: 'character',
            enabled: _canCustomize,
            child: const Text('選擇角色'),
          ),
          PopupMenuItem(
            value: 'restart',
            enabled: canRestart,
            child: const Text('重新開始'),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_game == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('人生棋盤 · 讀取進度')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _busy
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '載入失敗，原存檔已保留。\n${_loadError ?? "請重試"}',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () {
                            ref.invalidate(contentReadyProvider);
                            _initialize();
                          },
                          child: const Text('重新讀取'),
                        ),
                        if (_contentReady)
                          TextButton(
                            onPressed: _restart,
                            child: const Text('捨棄存檔並重新開始'),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }
    if (!_entered) return _titleScreen();
    final jobs = ref.watch(jobManagerProvider);
    final player = ref.watch(playerProvider);
    final turn = ref.watch(turnProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          acceptanceMode ? '人生棋盤 · 獨立驗收模式' : '人生棋盤',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              player.campaignComplete
                  ? '六關全破 · 星界自由養成'
                  : '第 ${player.currentStage}/6 關 · ${_stages.current(player).title}\n地圖回合 ${player.stageTurns}/${player.turnsPerStage} · ${player.bossPending ? "魔王待戰 · 勝利後前往下一關" : "完成回合後自動迎戰魔王"}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        actions: _appActions(player, turn),
      ),
      body: SafeArea(
        child: GameDashboard(
          player: player,
          job:
              '${jobs.byId(player.jobId).title} · 打工 ×${jobs.byId(player.jobId).workPercent / 100}',
          history: List.unmodifiable(_history),
          board: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ChapterBackdrop(stage: player.currentStage),
                GameWidget(
                  key: _boardKey,
                  game: _game!,
                  loadingBuilder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('場景載入失敗，請確認專案檔案已完整覆蓋後重新啟動。\n$error'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          controls: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (acceptanceMode)
                  const Text(
                    '驗收模式：獨立存檔，不影響正式進度',
                    style: TextStyle(color: Colors.deepOrange, fontSize: 12),
                  ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    IconButton(
                      tooltip: '向左旋轉',
                      onPressed: () => setState(() => _game!.orbit(-.25)),
                      icon: const Icon(Icons.rotate_left),
                    ),
                    IconButton(
                      tooltip: '向右旋轉',
                      onPressed: () => setState(() => _game!.orbit(.25)),
                      icon: const Icon(Icons.rotate_right),
                    ),
                    IconButton(
                      tooltip: '拉近',
                      onPressed: () => setState(() => _game!.changeZoom(.1)),
                      icon: const Icon(Icons.zoom_in),
                    ),
                    IconButton(
                      tooltip: '拉遠',
                      onPressed: () => setState(() => _game!.changeZoom(-.1)),
                      icon: const Icon(Icons.zoom_out),
                    ),
                    IconButton(
                      tooltip: '重設視角',
                      onPressed: () => setState(() => _game!.resetCamera()),
                      icon: const Icon(Icons.center_focus_strong),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DiceDisplay(
                      value: _diceFace ?? turn.dice,
                      rolling: turn.phase == TurnPhase.rolling,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(turn.message, textAlign: TextAlign.center),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 280,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed:
                        !_busy &&
                            _game!.isBoardReady &&
                            _saveError == null &&
                            turn.phase == TurnPhase.idle
                        ? _roll
                        : null,
                    icon: const Icon(Icons.casino_outlined),
                    label: Text(
                      !_game!.isBoardReady
                          ? '載入場景…'
                          : turn.phase == TurnPhase.rolling
                          ? '擲骰中…'
                          : turn.phase == TurnPhase.moving
                          ? '移動中…'
                          : turn.phase == TurnPhase.resolving
                          ? '處理事件中…'
                          : player.bossPending
                          ? '再戰魔王 · 通關前無法擲骰'
                          : '擲骰子 Roll Dice',
                    ),
                  ),
                ),
                if (player.bossPending)
                  OutlinedButton.icon(
                    onPressed: _canCustomize ? _prepareBoss : null,
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('戰前補給 · 商店與訓練'),
                  ),
                if (player.bossPending)
                  const Text(
                    '魔王戰敗不扣錢，體力與智力各 +2；可補給後再戰。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 8),
                Text(
                  '第 ${player.life.generation} 世 · ${player.life.age} 歲 · ${player.life.season}季',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2B584E),
                  ),
                ),
                Text(
                  '年齡地形：${AgeBoard.forAge(player.life.age).title} · ${AgeBoard.forAge(player.life.age).ageRange}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'EQ ${player.life.eq} · 壓力 ${player.life.stress} · 已學天賦 ${player.life.learnedSkills.length}',
                  style: const TextStyle(fontSize: 12),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('open-life-journal'),
                  onPressed: _canCustomize ? _openLifeJournal : null,
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: Text(
                    const LifeService().canReincarnate(player)
                        ? '人生手帳 · 可轉生'
                        : '人生手帳 · 培養與生活',
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('open-life-story'),
                  onPressed: _canCustomize ? _openLifeStory : null,
                  icon: const Icon(Icons.diversity_1_outlined),
                  label: const Text('人生故事 · 關係、家計與結局'),
                ),
                const SizedBox(height: 6),
                Text(
                  _saveMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: _saveError == null ? Colors.grey : Colors.red,
                  ),
                ),
                if (_saveError != null)
                  TextButton(
                    onPressed: _busy ? null : _retrySave,
                    child: const Text('重試存檔'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
