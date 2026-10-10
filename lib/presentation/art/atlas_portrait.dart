import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../three_d/models_3d.dart';
import 'equipment_layers.dart';
import '../../domain/models/player.dart';

class AtlasPortrait extends StatefulWidget {
  const AtlasPortrait({super.key,required this.asset,required this.columns,
    required this.rows,required this.index,this.width=150,this.height=180,this.fit=BoxFit.contain,this.equipment});
  final String asset;
  final int columns,rows,index;
  final double width,height;
  final BoxFit fit;
  final EquipmentLook? equipment;
  @override
  State<AtlasPortrait> createState()=>_AtlasPortraitState();
}
class _AtlasPortraitState extends State<AtlasPortrait>{
  static final Map<String,Future<ui.Image>> _cache={};
  static Future<ui.Image> _load(String asset)=>_cache.putIfAbsent(asset,()async{
    try {
      final data=await rootBundle.load(asset);
      final codec=await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes));
      final image=(await codec.getNextFrame()).image;codec.dispose();return image;
    }catch(_){_cache.remove(asset);rethrow;}
  });
  @override
  Widget build(BuildContext context)=>SizedBox(width:widget.width,height:widget.height,
    child:FutureBuilder<ui.Image>(future:_load(widget.asset),builder:(context,snapshot){
      if(snapshot.hasError)return const Icon(Icons.broken_image_outlined);
      if(!snapshot.hasData)return const SizedBox.shrink();
      return CustomPaint(painter:_AtlasPainter(snapshot.data!,widget.columns,widget.rows,widget.index,widget.fit,widget.equipment));
    }));
}
class _AtlasPainter extends CustomPainter{
  _AtlasPainter(this.image,this.columns,this.rows,this.index,this.fit,this.equipment);
  final BoxFit fit;
  final EquipmentLook? equipment;
  final ui.Image image;
  final int columns,rows,index;
  @override
  void paint(Canvas canvas,Size size){
    final w=image.width/columns,h=image.height/rows;
    final source=Rect.fromLTWH((index%columns)*w,(index~/columns)*h,w,h);
    final fitted=applyBoxFit(fit,Size(w,h),size);
    final dest=Alignment.center.inscribe(fitted.destination,Offset.zero&size);
    canvas.drawImageRect(image,Alignment.center.inscribe(fitted.source,source),dest,Paint()..filterQuality=FilterQuality.medium);
    if(equipment!=null)EquipmentLayers.paint(canvas,dest,equipment!);
  }
  @override
  bool shouldRepaint(covariant _AtlasPainter old)=>old.image!=image||old.index!=index||old.columns!=columns||old.rows!=rows||old.fit!=fit||old.equipment!=equipment;
}
class CareerPortrait extends StatelessWidget{
  const CareerPortrait({super.key,required this.jobId,this.gender=CharacterGender.male,this.width=150,this.height=180,this.equipment=const EquipmentLook()});
  final String jobId;
  final EquipmentLook equipment;
  final CharacterGender gender;
  final double width,height;
  @override
  Widget build(BuildContext context){
    return Actor3D(look:equipment.withCharacter(jobId,gender),width:width,height:height);
  }
}
