import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/board_tile.dart';
import '../domain/models/tile_event.dart';
import '../domain/models/player.dart';
import '../domain/services/dice_service.dart';
import 'content_providers.dart';
import 'player_controller.dart';

enum TurnPhase { idle, rolling, moving, resolving }
class TurnState {
  final TurnPhase phase;
  final int? dice;
  final String message;
  final TileEvent? choiceEvent;
  final bool careerChoice, battleChoice, shopChoice;
  final String? battleEnemyId;
  const TurnState({this.phase = TurnPhase.idle, this.dice,
    this.message = '擲骰，展開今天的旅程', this.choiceEvent,
    this.shopChoice = false, this.careerChoice = false, this.battleChoice = false, this.battleEnemyId});
}
final diceServiceProvider = Provider((ref) => DiceService());
final turnProvider = NotifierProvider<TurnController, TurnState>(TurnController.new);

class TurnController extends Notifier<TurnState> {
  @override
  TurnState build() => const TurnState();
  int? beginTurn() {
    if (state.phase != TurnPhase.idle) return null;
    final dice = ref.read(diceServiceProvider).roll();
    state = TurnState(phase: TurnPhase.rolling, dice: dice, message: '骰子轉動中…');
    return dice;
  }
  void finishRoll() {
    if (state.phase != TurnPhase.rolling) return;
    state = TurnState(phase: TurnPhase.moving, dice: state.dice, message: '前進 ${state.dice} 格');
  }
  Future<void> land() async {
    if (state.phase != TurnPhase.moving) return;
    final dice = state.dice;
    state = TurnState(phase: TurnPhase.resolving, dice: dice, message: '處理落點…');
    try {
      final kind = boardTiles[ref.read(playerProvider).position].kind;
      if (kind == TileKind.shop) {
        state = TurnState(phase: TurnPhase.resolving, dice: dice, shopChoice: true, message: '抵達商店街：選購補給與裝備');
      } else if (kind == TileKind.battle) {
        state = TurnState(phase: TurnPhase.resolving, dice: dice,
          battleChoice: true, message: '遭遇人生挑戰');
      } else if (kind == TileKind.career) {
        await ref.read(jobManagerProvider).load();
        if (!ref.mounted) return;
        state = TurnState(phase: TurnPhase.resolving, dice: dice,
          careerChoice: true, message: '命運岔路：選擇職業');
      } else {
        if (kind == TileKind.work) await ref.read(jobManagerProvider).load();
        if (!ref.mounted) return;
        final event = await ref.read(tileEventManagerProvider).draw(kind, stage: ref.read(playerProvider).currentStage);
        if (!ref.mounted) return;
        // Drawing never changes attributes. Commit only after choosing A/B.
        state = TurnState(phase: TurnPhase.resolving, dice: dice,
          choiceEvent: event, message: event.title);
      }
    } catch (error) {
      if (!ref.mounted) return;
      state = TurnState(dice: dice, message: '本次落點未結算：$error');
    }
  }

  bool finishChoice(String optionId) {
    final event = state.choiceEvent;
    if (state.phase != TurnPhase.resolving || event == null) return false;
    final options = event.options.where((o) => o.id == optionId);
    if (options.isEmpty) return false;
    final option = options.single;
    final before = ref.read(playerProvider);
    final effects = event.kind == TileKind.work
      ? ref.read(jobManagerProvider).workEffects(before, option.effects) : option.effects;
    final after = before.apply(effects);
    ref.read(playerProvider.notifier).replace(after);
    final actual = StatDelta(stamina: after.stamina-before.stamina,
      intelligence: after.intelligence-before.intelligence,
      charm: after.charm-before.charm, morality: after.morality-before.morality, money: after.money-before.money);
    state = TurnState(dice: state.dice,
      phase: option.battleEnemyId == null ? TurnPhase.idle : TurnPhase.resolving,
      battleChoice: option.battleEnemyId != null, battleEnemyId: option.battleEnemyId,
      message: '${event.title} · ${option.label}：${actual.summary.isEmpty ? "無數值變化" : actual.summary}');
    return true;
  }

  void finishShop() {
    if (state.phase != TurnPhase.resolving || !state.shopChoice) return;
    state = TurnState(dice: state.dice, message: '離開商店街，準備下一回合');
  }

  void finishBattle(StatDelta delta, String message, {int experience = 0, Map<String,int>? inventory}) {
    if (state.phase != TurnPhase.resolving || !state.battleChoice) return;
    final updated = ref.read(playerProvider).apply(delta).gainExperience(experience).copyWith(inventory:inventory);
    ref.read(playerProvider.notifier).replace(updated);
    state = TurnState(dice: state.dice, message: message);
  }
  String? finishResolution({String? targetJobId}) {
    if (state.phase != TurnPhase.resolving) return null;
    if (!state.careerChoice) return '請完成目前事件';
    var message = '維持原職業';
    if (targetJobId != null) {
      try {
        final jobs = ref.read(jobManagerProvider);
        final updated = jobs.changeJob(ref.read(playerProvider), targetJobId);
        ref.read(playerProvider.notifier).replace(updated);
        message = '轉職為${jobs.byId(targetJobId).title}';
      } catch (error) {
        state = TurnState(dice: state.dice, message: '轉職失敗：$error');
        return error.toString();
      }
    }
    state = TurnState(dice: state.dice, message: message);
    return null;
  }
}
