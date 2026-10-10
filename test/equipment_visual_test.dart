import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/models/shop_item.dart';
import 'package:life_graybox/presentation/art/equipment_layers.dart';
import 'package:life_graybox/presentation/art/appearance.dart';
import 'package:life_graybox/presentation/game/life_game.dart';
import 'package:life_graybox/presentation/components/player_component.dart';
import 'package:flame/components.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('every purchasable equipment item has a visual layer',(){
   final visible={...EquipmentLayers.weapons,...EquipmentLayers.armors,...EquipmentLayers.accessories};
   expect(visible,shopCatalog.where((i)=>i.isEquipment).map((i)=>i.id).toSet());
 });
 test('all career gender and walk-frame anchors remain in the character cell',(){
   for(final gender in CharacterGender.values){
    for(final id in CareerAppearance.jobs){
     for(final frame in [0,1]){
      final rig=EquipmentRig.forLook(EquipmentLook(jobId:id,gender:gender),frame);
      expect(rig.bodyX,inInclusiveRange(35,70));
      expect(rig.hand.dx,inInclusiveRange(50,88));
      expect(rig.hand.dy,inInclusiveRange(45,75));
     }
    }
   }
 });
 test('empty loadout paints nothing and individual equipment paints distinct pixels',()async{
   Future<List<int>> pixels(EquipmentLook look)async{
     final recorder=ui.PictureRecorder();final canvas=ui.Canvas(recorder);
     EquipmentLayers.paint(canvas,const ui.Rect.fromLTWH(0,0,200,200),look);
     final picture=recorder.endRecording();final image=await picture.toImage(200,200);
     final bytes=await image.toByteData(format:ui.ImageByteFormat.rawRgba);
     final result=bytes!.buffer.asUint8List().toList();image.dispose();picture.dispose();return result;
   }
   expect((await pixels(const EquipmentLook())).every((v)=>v==0),true);
   final signatures=<String>{};
   for(final i in shopCatalog.where((i)=>i.isEquipment)){
     final look=EquipmentLook(weapon:i.kind==ShopKind.weapon?i.id:'none',armor:i.kind==ShopKind.armor?i.id:'none',accessory:i.kind==ShopKind.accessory?i.id:'none');
     final data=await pixels(look);expect(data.any((v)=>v!=0),true);
     signatures.add(data.join(','));
   }
   expect(signatures.length,shopCatalog.where((i)=>i.isEquipment).length);
 });
 test('empty-handed base atlases load for both genders and both job groups',()async{
   for(final sex in CharacterGender.values){
    for(final job in ['student','mage']){
      final bytes=await rootBundle.load(CareerAppearance.assetFor(sex,jobId:job));
      final codec=await ui.instantiateImageCodec(bytes.buffer.asUint8List(bytes.offsetInBytes,bytes.lengthInBytes));
      final image=(await codec.getNextFrame()).image;
      final pawn=PlayerComponent(Vector2.zero())..equipment=EquipmentLook(jobId:job,gender:sex,weapon:'staff',armor:'robe',accessory:'pendant');
      pawn.setCareer(image,job);
      final recorder=ui.PictureRecorder(),bounds=const ui.Rect.fromLTWH(0,0,150,180);
      final canvas=ui.Canvas(recorder);pawn.render(canvas);
      EquipmentLayers.paint(canvas,bounds,pawn.equipment,frame:1);
      recorder.endRecording().dispose();image.dispose();codec.dispose();
    }
   }
 });
 test('board accepts equipment before asset loading and tracks unchanged player values',(){
   const player=Player(jobId:'mage',weaponId:'staff',armorId:'robe',accessoryId:'ring');
   final look=EquipmentLook.fromPlayer(player);
   final game=LifeGame(initialPosition:0,equipment:look,jobId:player.jobId);
   game.changeEquipment(const EquipmentLook());
   expect(look.weapon,'staff');expect(look.armor,'robe');expect(look.accessory,'ring');
   expect(player.intelligence,10);
 });
}
