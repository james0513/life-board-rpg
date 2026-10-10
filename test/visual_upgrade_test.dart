import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/models/shop_item.dart';
import 'package:life_graybox/domain/models/save_data.dart';
import 'package:life_graybox/domain/services/shop_service.dart';
import 'package:life_graybox/presentation/art/equipment_layers.dart';
import 'package:life_graybox/presentation/art/appearance.dart';
import 'package:life_graybox/presentation/three_d/scene_3d.dart';
import 'package:life_graybox/presentation/three_d/models_3d.dart';
import 'package:life_graybox/presentation/battle/spell_effect.dart';

const additions=['ember_spear','frost_wand','thunder_hammer','moon_blades',
  'ranger_cloak','scholar_coat','flame_armor','astral_robe',
  'ruby_ring','sapphire_pendant','guardian_brooch','wing_charm'];

Future<List<int>> raster(void Function(Canvas) paint) async {
  final recorder=ui.PictureRecorder();
  paint(Canvas(recorder));
  final picture=recorder.endRecording();
  final image=await picture.toImage(220,220);
  final bytes=await image.toByteData(format:ui.ImageByteFormat.rawRgba);
  final result=bytes!.buffer.asUint8List(bytes.offsetInBytes,bytes.lengthInBytes).toList();
  image.dispose();picture.dispose();return result;
}
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('terrain and labels never erase opaque pawn pixels when camera rotates',()async{
   for(final yaw in [0.0,math.pi/2,math.pi,math.pi*1.5]){
     const size=Size(220,220);
     final camera=Camera3D(eye:V3(math.sin(yaw)*9,8,math.cos(yaw)*9),target:const V3(0,.4,0),focal:1.35);
     for(final z in [-2.5,2.5]){
       final terrain=Scene3D(),actor=Scene3D();
       Models3D.ground(terrain,1);
       Models3D.hero(actor,V3(0,.16,z),const EquipmentLook(jobId:'hero',weapon:'ember_spear'),scale:.58);
       final isolated=await raster((c)=>actor.draw(c,size,camera));
       final composited=await raster((c)=>terrain.drawWithForeground(c,size,camera,actor,
         labels:()=>c.drawRect(Offset.zero&size,Paint()..color=Colors.blue)));
       var solid=0;
       for(var i=0;i<isolated.length;i+=4){
         if(isolated[i+3]!=255)continue;
         solid++;
         for(var channel=0;channel<3;channel++)expect(composited[i+channel],closeTo(isolated[i+channel],1));
       }
       expect(solid,greaterThan(10),reason:'Pawn must be visible from yaw $yaw at z $z');
     }
   }
 });
 test('new gear unlocks at declared chapter and persists in the correct slot',(){
   const shop=ShopService();
   for(final id in additions){
     final item=shopById(id);
     expect(()=>shop.buy(Player(money:20000,clearedStages:item.unlockStage-2),id),throwsStateError);
     final player=Player(money:20000,clearedStages:item.unlockStage-1);
     final bought=shop.buy(player,id),equipped=shop.equip(shop.buy(player,id),id);
     expect(bought.money,player.money-item.price);
     expect(equippedId(equipped,item.slot!),id);
     final restored=SaveData.decode(SaveData(equipped,DateTime.utc(2026)).encode(),{'unemployed'}).player;
     expect(equippedId(restored,item.slot!),id);
     final again=shop.equip(restored,id);
     expect(equipmentAttack(again),item.attack);expect(equipmentMagic(again),item.magic);
     expect(equipmentDefense(again),item.defense);expect(equipmentHp(again),item.hp);
     expect(equipmentCritical(again),item.critical);
     expect(()=>shop.equip(player,id),throwsStateError);
   }
 });
 test('all eighteen careers and new gear produce distinct mesh signatures',(){
   String signature(EquipmentLook look){
     final scene=Scene3D();Models3D.hero(scene,const V3(0,0,0),look);
     return scene.faces.map((f)=>'${f.color}:${f.points.map((p)=>'${p.x},${p.y},${p.z}').join(';')}').join('|');
   }
   for(final gender in CharacterGender.values){
     final signatures={for(final id in CareerAppearance.jobs)signature(EquipmentLook(jobId:id,gender:gender))};
     expect(signatures.length,CareerAppearance.jobs.length);
   }
   final gear={for(final id in additions)signature(EquipmentLook(
     weapon:shopById(id).kind==ShopKind.weapon?id:'none',
     armor:shopById(id).kind==ShopKind.armor?id:'none',
     accessory:shopById(id).kind==ShopKind.accessory?id:'none'))};
   expect(gear.length,additions.length);
 });
 test('magic supports all phases and reduced-effects mode without paint errors',(){
   for(final job in ['engineer','warrior','scholar','artist','student']){
     for(final element in <String?>[null,'ice','heal','burst']){
       for(final t in [0.0,.25,.59,.6,.8,1.0]){
         for(final reduced in [false,true]){
           final recorder=ui.PictureRecorder();
           SpellEffect(progress:t,jobId:job,element:element,reducedEffects:reduced).paint(Canvas(recorder),const Size(220,220));
           recorder.endRecording().dispose();
         }
       }
     }
   }
 });
 test('ice healing and meteor impact effects render differently',()async{
   final signatures=<String>{};
   for(final element in ['ice','heal','burst']){
     final pixels=await raster((c)=>SpellEffect(progress:.75,jobId:'mage',element:element).paint(c,const Size(220,220)));
     expect(pixels.any((v)=>v!=0),isTrue);signatures.add(pixels.join(','));
   }
   expect(signatures.length,3);
 });
}
