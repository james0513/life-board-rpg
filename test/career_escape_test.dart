// Flutter regression coverage; requires the local Flutter test runtime.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/services/job_manager.dart';
import 'package:life_graybox/presentation/widgets/career_dialog.dart';

void main() {
  late JobManager jobs;
  setUp(() async {
    jobs = JobManager(loadJson: (path) => File(path).readAsString());
    await jobs.load();
  });

  testWidgets('Esc cancels once, preserves player, restores board focus', (
    tester,
  ) async {
    const player = Player(money: 1200, jobId: 'student');
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var closed = 0;
    String? choice = 'not returned';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              focusNode: focus,
              autofocus: true,
              onPressed: () async {
                choice = await showDialog<String>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => CareerDialog(player: player, jobs: jobs),
                );
                closed++;
              },
              child: const Text('棋盤'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.tap(find.text('棋盤'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(find.byType(CareerDialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CareerDialog), findsNothing);
    expect(choice, isNull);
    expect(closed, 1);
    expect(player.money, 1200);
    expect(player.jobId, 'student');
    expect(focus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('棋盤'), findsOneWidget);
    expect(closed, 1);
    // A second visit has fresh cancellation state.
    await tester.tap(find.text('棋盤'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(closed, 2);
  });
  testWidgets('Escape never dismisses career through an unrelated top dialog', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('棋盤')),
      ),
    );
    showDialog<String>(
      context: navigator.currentContext!,
      barrierDismissible: false,
      builder: (_) => CareerDialog(player: const Player(), jobs: jobs),
    );
    await tester.pumpAndSettle();
    showDialog<void>(
      context: navigator.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('其他視窗'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉其他視窗'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('其他視窗'), findsOneWidget);
    expect(find.byType(CareerDialog, skipOffstage: false), findsOneWidget);
    await tester.tap(find.text('關閉其他視窗'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CareerDialog), findsNothing);
    expect(find.text('棋盤'), findsOneWidget);
  });
}
