import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/life_progress.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/services/life_service.dart';
import 'package:life_graybox/presentation/screens/life_journal_screen.dart';

const _service = LifeService();

String _jobTitle(String id) => switch (id) {
  'student' => '學生',
  'engineer' => '工程師',
  'part_timer' => '打工仔',
  _ => '待業',
};

Widget _app({
  Player player = const Player(),
  Future<Player> Function(String)? onAction,
  Future<Player> Function(String?)? onReincarnate,
  double textScale = 1,
}) => MaterialApp(
  theme: ThemeData(useMaterial3: true),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: LifeJournalScreen(
    player: player,
    jobTitle: _jobTitle,
    onAction: onAction ?? (action) async => _service.lifeAction(player, action),
    onReincarnate:
        onReincarnate ??
        (skill) async => _service.reincarnate(player, inheritSkill: skill),
  ),
);

Future<void> _show(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _top(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('life-journal-scroll')),
    const Offset(0, 12000),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(390, 740), Size(1000, 320)]) {
    testWidgets('journal remains scrollable without overflow at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app());
      expect(find.text('18 歲'), findsOneWidget);
      expect(find.text('春季'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _show(tester, 'life-action-study');
      expect(tester.takeException(), isNull);
      await _show(tester, 'life-reincarnate');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('life-reincarnate')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile journal and retirement dialog support large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(player: const Player(clearedStages: 6), textScale: 1.6),
    );
    await _show(tester, 'life-reincarnate');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('life-reincarnate')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('life-reincarnation-dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('life-reincarnation-cancel')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('life-reincarnation-dialog')),
      findsNothing,
    );
  });

  testWidgets(
    'action awaits once, locks navigation, and renders returned player',
    (tester) async {
      final pending = Completer<Player>();
      var calls = 0;
      const initial = Player();
      await tester.pumpWidget(
        _app(
          onAction: (action) {
            calls++;
            expect(action, 'study');
            return pending.future;
          },
        ),
      );
      await _show(tester, 'life-action-study');
      final study = find.byKey(const ValueKey('life-action-study'));
      await tester.tap(study);
      await tester.pump();
      expect(calls, 1);
      expect(tester.widget<FilledButton>(study).onPressed, isNull);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('life-journal-back')))
            .onPressed,
        isNull,
      );
      final scope = tester.widget<PopScope>(
        find.byWidgetPredicate((widget) => widget is PopScope),
      );
      expect(scope.canPop, isFalse);
      await tester.tap(study);
      expect(calls, 1);

      pending.complete(_service.lifeAction(initial, 'study'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(study).onPressed, isNotNull);
      await _top(tester);
      expect(find.text('\$800'), findsOneWidget);
      expect(find.text('夏季'), findsOneWidget);
      expect(find.textContaining('智力 15'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed action shows its error and permits a retry without advancing',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _app(
          onAction: (action) async {
            calls++;
            if (calls == 1) throw StateError('儲存暫時失敗');
            return _service.lifeAction(const Player(), action);
          },
        ),
      );
      await _show(tester, 'life-action-study');
      final study = find.byKey(const ValueKey('life-action-study'));
      await tester.tap(study);
      await tester.pumpAndSettle();
      expect(find.textContaining('儲存暫時失敗'), findsWidgets);
      expect(tester.widget<FilledButton>(study).onPressed, isNotNull);
      await _top(tester);
      expect(find.text('\$1000'), findsOneWidget);
      expect(find.text('春季'), findsOneWidget);
      await _show(tester, 'life-action-study');
      await tester.tap(study);
      await tester.pumpAndSettle();
      expect(calls, 2);
      await _top(tester);
      expect(find.text('\$800'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('paid actions respect affordability and resting remains free', (
    tester,
  ) async {
    const initial = Player(money: 99, life: LifeProgress(stress: 30));
    var calls = 0;
    await tester.pumpWidget(
      _app(
        player: initial,
        onAction: (action) async {
          calls++;
          expect(action, 'rest');
          return _service.lifeAction(initial, action);
        },
      ),
    );
    await _show(tester, 'life-action-study');
    for (final action in ['study', 'exercise', 'socialize', 'buyHome']) {
      expect(
        tester
            .widget<FilledButton>(find.byKey(ValueKey('life-action-$action')))
            .onPressed,
        isNull,
      );
    }
    await _show(tester, 'life-action-rest');
    final rest = find.byKey(const ValueKey('life-action-rest'));
    expect(tester.widget<FilledButton>(rest).onPressed, isNotNull);
    await tester.tap(rest);
    await tester.pumpAndSettle();
    expect(calls, 1);
    await _top(tester);
    expect(find.text('\$99'), findsOneWidget);
    expect(find.text('18 / 100'), findsOneWidget);
    expect(find.text('夏季'), findsOneWidget);
  });

  testWidgets(
    'second home purchase displays cost and becomes unavailable at level two',
    (tester) async {
      const initial = Player(money: 6500, life: LifeProgress(homeLevel: 1));
      await tester.pumpWidget(_app(player: initial));
      await _show(tester, 'life-action-buyHome');
      expect(find.text('\$6500 · 花費 1 季'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('life-action-buyHome')));
      await tester.pumpAndSettle();
      expect(find.text('已完成家園'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('life-action-buyHome')),
            )
            .onPressed,
        isNull,
      );
      await _top(tester);
      expect(find.text('舒適宅邸'), findsOneWidget);
      expect(find.text('\$0'), findsOneWidget);
    },
  );

  testWidgets(
    'skills, practice, relationship milestone, and goals reflect actual progress',
    (tester) async {
      final life = const LifeProgress(affection: 60, homeLevel: 1).copyWith(
        learnedSkills: ['engineer'],
        inheritedSkill: 'engineer',
        jobPractice: {'student': 1, 'engineer': 3},
      );
      await tester.pumpWidget(_app(player: Player(life: life)));
      expect(find.text('關係 · 相伴'), findsOneWidget);
      await _show(tester, 'life-goals');
      for (var index = 0; index < 3; index++) {
        final goal = find.byKey(ValueKey('life-goal-$index'));
        expect(
          find.descendant(of: goal, matching: find.byIcon(Icons.check_circle)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('life-goal-3')),
          matching: find.byIcon(Icons.radio_button_unchecked),
        ),
        findsOneWidget,
      );
      await _show(tester, 'life-practice-student');
      expect(find.text('已學會 1 項心得'), findsOneWidget);
      expect(find.text('傳承：工程師心得'), findsOneWidget);
      expect(find.text('工程師心得 · 已學會'), findsOneWidget);
      expect(find.text('已實踐 1 次 / 3 次'), findsOneWidget);
      expect(find.text(_service.skillDescription('engineer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('age sixty unlocks reincarnation before finishing the campaign', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(player: const Player(life: LifeProgress(turns: 168))),
    );
    expect(find.text('60 歲'), findsOneWidget);
    await _show(tester, 'life-reincarnate');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('life-reincarnate')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'canceling reincarnation makes no change and selected skill returns exactly once',
    (tester) async {
      final initial = Player(
        clearedStages: 6,
        life: const LifeProgress().copyWith(
          learnedSkills: ['student', 'engineer'],
        ),
      );
      final pending = Completer<Player>();
      var calls = 0;
      String? selected;
      Player? result;
      var returns = 0;
      final observer = _JournalObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const ValueKey('open-journal-test'),
                  onPressed: () async {
                    result = await Navigator.of(context).push<Player>(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'journal'),
                        builder: (_) => LifeJournalScreen(
                          player: initial,
                          jobTitle: _jobTitle,
                          onAction: (action) async =>
                              _service.lifeAction(initial, action),
                          onReincarnate: (skill) {
                            calls++;
                            selected = skill;
                            return pending.future;
                          },
                        ),
                      ),
                    );
                    returns++;
                  },
                  child: const Text('開啟手帳'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-journal-test')));
      await tester.pumpAndSettle();
      await _show(tester, 'life-reincarnate');
      await tester.tap(find.byKey(const ValueKey('life-reincarnate')));
      await tester.pumpAndSettle();
      expect(find.textContaining('此操作不能復原'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('life-reincarnation-cancel')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(LifeJournalScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('life-reincarnate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('life-inherit-skill')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('工程師心得').last);
      await tester.pumpAndSettle();
      expect(find.text(_service.skillDescription('engineer')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('life-reincarnation-confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls, 1);
      expect(selected, 'engineer');
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('life-journal-back')))
            .onPressed,
        isNull,
      );
      expect(observer.journalPops, 0);
      pending.complete(_service.reincarnate(initial, inheritSkill: selected));
      await tester.pumpAndSettle();
      expect(find.byType(LifeJournalScreen), findsNothing);
      expect(find.byKey(const ValueKey('open-journal-test')), findsOneWidget);
      expect(result?.life.generation, 2);
      expect(result?.life.inheritedSkill, 'engineer');
      expect(returns, 1);
      expect(observer.journalPops, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reincarnation with no skill passes null and errors leave the journal usable',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _app(
          player: const Player(clearedStages: 6),
          onReincarnate: (skill) async {
            calls++;
            expect(skill, isNull);
            throw StateError('轉生儲存失敗');
          },
        ),
      );
      await _show(tester, 'life-reincarnate');
      await tester.tap(find.byKey(const ValueKey('life-reincarnate')));
      await tester.pumpAndSettle();
      expect(find.text('不傳承，重新開始'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('life-reincarnation-confirm')),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(LifeJournalScreen), findsOneWidget);
      expect(find.textContaining('轉生儲存失敗'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('life-reincarnate')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('life-journal-back')))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _JournalObserver extends NavigatorObserver {
  int journalPops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route.settings.name == 'journal') journalPops++;
  }
}
