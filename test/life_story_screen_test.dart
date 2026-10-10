// Written regression coverage for v0.26. These widget tests have not been run
// in the restricted build environment; run them with the full Flutter suite.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/life_progress.dart';
import 'package:life_graybox/domain/models/life_story.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/services/story_service.dart';
import 'package:life_graybox/presentation/screens/life_story_screen.dart';

const _service = StoryService();

String _jobTitle(String id) => switch (id) {
  'student' => '學生',
  'engineer' => '工程師',
  _ => '待業',
};

Widget _app({
  Player player = const Player(),
  Future<Player> Function(String, String?)? onRelationship,
  Future<Player> Function(String, int, String)? onStoryChoice,
  Future<Player> Function(String)? onConclude,
  double textScale = 1,
}) {
  var saved = player;
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: LifeStoryScreen(
      player: player,
      jobTitle: _jobTitle,
      onRelationship:
          onRelationship ??
          (action, npcId) async {
            saved = _service.perform(saved, action, npcId: npcId);
            return saved;
          },
      onStoryChoice:
          onStoryChoice ??
          (chainId, step, optionId) async {
            saved = _service.chooseStory(
              saved,
              chainId,
              optionId,
              expectedStep: step,
            );
            return saved;
          },
      onConclude:
          onConclude ??
          (endingId) async {
            saved = _service.concludeLife(saved, endingId);
            return saved;
          },
    ),
  );
}

Player _grown({
  int turns = 48,
  int money = 4000,
  int homeLevel = 1,
  int children = 0,
  bool married = false,
  String? partnerId = 'cen_yu',
}) => Player(
  money: money,
  life: LifeProgress(turns: turns, homeLevel: homeLevel),
  story: LifeStory(lastSettledTurn: turns).copyWith(
    partnerId: partnerId,
    married: married,
    children: children,
    affinities: const {'cen_yu': 80, 'chu_ye': 80, 'luo_qing': 80},
  ),
);

