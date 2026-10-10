import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/game_screen.dart';
import 'presentation/widgets/creator_credit.dart';

void main() => runApp(const ProviderScope(child: LifeApp()));

class LifeApp extends StatelessWidget {
  const LifeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '人生棋盤',
    builder:(context,child)=>Column(children:[Expanded(child:child ?? const SizedBox.shrink()),const CreatorCredit()]),
    theme: ThemeData(colorSchemeSeed: const Color(0xFF3D7167),
      scaffoldBackgroundColor: const Color(0xFFF1EBDC), useMaterial3: true,
      appBarTheme:const AppBarTheme(backgroundColor:Color(0xFFF9F3E5),foregroundColor:Color(0xFF304F45),centerTitle:false),
      dividerTheme:const DividerThemeData(color:Color(0xFFD9C7A7)),
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:22,vertical:15))),
      dialogTheme:DialogThemeData(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),backgroundColor:const Color(0xFFFFFAEF))),
    home: const GameScreen(),
  );
}
