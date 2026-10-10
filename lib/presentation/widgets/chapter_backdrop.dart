import 'package:flutter/material.dart';

String chapterBackgroundAsset(int stage)=>'assets/images/backgrounds/stage_${stage.toString().padLeft(2,'0')}_v18.png';

class ChapterBackdrop extends StatelessWidget {
 final int stage;
 const ChapterBackdrop({super.key,required this.stage});
 @override Widget build(BuildContext context)=>Stack(fit:StackFit.expand,children:[
   AnimatedSwitcher(duration:const Duration(milliseconds:450),child:SizedBox.expand(key:ValueKey(stage),child:
     Image.asset(chapterBackgroundAsset(stage),fit:BoxFit.cover,alignment:Alignment.center,
       cacheWidth:1536,excludeFromSemantics:true,
       errorBuilder:(_,__,___)=>ColoredBox(color:stage>=3?const Color(0xFF465365):const Color(0xFFD9D3BA))))),
   const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
     colors:[Color(0x05000000),Color(0x12000000),Color(0x450E1020)],stops:[0,.7,1]))),
 ]);
}