Finder _vertical() => find
    .descendant(
      of: find.byKey(const ValueKey('life-story-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _show(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    260,
    scrollable: _vertical(),
  );
  await tester.pumpAndSettle();
}

Future<void> _top(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('life-story-scroll')),
    const Offset(0, 15000),
  );
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String pane) async {
  final tab = find.byKey(ValueKey('life-story-tab-$pane'));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

FilledButton _button(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.byKey(ValueKey(key)));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  for (final size in const [Size(390, 740), Size(390, 320), Size(1000, 320)]) {
    testWidgets('all four panes scroll without overflow at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app());
      expect(_text(tester, 'life-story-money'), '\$1000');
      await _show(tester, 'life-story-choice-roots-0-b');
      expect(tester.takeException(), isNull);
      await _tab(tester, 'relationships');
      await _show(tester, 'life-story-action-propose-luo_qing');
      expect(tester.takeException(), isNull);
      await _tab(tester, 'household');
      await _show(tester, 'life-story-action-familyTime-family');
      expect(tester.takeException(), isNull);
      await _tab(tester, 'endings');
      await _show(tester, 'life-story-conclude-peaceful');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('narrow screen and confirmation support large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(player: _grown(), textScale: 1.6));
    await _tab(tester, 'relationships');
    await _show(tester, 'life-story-action-propose-cen_yu');
    await tester.tap(
      find.byKey(const ValueKey('life-story-action-propose-cen_yu')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('life-story-confirmation')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('life-story-cancel')));
    await tester.tap(find.byKey(const ValueKey('life-story-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('life-story-confirmation')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked story options expose age and money prerequisites', (
    tester,
  ) async {
    await tester.pumpWidget(_app(player: const Player(money: 0)));
    await _show(tester, 'life-story-choice-lantern-0-b');
    expect(_button(tester, 'life-story-choice-lantern-0-b').onPressed, isNull);
    expect(find.textContaining('金錢不足，需要 200'), findsWidgets);
    await _show(tester, 'life-story-choice-roots-0-b');
    expect(_button(tester, 'life-story-choice-roots-0-b').onPressed, isNull);
    expect(find.textContaining('需年滿 22 歲'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'story callback receives exact current chapter and advances only after save',
    (tester) async {
      final pending = Completer<Player>();
      var calls = 0;
      await tester.pumpWidget(
        _app(
          onStoryChoice: (chainId, step, optionId) {
            calls++;
            expect(chainId, 'lantern');
            expect(step, 0);
            expect(optionId, 'a');
            return pending.future;
          },
        ),
      );
      await _show(tester, 'life-story-choice-lantern-0-a');
      final choose = find.byKey(
        const ValueKey('life-story-choice-lantern-0-a'),
      );
      await tester.tap(choose);
      await tester.pump();
      expect(calls, 1);
      expect(
        _button(tester, 'life-story-choice-lantern-0-a').onPressed,
        isNull,
      );
      expect(
        find.byKey(const ValueKey('life-story-chapter-lantern-0')),
        findsOneWidget,
      );
      await tester.tap(choose);
      expect(calls, 1);
      pending.complete(
        _service.chooseStory(const Player(), 'lantern', 'a', expectedStep: 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('life-story-choice-lantern-0-a')),
        findsNothing,
      );
      await _show(tester, 'life-story-choice-lantern-1-a');
      expect(
        _button(tester, 'life-story-choice-lantern-1-a').onPressed,
        isNull,
      );
      expect(find.textContaining('需年滿 22 歲'), findsWidgets);
      await _top(tester);
      expect(_text(tester, 'life-story-age'), '18 歲 · 夏季');
      await _show(tester, 'life-story-chosen-lantern_0');
      expect(_text(tester, 'life-story-chosen-lantern_0'), '已選擇：親自幫忙');
    },
  );

  testWidgets(
    'older completed chapter without saved choice does not invent a decision',
    (tester) async {
      final player = Player(
        story: const LifeStory().copyWith(
          storySteps: const {'lantern': 1, 'craft': 0, 'roots': 0},
        ),
      );
      await tester.pumpWidget(_app(player: player));
      await _show(tester, 'life-story-chapter-lantern-1');
      expect(
        find.byKey(const ValueKey('life-story-chosen-lantern_0')),
        findsNothing,
      );
      expect(find.text('已選擇：親自幫忙'), findsNothing);
      expect(find.text('已選擇：贊助燈具'), findsNothing);
    },
  );

  testWidgets(
    'relationship saving locks actions tabs and Back then applies the result once',
    (tester) async {
      final pending = Completer<Player>();
      var calls = 0;
      await tester.pumpWidget(
        _app(
          onRelationship: (action, npcId) {
            calls++;
            expect(action, 'talk');
            expect(npcId, 'cen_yu');
            return pending.future;
          },
        ),
      );
      await _tab(tester, 'relationships');
      await _show(tester, 'life-story-action-talk-cen_yu');
      final talk = find.byKey(const ValueKey('life-story-action-talk-cen_yu'));
      await tester.tap(talk);
      await tester.pump();
      expect(
        _button(tester, 'life-story-action-talk-cen_yu').onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('life-story-back')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('life-story-tab-stories')),
            )
            .onSelected,
        isNull,
      );
      expect(
        tester.widget<PopScope<Player>>(find.byType(PopScope<Player>)).canPop,
        isFalse,
      );
      expect(find.byKey(const ValueKey('life-story-saving')), findsOneWidget);
      await tester.tap(talk);
      expect(calls, 1);
      pending.complete(
        _service.perform(const Player(), 'talk', npcId: 'cen_yu'),
      );
      await tester.pumpAndSettle();
      expect(
        _button(tester, 'life-story-action-talk-cen_yu').onPressed,
        isNotNull,
      );
      expect(
        tester.widget<PopScope<Player>>(find.byType(PopScope<Player>)).canPop,
        isTrue,
      );
      await _top(tester);
      expect(_text(tester, 'life-story-age'), '18 歲 · 夏季');
      await _show(tester, 'life-story-affinity-cen_yu');
      expect(_text(tester, 'life-story-affinity-cen_yu'), '好感 8 / 100');
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed save keeps original state and explicit retry is safe', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        onRelationship: (action, npcId) async {
          calls++;
          if (calls == 1) throw StateError('儲存暫時失敗');
          return _service.perform(const Player(), action, npcId: npcId);
        },
      ),
    );
    await _tab(tester, 'relationships');
    await _show(tester, 'life-story-action-talk-cen_yu');
    await tester.tap(
      find.byKey(const ValueKey('life-story-action-talk-cen_yu')),
    );
    await tester.pumpAndSettle();
    await _top(tester);
    expect(_text(tester, 'life-story-money'), '\$1000');
    expect(_text(tester, 'life-story-age'), '18 歲 · 春季');
    await _show(tester, 'life-story-retry');
    expect(find.textContaining('儲存暫時失敗'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('life-story-retry')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    await _top(tester);
    expect(_text(tester, 'life-story-age'), '18 歲 · 夏季');
    expect(find.byKey(const ValueKey('life-story-error')), findsNothing);
  });

  testWidgets(
    'commit confirmation explains exclusive partner and cancellation is read-only',
    (tester) async {
      final initial = _grown(partnerId: null);
      var calls = 0;
      await tester.pumpWidget(
        _app(
          player: initial,
          onRelationship: (action, npcId) async {
            calls++;
            return _service.perform(initial, action, npcId: npcId);
          },
        ),
      );
      await _tab(tester, 'relationships');
      await _show(tester, 'life-story-action-commit-cen_yu');
      await tester.tap(
        find.byKey(const ValueKey('life-story-action-commit-cen_yu')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('將與岑雨成為本世唯一伴侶'), findsOneWidget);
      expect(find.textContaining('轉生會重設伴侶'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('life-story-cancel')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(
        find.byKey(const ValueKey('life-story-action-commit-cen_yu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('life-story-confirm')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await _top(tester);
      await _show(tester, 'life-story-partner');
      expect(find.text('目前伴侶：岑雨'), findsOneWidget);
      expect(find.text('關係狀態：穩定交往'), findsOneWidget);
    },
  );

  testWidgets(
    'other adult NPCs show why dates are blocked after choosing a partner',
    (tester) async {
      await tester.pumpWidget(_app(player: _grown()));
      await _tab(tester, 'relationships');
      await _show(tester, 'life-story-action-date-chu_ye');
      expect(
        _button(tester, 'life-story-action-date-chu_ye').onPressed,
        isNull,
      );
      expect(find.textContaining('只能與目前伴侶約會'), findsWidgets);
      await _top(tester);
      await _show(tester, 'life-story-action-talk-chu_ye');
      expect(
        _button(tester, 'life-story-action-talk-chu_ye').onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'marriage confirms named partner cost and reset effects before one saved action',
    (tester) async {
      final initial = _grown();
      var calls = 0;
      await tester.pumpWidget(
        _app(
          player: initial,
          onRelationship: (action, npcId) async {
            calls++;
            expect(action, 'propose');
            expect(npcId, 'cen_yu');
            return _service.perform(initial, action, npcId: npcId);
          },
        ),
      );
      await _tab(tester, 'relationships');
      await _show(tester, 'life-story-action-propose-cen_yu');
      await tester.tap(
        find.byKey(const ValueKey('life-story-action-propose-cen_yu')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('將與岑雨結婚'), findsOneWidget);
      expect(find.textContaining('本次花費 \$1200'), findsOneWidget);
      expect(find.textContaining('取消不扣款'), findsOneWidget);
      expect(calls, 0);
      await tester.tap(find.byKey(const ValueKey('life-story-confirm')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await _top(tester);
      expect(_text(tester, 'life-story-money'), '\$2790');
      await _show(tester, 'life-story-partner');
      expect(find.text('關係狀態：已婚'), findsOneWidget);
    },
  );

  testWidgets(
    'child decision can be canceled then adds one child and updated seasonal budget',
    (tester) async {
      final initial = _grown(married: true);
      var calls = 0;
      await tester.pumpWidget(
        _app(
          player: initial,
          onRelationship: (action, npcId) async {
            calls++;
            expect(action, 'child');
            expect(npcId, isNull);
            return _service.perform(initial, action, npcId: npcId);
          },
        ),
      );
      await _tab(tester, 'household');
      await _show(tester, 'life-story-action-child-family');
      await tester.tap(
        find.byKey(const ValueKey('life-story-action-child-family')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('共同領養一名孩子'), findsOneWidget);
      expect(find.textContaining('本次花費 \$800'), findsOneWidget);
      expect(find.textContaining('每季生活費增加 \$15'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('life-story-cancel')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(
        find.byKey(const ValueKey('life-story-action-child-family')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('life-story-confirm')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await _top(tester);
      expect(_text(tester, 'life-story-money'), '\$3175');
      await _show(tester, 'life-story-children');
      expect(_text(tester, 'life-story-children'), '孩子：1 / 2');
      await _show(tester, 'life-story-living-cost');
      expect(_text(tester, 'life-story-living-cost'), '每季生活費 \$25');
    },
  );

  testWidgets(
    'finance browsing never calls actions and explains housing integration',
    (tester) async {
      final initial = _grown(married: true, children: 2, homeLevel: 2);
      var calls = 0;
      await tester.pumpWidget(
        _app(
          player: initial,
          onRelationship: (_, __) async {
            calls++;
            return initial;
          },
          onStoryChoice: (_, __, ___) async {
            calls++;
            return initial;
          },
          onConclude: (_) async {
            calls++;
            return initial;
          },
        ),
      );
      await _tab(tester, 'household');
      await _show(tester, 'life-story-living-cost');
      expect(_text(tester, 'life-story-living-cost'), '每季生活費 \$50');
      expect(find.textContaining('付不足的季節壓力 +8'), findsWidgets);
      await _top(tester);
      await _show(tester, 'life-story-household');
      expect(find.textContaining('購屋與升級請回「人生手帳」'), findsOneWidget);
      await _show(tester, 'life-story-action-child-family');
      expect(
        _button(tester, 'life-story-action-child-family').onPressed,
        isNull,
      );
      expect(find.textContaining('最多養育 2 名孩子'), findsWidgets);
      await _tab(tester, 'stories');
      await _tab(tester, 'endings');
      expect(calls, 0);
      expect(_text(tester, 'life-story-money'), '\$4000');
    },
  );

  testWidgets(
    'locked endings display their actual conditions and journal retirement route',
    (tester) async {
      await tester.pumpWidget(_app());
      await _tab(tester, 'endings');
      await _show(tester, 'life-story-conclude-family');
      expect(_button(tester, 'life-story-conclude-family').onPressed, isNull);
      expect(find.text('完成六章或年滿 60 歲，且已婚並育有至少 1 名孩子'), findsOneWidget);
      await _show(tester, 'life-story-conclude-prosperity');
      expect(find.text('完成六章或年滿 60 歲，擁有 2 級家園與至少 5000 金錢'), findsOneWidget);
      await _show(tester, 'life-story-conclude-peaceful');
      expect(_button(tester, 'life-story-conclude-peaceful').onPressed, isNull);
      expect(find.byKey(const ValueKey('life-reincarnate')), findsNothing);
    },
  );

  testWidgets(
    'ending selection records one frozen snapshot without another season or reward',
    (tester) async {
      final initial = _grown(turns: 168, money: 6200, homeLevel: 2);
      var calls = 0;
      await tester.pumpWidget(
        _app(
          player: initial,
          onConclude: (endingId) async {
            calls++;
            expect(endingId, 'prosperity');
            return _service.concludeLife(initial, endingId);
          },
        ),
      );
      await _tab(tester, 'endings');
      await _show(tester, 'life-story-conclude-prosperity');
      await tester.tap(
        find.byKey(const ValueKey('life-story-conclude-prosperity')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('不會多花一季'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('life-story-cancel')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(
        find.byKey(const ValueKey('life-story-conclude-prosperity')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('life-story-confirm')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        _button(tester, 'life-story-conclude-prosperity').onPressed,
        isNull,
      );
      await _top(tester);
      expect(_text(tester, 'life-story-money'), '\$6200');
      expect(_text(tester, 'life-story-age'), '60 歲 · 春季');
      await _show(tester, 'life-story-record-1');
      expect(find.text('第 1 世 · 安穩而豐盛'), findsOneWidget);
      expect(find.text('60 歲 · 待業'), findsOneWidget);
      expect(find.text('當時資產 \$6200 · 學會 0 項心得'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'past ending uses recorded job age and money instead of live values',
    (tester) async {
      final player = Player(
        money: 900,
        jobId: 'student',
        life: const LifeProgress(generation: 2),
        story: const LifeStory().copyWith(
          history: const [
            EndingRecord(
              generation: 1,
              age: 62,
              id: 'peaceful',
              jobId: 'engineer',
              money: 7000,
              learnedCount: 3,
            ),
          ],
        ),
      );
      await tester.pumpWidget(_app(player: player));
      await _tab(tester, 'endings');
      await _show(tester, 'life-story-record-1');
      expect(find.text('第 1 世 · 平凡日子的光'), findsOneWidget);
      expect(find.text('62 歲 · 工程師'), findsOneWidget);
      expect(find.text('當時資產 \$7000 · 學會 3 項心得'), findsOneWidget);
    },
  );

  testWidgets(
    'ending save failure permits retry but requires the confirmation again',
    (tester) async {
      var calls = 0;
      const initial = Player(clearedStages: 6);
      await tester.pumpWidget(
        _app(
          player: initial,
          onConclude: (endingId) async {
            calls++;
            if (calls == 1) throw StateError('結局儲存失敗');
            return _service.concludeLife(initial, endingId);
          },
        ),
      );
      await _tab(tester, 'endings');
      await _show(tester, 'life-story-conclude-trials');
      await tester.tap(
        find.byKey(const ValueKey('life-story-conclude-trials')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('life-story-confirm')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await _top(tester);
      await _show(tester, 'life-story-retry');
      await tester.tap(find.byKey(const ValueKey('life-story-retry')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('life-story-confirmation')),
        findsOneWidget,
      );
      expect(calls, 1);
      await tester.tap(find.byKey(const ValueKey('life-story-confirm')));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await _show(tester, 'life-story-record-1');
      expect(find.text('第 1 世 · 越過六座山'), findsOneWidget);
    },
  );

  testWidgets(
    'Back returns the saved player and does not perform extra actions',
    (tester) async {
      Player? result;
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                key: const ValueKey('open-story'),
                onPressed: () async {
                  result = await Navigator.of(context).push<Player>(
                    MaterialPageRoute(
                      builder: (_) => LifeStoryScreen(
                        player: const Player(),
                        jobTitle: _jobTitle,
                        onRelationship: (action, npcId) async {
                          calls++;
                          return _service.perform(
                            const Player(),
                            action,
                            npcId: npcId,
                          );
                        },
                        onStoryChoice: (chainId, step, optionId) async =>
                            _service.chooseStory(
                              const Player(),
                              chainId,
                              optionId,
                              expectedStep: step,
                            ),
                        onConclude: (endingId) async =>
                            _service.concludeLife(const Player(), endingId),
                      ),
                    ),
                  );
                },
                child: const Text('開啟故事'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-story')));
      await tester.pumpAndSettle();
      await _tab(tester, 'relationships');
      await _show(tester, 'life-story-action-talk-cen_yu');
      await tester.tap(
        find.byKey(const ValueKey('life-story-action-talk-cen_yu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('life-story-back')));
      await tester.pumpAndSettle();
      expect(result?.story.affinities['cen_yu'], 8);
      expect(result?.life.turns, 1);
      expect(calls, 1);
      expect(find.byType(LifeStoryScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rapid repeated dialog buttons never dismiss the story route or save twice',
    (tester) async {
      final pending = Completer<Player>();
      final initial = _grown();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                key: const ValueKey('open-story-dialog-test'),
                onPressed: () => Navigator.of(context).push<Player>(
                  MaterialPageRoute(
                    builder: (_) => LifeStoryScreen(
                      player: initial,
                      jobTitle: _jobTitle,
                      onRelationship: (action, npcId) {
                        calls++;
                        return pending.future;
                      },
                      onStoryChoice: (_, __, ___) async => initial,
                      onConclude: (_) async => initial,
                    ),
                  ),
                ),
                child: const Text('開啟故事'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-story-dialog-test')));
      await tester.pumpAndSettle();
      await _tab(tester, 'relationships');
      await _show(tester, 'life-story-action-propose-cen_yu');
      await tester.tap(
        find.byKey(const ValueKey('life-story-action-propose-cen_yu')),
      );
      await tester.pumpAndSettle();
      final cancel = tester
          .widget<TextButton>(find.byKey(const ValueKey('life-story-cancel')))
          .onPressed!;
      cancel();
      cancel();
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(LifeStoryScreen), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('life-story-action-propose-cen_yu')),
      );
      await tester.pumpAndSettle();
      final confirm = _button(tester, 'life-story-confirm').onPressed!;
      confirm();
      confirm();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
      expect(find.byType(LifeStoryScreen), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('life-story-back')))
            .onPressed,
        isNull,
      );
      pending.complete(_service.perform(initial, 'propose', npcId: 'cen_yu'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(LifeStoryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
