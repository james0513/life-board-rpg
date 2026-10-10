import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/player.dart';
import '../../domain/models/shop_item.dart';
import '../art/equipment_layers.dart';
import '../three_d/models_3d.dart';
class VictoryScreen extends StatefulWidget {
 final Player player;final String jobTitle;
 const VictoryScreen({super.key,required this.player,required this.jobTitle});
 @override State<VictoryScreen> createState()=>_VictoryScreenState();
}
class _VictoryScreenState extends State<VictoryScreen> with SingleTickerProviderStateMixin {
 late final AnimationController motion=AnimationController(vsync:this,duration:const Duration(seconds:8))..forward();
 @override void dispose(){motion.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(body:Stack(children:[
  const Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF202B48),Color(0xFF574478),Color(0xFF302F52)])))),
  Positioned.fill(child:IgnorePointer(child:AnimatedBuilder(animation:motion,builder:(_,__)=>CustomPaint(painter:_Celebration(motion.value))))),
  SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:720),child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(children:[
    const Icon(Icons.emoji_events_rounded,color:Color(0xFFF8D58A),size:66),
    const Text('恭喜破關！',style:TextStyle(fontSize:40,fontWeight:FontWeight.w900,color:Color(0xFFFFE2A2))),
    const SizedBox(height:8),
    const Text('六關全破 · 命運由你改寫',style:TextStyle(fontSize:20,color:Colors.white)),
    Actor3D(look:EquipmentLook.fromPlayer(widget.player),width:230,height:240),
    Text('${widget.player.displayName} · ${widget.jobTitle}',style:const TextStyle(fontSize:24,color:Colors.white,fontWeight:FontWeight.bold)),
    const SizedBox(height:10),
    const Text('你擊敗了命運編織者，走出了別人寫好的劇本。\n回棋盤打開「人生故事」，記錄這一世的結局；\n再到「人生手帳」選擇傳承，開啟下一世。',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFFE3DCEC),height:1.8)),
    const SizedBox(height:22),
    Wrap(alignment:WrapAlignment.center,spacing:8,runSpacing:8,children:[for(final name in ['青芽學園','黃金商店街','齒輪科技城','幻彩大劇院','赤岩英雄堡','命運王座'])
      Chip(avatar:const Icon(Icons.check_circle,color:Color(0xFF4C8568),size:18),label:Text(name))]),
    const SizedBox(height:16),
    Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
      Text('Lv.${widget.player.level} · EXP ${widget.player.experience} · 金錢 \$${widget.player.money}'),
      Text('目前裝備：${weaponName(widget.player.weaponId)}'),
      Text('體力 ${widget.player.stamina} · 智力 ${widget.player.intelligence} · 魅力 ${widget.player.charm} · 道德 ${widget.player.morality}'),
    ]))),
    const SizedBox(height:16),
    FilledButton.icon(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.explore_outlined),label:const Text('繼續自由冒險')),
    const SizedBox(height:12),const Text('破關進度已儲存 · 棋盤右上角獎盃可再次觀看',style:TextStyle(color:Color(0xFFDDD2EA),fontSize:12)),
  ]))))),
 ]));
}
class _Celebration extends CustomPainter {
 final double progress;
 const _Celebration(this.progress);
 @override void paint(Canvas canvas,Size size){
  const colors=[Color(0xFFFFD580),Color(0xFF78DACC),Color(0xFFC29BEA),Color(0xFFFFA6AA)];
  for(var i=0;i<80;i++){
   final x=(i*137%1000)/1000*size.width+math.sin(progress*12+i)*18;
   final y=(progress*1.6-(i%17)/25)*size.height;
   if(y<0||y>size.height)continue;
   canvas.save();canvas.translate(x,y);canvas.rotate(i+progress*9);
   canvas.drawRect(Rect.fromCenter(center:Offset.zero,width:5+(i%4).toDouble(),height:9),Paint()..color=colors[i%4]);canvas.restore();
  }
 }
 @override bool shouldRepaint(covariant _Celebration old)=>old.progress!=progress;
}
