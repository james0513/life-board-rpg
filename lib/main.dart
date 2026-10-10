import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/game_screen.dart';
import 'presentation/widgets/creator_credit.dart';
import 'presentation/theme/game_design.dart';

void main() => runApp(const ProviderScope(child: LifeApp()));

class LifeApp extends StatelessWidget {
  const LifeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '人生棋盤',
    builder:(context,child)=>Column(children:[Expanded(child:child ?? const SizedBox.shrink()),const CreatorCredit()]),
    theme: GameDesign.theme,
    home: const GameScreen(),
  );
}
