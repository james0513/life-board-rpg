import 'dart:async';
import '../../domain/models/stage.dart';
import '../../domain/services/stage_service.dart';
import 'shop_screen.dart';
import 'equipment_screen.dart';
import 'victory_screen.dart';
import '../../domain/services/shop_service.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../domain/models/battle.dart';
import '../battle/battle_screen.dart';
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
import '../art/atlas_portrait.dart';
import '../three_d/models_3d.dart';
import '../widgets/chapter_backdrop.dart';
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

  LifeGame _createBoard(int position) => LifeGame(equipment:EquipmentLook.fromPlayer(ref.read(playerProvider)),stage: ref.read(playerProvider).currentStage, initialPosition: position, jobId: ref.read(playerProvider).jobId, gender:ref.read(playerProvider).gender,
    onBoardReady: () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    });

  Future<void> _toggleAudio() async {
    if (_audioBusy) return;
    setState(() => _audioBusy = true);
    await _audio.setEnabled(!_soundOn);
    if (!mounted) return;
    setState(() { _soundOn = _audio.enabled; _audioBusy = false; });
    if (_audio.error != null) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('聲音未能啟動，請再點一次音樂按鈕。遊戲仍可繼續。')));
  }

  void _enterGame() {
    setState(() => _entered = true);
    unawaited(_audio.music(stageMusic(ref.read(playerProvider).currentStage)));
    unawaited(_audio.sfx('click'));
  }

  Widget _soundButton() => IconButton(
    tooltip: _soundOn ? '關閉音樂與音效' : '開啟音樂與音效',
    onPressed: _audioBusy ? null : _toggleAudio,
    icon: Icon(_soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded),
  );

  Widget _titleScreen() => Scaffold(body: Stack(fit: StackFit.expand, children: [
    Image.asset('assets/images/backgrounds/title_city.png', fit: BoxFit.cover),
    DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
      colors: [const Color(0xF5FFF7E6), const Color(0x60FFF7E6)],
      begin: Alignment.centerLeft, end: Alignment.centerRight))),
    SafeArea(child: Padding(padding: const EdgeInsets.all(28), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(alignment: Alignment.topRight, child: _soundButton()),
        Expanded(child: Center(child: Align(alignment: Alignment.centerLeft,
          child: SingleChildScrollView(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
                const Text('LIFE BOARD', style: TextStyle(letterSpacing: 5, color: Color(0xFF8E623D))),
                const SizedBox(height: 12),
                const Text('人生棋盤', style: TextStyle(fontSize: 48,
                  fontWeight: FontWeight.bold, color: Color(0xFF2B584E))),
                const SizedBox(height: 12),
                const Text('把日常，玩成冒險。\n每一步都有新的可能。', style: TextStyle(fontSize: 20, height: 1.7)),
                const SizedBox(height: 28),
                FilledButton.icon(onPressed: _enterGame,
                  icon: const Icon(Icons.play_arrow_rounded), label: const Text('開始／繼續人生')),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: _canCustomize ? _chooseCharacter : null, icon: const Icon(Icons.person), label: const Text('選擇男女角色')),
                Row(children: [
                  CareerPortrait(equipment:EquipmentLook.fromPlayer(ref.watch(playerProvider)),jobId: ref.watch(playerProvider).jobId, gender:ref.watch(playerProvider).gender, width: 54, height: 76),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_saveMessage)),
                ]),
                const SizedBox(height: 8),
                const Text('右上角可開啟音樂與音效', style: TextStyle(fontSize: 13)),
              ]),
          )),
        ))),
      ],
    ))),
  ]));

  Future<void> _initialize() async {
    if (!mounted) return;
    setState(() { _busy = true; _loadError = null; });
    try {
      await ref.read(contentReadyProvider.future);
      final enemyJson = jsonDecode(await rootBundle.loadString('assets/data/enemies.json')) as List;
      _enemies = enemyJson.map((e) => Enemy.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final stageJson = jsonDecode(await rootBundle.loadString('assets/data/stages.json')) as List;
      _stages = StageService(stageJson.map((j)=>GameStage.fromJson(Map<String,dynamic>.from(j as Map))).toList());
      if (_enemies.isEmpty) throw const FormatException('敵人資料不可為空');
      for (final event in await ref.read(tileEventManagerProvider).load()) {
        for (final option in event.options) {
          if (option.battleEnemyId != null && !_enemies.any((e) => e.id == option.battleEnemyId)) {
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
      await ref.read(saveRepositoryProvider).save(ref.read(playerProvider));
      if (mounted) setState(() {
        _saveError = null;
        _saveMessage = '已自動存檔';
      });
    } catch (error) {
      if (mounted) setState(() {
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
    }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _restart() async {
    if (_busy || !_contentReady || ref.read(turnProvider).phase != TurnPhase.idle) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('重新開始？'),
          content: const Text('目前存檔將被新遊戲取代。位置、屬性、金錢與職業都會重置。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('重新開始')),
          ],
        ));
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
        game.changeCareer('unemployed',gender:CharacterGender.male);
        game.changeStage(1);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重新開始失敗，進度未重置：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canCustomize => !_busy && _saveError == null &&
    ref.read(turnProvider).phase == TurnPhase.idle;

  Future<Player> _persistPlayer(Player candidate) async {
    await ref.read(saveRepositoryProvider).save(candidate);
    if (!mounted) return candidate;
    ref.read(playerProvider.notifier).replace(candidate);
    _game?.changeEquipment(EquipmentLook.fromPlayer(candidate));
    setState(() => _saveMessage = '已自動存檔');
    return candidate;
  }

  Future<void> _openShop() async {
    final turn = ref.read(turnProvider);
    if (turn.phase != TurnPhase.resolving || !turn.shopChoice) return;
    try {
      await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ShopScreen(
        player: ref.read(playerProvider), onAction: (id, equip) async {
          final current = ref.read(playerProvider);
          const service = ShopService();
          return _persistPlayer(equip ? service.equip(current, id) : service.buy(current, id));
        })));
    } finally {
      if (mounted) {
        ref.read(turnProvider.notifier).finishShop();
        _record('離開商店街');
        await _checkpoint();
      }
    }
  }

  Future<void> _openEquipment() async {
    if(!_canCustomize)return;
    setState(()=>_busy=true);
    try {
      final player=ref.read(playerProvider);
      await Navigator.of(context).push<void>(MaterialPageRoute(builder:(_)=>EquipmentScreen(
        player:player,jobTitle:ref.read(jobManagerProvider).byId(player.jobId).title,
        onEquip:(id,slot)=>_persistPlayer(const ShopService().equip(ref.read(playerProvider),id,slot:slot)))));
    } finally {if(mounted)setState(()=>_busy=false);}
  }

  Future<void> _chooseCharacter() async {
    if (!_canCustomize) return;
    setState(() => _busy = true);
    try {
      final player = ref.read(playerProvider);
      final selected = await showDialog<CharacterGender>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('選擇角色'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('男女角色能力相同，保留目前職業、屬性與背包。'),
          for (final gender in CharacterGender.values) ListTile(
            leading: CareerPortrait(equipment:EquipmentLook.fromPlayer(player),jobId: player.jobId, gender: gender, width: 42, height: 56),
            title: Text(gender == CharacterGender.male ? '男生 · 阿晨' : '女生 · 小晴'),
            trailing: player.gender == gender ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, gender)),
        ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消'))],
      ));
      if (selected == null || !mounted || selected == player.gender) return;
      await _persistPlayer(player.copyWith(gender: selected));
      if (mounted) _game?.changeCareer(player.jobId, gender: selected);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('角色切換未完成：$e')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _roll() async {
    final game = _game;
    if (_busy || _saveError != null || game == null || !game.isBoardReady) return;
    final turns = ref.read(turnProvider.notifier);
    final from = ref.read(playerProvider).position;
    final steps = turns.beginTurn();
    if (steps == null) return;
    setState(() => _busy = true);
    _turnNumber++;

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
    final moved = await game.move(from: from, steps: steps,
      onPosition: (index) {
        if (mounted) {
          ref.read(playerProvider.notifier).moveTo(index);
          unawaited(_audio.sfx('step'));
        }
      });
    if (!mounted || !moved) return;
    await turns.land();
    if (!mounted) return;
    final resolution = ref.read(turnProvider);
    if (resolution.phase != TurnPhase.resolving) {
      _record('抵達第 ${ref.read(playerProvider).position + 1} 格\n${resolution.message}');
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
    if (resolution.choiceEvent != null) {
      final event = resolution.choiceEvent!;
      unawaited(_audio.sfx('event'));
      final selectedOption = await showDialog<String>(context: context, barrierDismissible: false,
        builder: (_) => ChoiceEventDialog(event: event,
          workPercent: event.kind == TileKind.work
            ? ref.read(jobManagerProvider).byId(ref.read(playerProvider).jobId).workPercent : 100));
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
      selected = await showDialog<String>(context: context, barrierDismissible: false,
        builder: (_) => CareerDialog(player: player, jobs: jobs));
    }
    if (mounted) {
      turns.finishResolution(targetJobId: selected);
      _game?.changeCareer(ref.read(playerProvider).jobId);
      if (resolution.careerChoice) {
        _record(ref.read(turnProvider).message);
        unawaited(_audio.music(stageMusic(ref.read(playerProvider).currentStage)));
        unawaited(_audio.sfx(selected == null ? 'click' : 'promotion'));
        await _checkpoint();
      }
    }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runBattle(String? enemyId) async {
    final tier = ref.read(jobManagerProvider).byId(ref.read(playerProvider).jobId).tier;
    final pool = _enemies.where((e) => e.minTier <= tier).toList();
    var enemy = enemyId == null ? pool[Random().nextInt(pool.length)]
      : _enemies.firstWhere((e) => e.id == enemyId);
    final player = ref.read(playerProvider);
    final stage = _stages.current(player);
    if (enemyId == null && stage.bossReady(player)) {
      final challenge = await showDialog<bool>(context:context,barrierDismissible:false,
        builder:(ctx)=>AlertDialog(title:Text('${stage.id == 6 ? "最終魔王" : "關卡魔王"} · ${stage.boss.name}'),
          content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
            Actor3D(enemy:stage.id-1,boss:true,width:180,height:160),
            Text('${stage.story}\n\nHP ${stage.boss.hp} · 攻擊 ${stage.boss.attack}\n招式：${stage.boss.specialName}\n獎勵：金錢 ${stage.boss.reward} · EXP ${stage.boss.experience}'),
            if(stage.id==6)const Text('半血後進入命運暴走，攻擊 +8。'),
          ])),actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('先打一般戰鬥練習')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('挑戰魔王')),
          ]));
      if(!mounted)return;
      if(challenge==true)enemy=stage.boss;
    }
    if(!enemy.isBoss)enemy=_stages.scaleEnemy(enemy,player);
    final battle = BattleSession(player, enemy, job: ref.read(jobManagerProvider).byId(player.jobId));
    var applied = false;
    _record('遭遇 ${enemy.name}');
    _game?.pauseEngine();
    unawaited(_audio.music(enemy.isBoss ? 'boss' : 'battle'));
    try {
      await Navigator.of(context).push<void>(PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, __, ___) => BattleScreen(session: battle,
          onSound: (name) => unawaited(_audio.sfx(name)),
          onSettle: () async {
            if (!mounted || battle.active) return false;
            if (!applied) {
              final reward = battle.claim();
              if (reward == null) return false;
              final result = switch (battle.status) {
                BattleStatus.won => '戰勝 ${enemy.name}：EXP +${battle.earnedExperience}，${reward.summary}',
                BattleStatus.lost => '戰敗：EXP +0，${reward.summary.isEmpty ? "無金錢損失" : reward.summary}',
                _ => '已從 ${enemy.name} 撤退，無獎懲',
              };
              ref.read(turnProvider.notifier).finishBattle(reward, result,
                experience: battle.earnedExperience, inventory:battle.remainingInventory);
              final progressed = _stages.settle(ref.read(playerProvider),enemy,battle.status);
              ref.read(playerProvider.notifier).replace(progressed);
              _game?.changeStage(progressed.currentStage);
              applied = true;
              _record(result);
            }
            await _checkpoint();
            return mounted && _saveError == null;
          }),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ));
      if(mounted && ref.read(playerProvider).clearedStages > player.clearedStages) {
        final updated=ref.read(playerProvider);
        if(updated.campaignComplete){await _showEnding(updated);}
        else {await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
          title:Text(updated.campaignComplete ? '六關全破！' : '第 ${stage.id} 關通關'),
          content:Text(updated.campaignComplete ? '你擊敗了命運編織者，取回選擇人生的自由！可以繼續在星界養成與購物。' : '已解鎖第 ${updated.currentStage} 關：${_stages.current(updated).title}。\n屬性、職業、裝備與背包均保留。${updated.currentStage==6 ? '\n終章武器已解鎖：走到商店格購買並裝備，可提高對最終魔王的傷害。' : ''}'),
          actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('繼續冒險'))]));}
      }
    } finally {
      if (mounted) {
        _game?.resumeEngine();
        unawaited(_audio.music(stageMusic(ref.read(playerProvider).currentStage)));
      }
    }
  }

  Future<void> _showEnding(Player player) => Navigator.of(context).push<void>(MaterialPageRoute(
    builder:(_)=>VictoryScreen(player:player,jobTitle:ref.read(jobManagerProvider).byId(player.jobId).title)));
  Future<void> _replayEnding()async{
    if(!_canCustomize || !ref.read(playerProvider).campaignComplete)return;
    setState(()=>_busy=true);
    try{await _showEnding(ref.read(playerProvider));}finally{if(mounted)setState(()=>_busy=false);}
  }

  Future<void> _showStages() async {
    final p=ref.read(playerProvider);
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('六關人生旅程'),
      content:SizedBox(width:520,child:ListView(shrinkWrap:true,children:[
        for(final s in _stages.stages) ListTile(
          leading:Icon(s.id<=p.clearedStages?Icons.check_circle:s.id==p.currentStage?Icons.flag:Icons.lock),
          title:Text('${s.id}. ${s.title} · ${s.id==6?"最終魔王":"普通魔王"}'),
          subtitle:Text('${s.boss.name}\n${s.story}')),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('返回'))]));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_game == null) {
      return Scaffold(appBar: AppBar(title: const Text('人生棋盤 · 讀取進度')),
        body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(24),
          child: _busy ? const CircularProgressIndicator() : Column(
            mainAxisSize: MainAxisSize.min, children: [
              Text('載入失敗，原存檔已保留。\n${_loadError ?? "請重試"}', textAlign: TextAlign.center),
              TextButton(onPressed: () {
                ref.invalidate(contentReadyProvider);
                _initialize();
              }, child: const Text('重新讀取')),
              if (_contentReady)
                TextButton(onPressed: _restart, child: const Text('捨棄存檔並重新開始')),
            ],
          ),
        ))));
    }
    if (!_entered) return _titleScreen();
    final jobs = ref.watch(jobManagerProvider);
    final player = ref.watch(playerProvider);
    final turn = ref.watch(turnProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('人生棋盤'), bottom: PreferredSize(preferredSize: const Size.fromHeight(58), child: Padding(padding: const EdgeInsets.all(8), child: Text(
        player.campaignComplete ? '六關全破 · 星界自由養成' : '第 ${player.currentStage}/6 關 · ${_stages.current(player).title}\n勝利 ${player.stageWins}/3 · ${_stages.current(player).bossReady(player) ? "藍色格可挑戰魔王" : "累積 3 勝解鎖魔王"}', textAlign:TextAlign.center))), actions: [
        if(player.campaignComplete) IconButton(tooltip:'重看破關畫面',onPressed:_canCustomize?_replayEnding:null,icon:const Icon(Icons.emoji_events_outlined)),
        IconButton(tooltip:'人物裝備',onPressed:_canCustomize ? _openEquipment : null,icon:const Icon(Icons.shield_outlined)),
        IconButton(tooltip:'六關旅程',onPressed:_canCustomize ? _showStages : null,icon:const Icon(Icons.flag_outlined)),
        IconButton(tooltip: '選擇角色', onPressed: _canCustomize ? _chooseCharacter : null, icon: const Icon(Icons.person)),
        _soundButton(),
        TextButton(onPressed: !_busy && turn.phase == TurnPhase.idle && _game!.isBoardReady
          ? _restart : null, child: const Text('重新開始')),
      ]),
      body: SafeArea(child: GameDashboard(
        player: player,
        job: '${jobs.byId(player.jobId).title} · 打工 ×${jobs.byId(player.jobId).workPercent / 100}',
        history: List.unmodifiable(_history),
        board: ClipRRect(borderRadius:BorderRadius.circular(22),child: Stack(fit:StackFit.expand,children:[ChapterBackdrop(stage:player.currentStage),GameWidget(key: _boardKey, game: _game!,
            loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error) => Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('場景載入失敗，請確認專案檔案已完整覆蓋後重新啟動。\n$error'),
            )),
          )])),
        controls: Padding(padding: const EdgeInsets.only(top: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(alignment:WrapAlignment.center,children:[
              IconButton(tooltip:'向左旋轉',onPressed:()=>setState(()=>_game!.orbit(-.25)),icon:const Icon(Icons.rotate_left)),
              IconButton(tooltip:'向右旋轉',onPressed:()=>setState(()=>_game!.orbit(.25)),icon:const Icon(Icons.rotate_right)),
              IconButton(tooltip:'拉近',onPressed:()=>setState(()=>_game!.changeZoom(.1)),icon:const Icon(Icons.zoom_in)),
              IconButton(tooltip:'拉遠',onPressed:()=>setState(()=>_game!.changeZoom(-.1)),icon:const Icon(Icons.zoom_out)),
              IconButton(tooltip:'重設視角',onPressed:()=>setState(()=>_game!.resetCamera()),icon:const Icon(Icons.center_focus_strong)),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              DiceDisplay(value: _diceFace ?? turn.dice, rolling: turn.phase == TurnPhase.rolling),
              const SizedBox(width: 12),
              Flexible(child: Text(turn.message, textAlign: TextAlign.center)),
            ]),
            const SizedBox(height: 10),
            SizedBox(width: 280, height: 48, child: FilledButton.icon(
              onPressed: !_busy && _game!.isBoardReady && _saveError == null && turn.phase == TurnPhase.idle ? _roll : null,
              icon: const Icon(Icons.casino_outlined),
              label: Text(!_game!.isBoardReady ? '載入場景…' : turn.phase == TurnPhase.rolling ? '擲骰中…' : turn.phase == TurnPhase.moving ? '移動中…' :
                turn.phase == TurnPhase.resolving ? '處理事件中…' : '擲骰子 Roll Dice'),
            )),
            const SizedBox(height: 6),
            Text(_saveMessage, style: TextStyle(fontSize: 12,
              color: _saveError == null ? Colors.grey : Colors.red)),
            if (_saveError != null)
              TextButton(onPressed: _busy ? null : _retrySave, child: const Text('重試存檔')),
          ])),
      )),
    );
  }
}
