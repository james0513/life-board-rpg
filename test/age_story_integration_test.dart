import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/application/content_providers.dart';
import 'package:life_graybox/application/player_controller.dart';
import 'package:life_graybox/application/turn_controller.dart';
import 'package:life_graybox/domain/models/age_board.dart';
import 'package:life_graybox/domain/models/board_tile.dart';
import 'package:life_graybox/domain/models/life_progress.dart';
import 'package:life_graybox/domain/models/life_story.dart';
import 'package:life_graybox/domain/models/player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ProviderContainer at(Player player) {
    final c = ProviderContainer(overrides: [jsonLoaderProvider.overrideWithValue((path) => File(path).readAsString())]);
    c.read(playerProvider.notifier).replace(player);
    addTearDown(c.dispose);
    return c;
  }
  Future<TurnController> land(ProviderContainer c) async {
    final t = c.read(turnProvider.notifier);
    t.beginTurn(); t.finishRoll(); await t.land();
    return t;
  }
  test('age22 uses actual work tile at position0 instead of old luck tile', () async {
    final c = at(const Player(position: 0, life: LifeProgress(turns: 16), story: LifeStory(lastSettledTurn: 16)));
    await land(c);
    expect(AgeBoard.forAge(22).tiles[0].kind, TileKind.work);
    expect(c.read(turnProvider).choiceEvent!.kind, TileKind.work);
    expect(c.read(turnProvider).storyEvent, isNull);
  });
  test('a luck landing resolves one persistent story and one season only', () async {
    final c = at(const Player(position: 0, life: LifeProgress(turns: 1), story: LifeStory(lastSettledTurn: 1)));
    final t = await land(c);
    final chapter = c.read(turnProvider).storyEvent!;
    final choice = chapter.options.firstWhere((option) => option.enabled);
    expect(t.finishStory('unknown'), isFalse);
    expect(t.finishStory(choice.id), isTrue);
    expect(t.finishStory(choice.id), isFalse);
    final p = c.read(playerProvider);
    expect(p.life.turns, 2);
    expect(p.story.lastSettledTurn, 2);
    expect(p.story.storySteps[chapter.chainId], 1);
    expect(p.story.storyChoices[chapter.id], choice.id);
    expect(c.read(turnProvider).phase, TurnPhase.idle);
  });
  test('household charge occurs once even repeated shop completion', () async {
    final c = at(const Player(position: 5, money: 1000, life: LifeProgress(homeLevel: 2)));
    final t = await land(c);
    t.finishShop(); t.finishShop();
    expect(c.read(playerProvider).money, 980);
    expect(c.read(playerProvider).life.turns, 1);
    expect(c.read(playerProvider).story.lastSettledTurn, 1);
  });
}
