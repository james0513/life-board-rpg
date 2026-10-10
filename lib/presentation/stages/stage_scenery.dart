import 'dart:math' as math;
import 'package:flutter/material.dart';
/// Shared procedural scenery for Flame's board and Flutter's battle arena.
class StageScenery extends CustomPainter {
  final int stage;
  const StageScenery(this.stage);
  static const colors=[Color(0xFFDDEAD5),Color(0xFFF5DEB7),Color(0xFFD0E7EA),Color(0xFFECD5E9),Color(0xFFE9D0C0),Color(0xFFD5CFEB)];
  @override
  void paint(Canvas canvas,Size size) {
    canvas.save();canvas.scale(size.width/900,size.height/560);
    canvas.drawRect(const Rect.fromLTWH(0,0,900,560),Paint()..color=colors[stage-1]);
    final ink=Paint()..color=const Color(0xFF687887).withValues(alpha:.28);
    switch(stage){
      case 1:
        for(var x=100;x<850;x+=160){
          canvas.drawRect(Rect.fromLTWH(x.toDouble(),180,110,200),ink);
          canvas.drawPath(Path()..moveTo(x-10.0,180)..lineTo(x+55.0,110)..lineTo(x+120.0,180)..close(),ink);
          for(var y=205;y<350;y+=50)canvas.drawRect(Rect.fromLTWH(x+25.0,y.toDouble(),60,24),Paint()..color=Colors.white54);
        }
        break;
      case 2:
        for(var i=0;i<5;i++){
          final x=35+i*178.0;
          canvas.drawRect(Rect.fromLTWH(x,210,145,160),ink);
          for(var j=0;j<6;j++)canvas.drawRect(Rect.fromLTWH(x+j*24,195,24,35),Paint()..color=j.isEven?const Color(0xFFC98155):const Color(0xFFF8EACC));
        }
        break;
      case 3:
        for(var i=0;i<4;i++){
          final x=120+i*220.0;
          canvas.drawRect(Rect.fromLTWH(x-60,220,120,190),ink);
          canvas.drawRect(Rect.fromLTWH(x-35,130,25,100),ink);
          canvas.drawCircle(Offset(x,280),48,Paint()..color=const Color(0xFF5094A2)..style=PaintingStyle.stroke..strokeWidth=12);
          for(var j=0;j<8;j++){
            final a=j*math.pi/4;
            canvas.drawLine(Offset(x,280),Offset(x+55*math.cos(a),280+55*math.sin(a)),ink..strokeWidth=8);
          }
        }
        break;
      case 4:
        canvas.drawRect(const Rect.fromLTWH(0,0,900,65),Paint()..color=const Color(0xFF824963));
        for(final x in [0.0,760.0])canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,0,140,440),const Radius.circular(65)),Paint()..color=const Color(0xFFAD6989));
        canvas.drawOval(const Rect.fromLTWH(190,210,520,230),Paint()..color=Colors.white38);
        break;
      case 5:
        canvas.drawRect(const Rect.fromLTWH(100,200,700,210),ink);
        for(var x=100;x<810;x+=100)canvas.drawRect(Rect.fromLTWH(x.toDouble(),155,55,70),ink);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(350,260,200,180),const Radius.circular(90)),Paint()..color=const Color(0xFF91675B));
        break;
      case 6:
        canvas.drawRect(const Rect.fromLTWH(0,0,900,560),Paint()..color=const Color(0xFF302C53));
        for(var i=0;i<65;i++)canvas.drawCircle(Offset((i*137%900).toDouble(),(i*79%450).toDouble()),i%3+1.0,Paint()..color=Colors.white54);
        for(var i=0;i<3;i++)canvas.drawCircle(const Offset(450,250),80+i*35.0,Paint()..color=const Color(0xFFB1A0DD)..style=PaintingStyle.stroke..strokeWidth=3);
        break;
    }
    canvas.drawRect(const Rect.fromLTWH(0,455,900,105),Paint()..color=const Color(0x22605340));
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant StageScenery old)=>old.stage!=stage;
}
