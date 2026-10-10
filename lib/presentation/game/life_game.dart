import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/painting.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import '../../domain/models/board_tile.dart';
import '../../domain/models/player.dart';
import '../art/equipment_layers.dart';
import '../components/player_component.dart';
import '../components/tile_component.dart';
import '../three_d/scene_3d.dart';
import '../three_d/models_3d.dart';
import '../three_d/chapter_board.dart';

class LifeGame extends FlameGame {
 LifeGame({EquipmentLook equipment=const EquipmentLook(),this.stage=1,required this.initialPosition,this.onBoardReady,
   String jobId='unemployed',CharacterGender gender=CharacterGender.male}):_equipment=equipment.withCharacter(jobId,gender);
 EquipmentLook _equipment;
 int stage;
 final int initialPosition;
 final void Function()? onBoardReady;
 late final PlayerComponent pawn;
 bool isBoardReady=false;
 double yaw=.72,zoom=1,_clock=0,_heading=0;
 V3? _last;
 Scene3D? _terrain;
 Scene3D? _base;
 int? _terrainStage;
 void changeEquipment(EquipmentLook value){_equipment=value;if(isBoardReady){pawn.equipment=value;pawn.jobId=value.jobId;}}
 void changeStage(int value)=>stage=value;
 void changeCareer(String id,{CharacterGender? gender})=>changeEquipment(_equipment.withCharacter(id,gender??_equipment.gender));
 void orbit(double amount)=>yaw+=amount;
 void changeZoom(double amount)=>zoom=(zoom+amount).clamp(.75,1.35).toDouble();
 void resetCamera(){yaw=.72;zoom=1;}
 static final List<Vector2> centers=boardCenters.map((p)=>Vector2(p.x,p.y)).toList();
 Vector2 pawnCenter(int index)=>centers[index]+Vector2(0,-1);
 static V3 worldFromPoint(double x,double y){
   final a=(x-450)/72,b=(y-85)/36;
   return V3((a+b)/2-2.5,0,(b-a)/2-2.5);
 }
 @override Color backgroundColor()=>const Color(0x00000000);
 @override Future<void> onLoad()async{
   await super.onLoad();
   pawn=PlayerComponent(pawnCenter(initialPosition))..equipment=_equipment..jobId=_equipment.jobId;
   await add(pawn); // movement controller remains; rendering uses XYZ meshes below.
   isBoardReady=true;onBoardReady?.call();
 }
 @override void update(double dt){
   super.update(dt);_clock+=dt;
   if(!isBoardReady)return;
   final p=worldFromPoint(pawn.position.x,pawn.position.y+1);
   if(_last!=null){final d=p-_last!;if(d.x.abs()+d.z.abs()>.001)_heading=math.atan2(d.x,d.z);}
   _last=p;
 }
 Scene3D _environment(){
   if(_terrain!=null && _terrainStage==stage)return _terrain!;
   final scene=Scene3D();
   _base=Scene3D();ChapterBoard.floor(_base!,stage);
   ChapterBoard.scenery(scene,stage);
   for(final tile in boardTiles){
     final point=centers[tile.index],p=worldFromPoint(point.x,point.y);
     ChapterBoard.tile(scene,p,tile.kind,stage);
     if(tile.kind==TileKind.shop)ChapterBoard.shop(scene,p,stage);
   }
   _terrainStage=stage;return _terrain=scene;
 }
 @override void render(Canvas canvas){
   if(!isBoardReady)return;
   final viewport = this.size;
   if(viewport.x <= 0 || viewport.y <= 0)return;
   final scale=math.min(viewport.x/900,viewport.y/560);
   canvas.save();canvas.clipRect(Rect.fromLTWH(0,0,viewport.x,viewport.y));
   canvas.scale(scale);
   final size=Size(viewport.x/scale,viewport.y/scale),scene=Scene3D(),actor=Scene3D();
   final camera=Camera3D(eye:V3(math.sin(yaw)*10/zoom,8/zoom,math.cos(yaw)*10/zoom),target:const V3(0,.2,0),focal:1.22);
   scene.faces.addAll(_environment().faces);
   canvas.drawOval(Rect.fromCenter(center:Offset(size.width/2,size.height*.58),width:500,height:235),Paint()..color=const Color(0x3D171824)..maskFilter=const MaskFilter.blur(BlurStyle.normal,22));
   _base!.draw(canvas,size,camera);
   final p=worldFromPoint(pawn.position.x,pawn.position.y+1);
   Models3D.hero(actor,p+const V3(0,.16,0),_equipment,scale:.58,walk:pawn.isWalking?_clock*12:0,facing:_heading);
   scene.drawWithForeground(canvas,size,camera,actor,labels:(){
   for(final tile in boardTiles){
     final point=centers[tile.index],p=worldFromPoint(point.x,point.y)+const V3(0,.13,.3);
     final projected=camera.project(p,size);if(projected==null)continue;
     final text=TextPainter(text:TextSpan(text:'${tile.index+1}  ${TileComponent.labels[tile.kind.index]}',
       style:const TextStyle(fontSize:9,fontWeight:FontWeight.w600,color:Color(0xFFFFF4DB))),textDirection:TextDirection.ltr)..layout();
     final plate=RRect.fromRectAndRadius(Rect.fromCenter(center:projected+const Offset(0,6),width:text.width+10,height:17),const Radius.circular(5));
     canvas.drawRRect(plate,Paint()..color=const Color(0xEB303B40));
     canvas.drawRRect(plate,Paint()..color=ChapterPalette.forStage(stage).metal..style=PaintingStyle.stroke..strokeWidth=.7);
     text.paint(canvas,Offset(projected.dx-text.width/2,projected.dy+6-text.height/2));text.dispose();
   }
   final feet=camera.project(p+const V3(0,.14,0),size);
   if(feet!=null){
     canvas.drawOval(Rect.fromCenter(center:feet,width:32,height:12),Paint()..color=const Color(0x66403824));
     canvas.drawOval(Rect.fromCenter(center:feet,width:38,height:16),Paint()..color=const Color(0xFFFFE8A8)..style=PaintingStyle.stroke..strokeWidth=2);
   }
   });
   canvas.restore();
 }
 Future<bool> move({required int from,required int steps,required void Function(int) onPosition}){
   if(!isBoardReady)return Future.value(false);
   final indices=List.generate(steps,(i)=>nextPosition(from,i+1));
   return pawn.walk(indices.map(pawnCenter).toList(),(step)=>onPosition(indices[step]));
 }
}
