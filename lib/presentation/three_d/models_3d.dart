import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/player.dart';
import '../art/equipment_layers.dart';
import 'scene_3d.dart';
import 'career_details.dart';
import 'creature_models.dart';

class Models3D {
 static const armorColors={
   'coat':Color(0xFFAE794C),'robe':Color(0xFF626FBE),'plate':Color(0xFFA9C4D9),
   'ranger_cloak':Color(0xFF417D69),'scholar_coat':Color(0xFF446C92),
   'flame_armor':Color(0xFFB85648),'astral_robe':Color(0xFF765AAA),
 };
 static void armorDetails(Scene3D s,String id){
   if(id=='none')return;
   const gold=Color(0xFFEACC85);
   if(id=='ranger_cloak'||id=='astral_robe'){
     final c=armorColors[id]!;
     s.face([const V3(-.3,1.19,-.21),const V3(.3,1.19,-.21),const V3(.48,.18,-.43),const V3(-.48,.18,-.43)],c);
     for(final x in [-.32,.32])s.box(V3(x,.7,-.34),const V3(.035,.8,.06),gold);
     if(id=='astral_robe')for(final y in [.4,.65,.9])s.orb(V3(0,y,-.44),const V3(.07,.07,.035),const Color(0xFFBDEAFF),slices:4,rings:3);
   }
   if(id=='scholar_coat'){
     for(final x in [-.21,.21])s.box(V3(x,.82,.23),const V3(.065,.53,.04),gold);
     s.box(const V3(.16,.81,.25),const V3(.15,.18,.04),const Color(0xFFADC5E5));
   }
   if(id=='flame_armor'){
     for(final x in [-.36,.36])s.pyramid(V3(x,1.15,0),.16,.23,const Color(0xFFF2B968));
     s.orb(const V3(0,.94,.26),const V3(.12,.15,.06),const Color(0xFFFFC777),slices:4,rings:3);
   }
 }
 static void accessory(Scene3D s,String id){
   const gold=Color(0xFFF5D18C);
   switch(id){
     case 'ruby_ring':
       s.orb(const V3(.43,.69,.17),const V3(.09,.09,.055),gold,slices:8,rings:3);
       s.orb(const V3(.43,.7,.22),const V3(.065,.07,.04),const Color(0xFFE96D7B),slices:4,rings:3);break;
     case 'sapphire_pendant':
       s.box(const V3(0,1.03,.23),const V3(.025,.22,.025),gold);
       s.orb(const V3(0,.9,.27),const V3(.12,.15,.06),const Color(0xFF75BCF5),slices:6,rings:4);break;
     case 'guardian_brooch':
       s.box(const V3(-.17,1.03,.25),const V3(.19,.22,.045),gold);
       s.box(const V3(-.17,1.03,.28),const V3(.07,.13,.025),const Color(0xFF70DBB7));break;
     case 'wing_charm':
       for(final sign in [-1.0,1.0])s.face([const V3(0,.98,.26),V3(sign*.19,1.13,.26),V3(sign*.14,.99,.26)],gold);
       s.orb(const V3(0,1,.28),const V3(.065,.08,.04),const Color(0xFFBA9DF0),slices:6,rings:3);break;
     default:break;
   }
 }
 static Color jobColor(String job)=>switch(job){
  'student'=>const Color(0xFF57916D),'part_timer'=>const Color(0xFFC97559),
  'engineer'=>const Color(0xFF4988A1),'artist'=>const Color(0xFFD79652),
  'warrior'=>const Color(0xFF8BABB4),'scholar'=>const Color(0xFFBCA874),
  'president'=>const Color(0xFFE9DFCC),'mentor'=>const Color(0xFF8466AD),
  'hero'=>const Color(0xFFE8C35D),'apprentice'=>const Color(0xFFB08C62),
  'adventurer'=>const Color(0xFF598669),'doctor'=>const Color(0xFFE9F2E9),
  'mage'=>const Color(0xFF5167B0),'ranger'=>const Color(0xFF4E8F67),
  'merchant'=>const Color(0xFFA25F72),'archmage'=>const Color(0xFF9669C1),
  'paladin'=>const Color(0xFFF2D783),'ranger_master'=>const Color(0xFF3F9E8A),
  'alchemist'=>const Color(0xFF55A18D),'sage'=>const Color(0xFF5376A6),
  'bard'=>const Color(0xFFC887A1),'maestro'=>const Color(0xFF6C4F8F),
  'chef'=>const Color(0xFFAF705B),'gourmet_master'=>const Color(0xFFD4A456),
  'guardian'=>const Color(0xFF507B9A),'warlord'=>const Color(0xFFAA5155),
  'dancer'=>const Color(0xFFDB8DAA),'celestial_dancer'=>const Color(0xFFA48ADB),
  'beast_tamer'=>const Color(0xFF719669),'dragon_tamer'=>const Color(0xFF4F969D),
  _=>const Color(0xFF849469),
 };
 static void hero(Scene3D scene,V3 pos,EquipmentLook look,{double scale=1,double walk=0,double facing=0}) {
   final local=Scene3D();
   final female=look.gender==CharacterGender.female;
   final coat=armorColors[look.armor] ?? jobColor(look.jobId);
   const skin=Color(0xFFF1BE95),dark=Color(0xFF46392E),gold=Color(0xFFE8C975);
   final step=math.sin(walk)*.12;
   for(final sign in [-1.0,1.0]) {
     local.box(V3(sign*.15,.24,sign*step),const V3(.22,.42,.25),dark);
     local.box(V3(sign*.15,.06,.05+sign*step),const V3(.25,.14,.34),const Color(0xFF544637));
     local.box(V3(sign*.38,.89,-sign*step),const V3(.18,.43,.22),coat);
     local.orb(V3(sign*.38,.65,-sign*step),const V3(.12,.12,.12),skin,slices:6,rings:3);
   }
   local.box(const V3(0,.85,0),V3(female ? .5 : .56,.65,.34),coat);
   local.face([const V3(-.24,1.17,.18),const V3(-.03,.95,.21),const V3(-.02,1.17,.2)],const Color(0xFFFFECCB));
   local.face([const V3(.24,1.17,.18),const V3(.03,.95,.21),const V3(.02,1.17,.2)],const Color(0xFFFFECCB));
   for(final y in [.76,.88])local.orb(V3(0,y,.2),const V3(.025,.025,.02),gold,slices:6,rings:2);
   local.box(const V3(0,.59,.02),const V3(.59,.08,.39),dark);
   local.box(const V3(0,.59,.23),const V3(.13,.09,.045),gold);
   if(['robe','astral_robe','scholar_coat'].contains(look.armor)||['mage','archmage','scholar','mentor'].contains(look.jobId))local.pyramid(const V3(0,.22,0),.45,.7,coat);
   if(['plate','flame_armor'].contains(look.armor)||['warrior','hero','paladin'].contains(look.jobId)) {
     for(final sign in [-1.0,1.0])local.orb(V3(sign*.35,1.09,0),const V3(.22,.14,.25),gold,slices:6,rings:3);
     local.box(const V3(0,.91,.2),const V3(.3,.28,.06),const Color(0xFF719BB6));
   }
   local.orb(const V3(0,1.49,0),const V3(.35,.35,.31),skin);
   local.orb(const V3(0,1.71,-.04),const V3(.36,.22,.32),dark,slices:10,rings:4);
   local.orb(const V3(0,1.54,-.22),V3(.34,female ? .38 : .22,.2),dark,slices:10,rings:4);
   for(final x in [-.28,-.1,.09,.26])local.pyramid(V3(x,1.7,.02),.15,.2,dark,sides:4);
   if(female)local.orb(const V3(-.32,1.49,-.22),const V3(.2,.38,.19),dark,slices:6,rings:4);
   for(final x in [-.12,.12]) {
     local.box(V3(x,1.53,.292),const V3(.085,.11,.028),const Color(0xFF322E2D));
     local.box(V3(x-.015,1.56,.314),const V3(.025,.028,.01),Colors.white);
   }
   for(final x in [-.22,.22])local.orb(V3(x,1.42,.27),const V3(.06,.025,.02),const Color(0xFFEFA7A0),slices:6,rings:2);
   local.box(const V3(0,1.39,.30),const V3(.11,.025,.025),const Color(0xFFAA6555));
   if(['mage','archmage','scholar'].contains(look.jobId))local.pyramid(const V3(0,1.81,0),.47,.42,jobColor(look.jobId),sides:6);
   if(['student','mentor'].contains(look.jobId))local.box(const V3(0,1.85,0),const V3(.72,.06,.62),jobColor(look.jobId));
   if(['artist','merchant','part_timer'].contains(look.jobId))local.orb(const V3(0,1.83,0),const V3(.4,.12,.34),jobColor(look.jobId),slices:8,rings:3);
   if(['hero','paladin'].contains(look.jobId))for(final x in [-.24,0.0,.24])local.pyramid(V3(x,1.8,.12),.09,.2,gold);
   if(look.jobId=='doctor') {
     local.box(const V3(0,1,.2),const V3(.08,.25,.045),const Color(0xFFC45463));
     local.box(const V3(0,1,.23),const V3(.22,.08,.045),const Color(0xFFC45463));
   }
   CareerDetails.add(local,look.jobId,jobColor(look.jobId),uncovered:look.armor=='none');
   armorDetails(local,look.armor);
   weapon(local,look.weapon,V3(.43,.66,.03-step));
   accessory(local,look.accessory);

   if(look.accessory=='ring')local.orb(const V3(.43,.69,.15),const V3(.075,.065,.06),const Color(0xFF6DD6F2),slices:6,rings:3);
   if(look.accessory=='pendant') {local.box(const V3(0,1,.21),const V3(.035,.27,.035),gold);local.orb(const V3(0,.87,.24),const V3(.09,.12,.045),const Color(0xFFE87D80),slices:6,rings:3);}
   if(look.accessory=='charm')local.orb(const V3(-.16,1.03,.23),const V3(.1,.1,.035),gold,slices:5,rings:3);
   for(final face in local.faces) {
     scene.face(face.points.map((v){final x=v.x*math.cos(facing)+v.z*math.sin(facing),z=-v.x*math.sin(facing)+v.z*math.cos(facing);return pos+V3(x,v.y,z)*scale;}).toList(),face.color);
   }
 }
 static void weapon(Scene3D s,String id,V3 hand){
   if(id=='none')return;
   const gold=Color(0xFFE9C874);
   final legendary=['dawnblade','astral_staff','fate_bow'].contains(id);
   final color=legendary?gold:const Color(0xFFADCEDD);
   if(id=='ember_spear'){
     s.box(hand+const V3(0,.2,0),const V3(.06,1.65,.06),const Color(0xFF694948));
     s.pyramid(hand+const V3(0,1.01,0),.16,.4,const Color(0xFFFFAC6B));
     s.box(hand+const V3(0,.96,0),const V3(.32,.06,.08),gold);
   }else if(id=='frost_wand'){
     s.box(hand+const V3(0,.23,0),const V3(.06,1.1,.06),const Color(0xFF97BDDC));
     for(final x in [-.13,0.0,.13])s.orb(hand+V3(x,.88-x.abs(),0),const V3(.09,.23,.09),const Color(0xFF9DEBFF),slices:4,rings:3);
   }else if(id=='thunder_hammer'){
     s.box(hand+const V3(0,.2,0),const V3(.085,.95,.085),gold);
     s.box(hand+const V3(0,.75,0),const V3(.5,.28,.23),const Color(0xFF7C88B6));
     s.box(hand+const V3(0,.75,.13),const V3(.065,.22,.035),const Color(0xFFB9F6FF));
   }else if(id=='moon_blades'){
     for(final x in [0.0,-.86]){
       s.box(hand+V3(x,.21,0),const V3(.1,.5,.05),const Color(0xFFB1BCEB));
       s.pyramid(hand+V3(x,.46,0),.09,.19,const Color(0xFFF0D6F7));
       s.box(hand+V3(x,-.06,0),const V3(.2,.05,.07),gold);
     }
   }else if(id=='staff'||id=='astral_staff') {
     s.box(hand+const V3(0,.25,0),const V3(.065,1.3,.065),gold);
     s.orb(hand+const V3(0,.95,0),const V3(.19,.23,.18),legendary?const Color(0xFFC0A4FB):const Color(0xFF65DCEB),slices:6,rings:4);
   }else if(id=='longbow'||id=='fate_bow'){
     for(var i=0;i<9;i++){final a=-math.pi/2+i*math.pi/8;s.orb(hand+V3(math.cos(a)*.22,.3+math.sin(a)*.55,0),const V3(.055,.08,.06),legendary?gold:const Color(0xFF69A77D),slices:4,rings:2);}
     s.box(hand+const V3(0,.3,0),const V3(.018,1.05,.018),Colors.white);
   }else{
     s.box(hand+const V3(0,.42,0),V3(legendary ? .19 : .12,.8,.06),id=='spellblade'?const Color(0xFFB2A1E3):color);
     s.pyramid(hand+const V3(0,.82,0),legendary ? .13 : .09,.25,color);
     s.box(hand+const V3(0,.05,0),const V3(.36,.065,.09),gold);
     s.box(hand+const V3(0,-.08,0),const V3(.065,.23,.065),const Color(0xFF5B403B));
   }
 }
 static void monster(Scene3D s,V3 pos,int kind,{bool boss=false,double scale=1}){
   final local=Scene3D();
   if(boss){CreatureModels.boss(local,kind);}else{CreatureModels.monster(local,kind);}
   for(final f in local.faces)s.face(f.points.map((v)=>pos+v*scale).toList(),f.color);
 }
 static void ground(Scene3D s,int stage){
   const colors=[Color(0xFFB0CFA2),Color(0xFFD9BD8C),Color(0xFF82B6BB),Color(0xFFB394B9),Color(0xFFB58D7C),Color(0xFF80779F)];
   s.box(const V3(0,-.35,0),const V3(8,.45,8),colors[stage-1]);
 }
 static void scenery(Scene3D s,int stage,{bool includeGround=true}){
   final palettes=[const Color(0xFFB0CFA2),const Color(0xFFD9BD8C),const Color(0xFF82B6BB),const Color(0xFFB394B9),const Color(0xFFB58D7C),const Color(0xFF80779F)];
   final color=palettes[stage-1];
   if(includeGround)ground(s,stage);
   if(stage==6){
    for(var i=0;i<8;i++){final a=i*math.pi/4;s.pyramid(V3(math.cos(a)*1.15,.05,math.sin(a)*1.15),.16,.7,const Color(0xFFD5BCEF));}
    s.box(const V3(0,.25,0),const V3(.75,.6,.75),const Color(0xFFCFB96C));
   }else if(stage==4){
    s.box(const V3(0,.15,0),const V3(2.5,.3,2),const Color(0xFF87624E));
    for(final x in [-1.0,1.0])s.box(V3(x,.8,-.4),const V3(.22,1.5,.5),const Color(0xFFA04875));
    s.box(const V3(0,1.5,-.4),const V3(2.4,.25,.5),const Color(0xFFBD9862));
   }else{
    for(final x in [-.8,.8]){
     s.box(V3(x,.4,0),const V3(.85,.8,1.1),Color.lerp(color,Colors.white,.35)!);
     if(stage==3){s.box(V3(x,.95,-.25),const V3(.2,.6,.2),const Color(0xFFADAD94));s.orb(V3(x,.55,.6),const V3(.2,.2,.05),const Color(0xFF71DFDA),slices:8,rings:3);}
     else if(stage==5){for(final dx in [-.3,0.0,.3])s.box(V3(x+dx,.93,0),const V3(.16,.3,1.1),color);}
     else{s.pyramid(V3(x,.8,0),.72,.45,stage==1?const Color(0xFF588E79):const Color(0xFFB87357));}
     s.box(V3(x,.3,.56),const V3(.2,.42,.035),const Color(0xFF746657));
    }
   }
 }
}
class Actor3D extends StatelessWidget {
 final EquipmentLook? look;
 final int enemy;
 final bool boss;
 final double width,height;
 const Actor3D({super.key,this.look,this.enemy=0,this.boss=false,this.width=150,this.height=180});
 @override Widget build(BuildContext context)=>SizedBox(width:width,height:height,child:CustomPaint(painter:_ActorPainter(look,enemy,boss)));
}
class _ActorPainter extends CustomPainter {
 final EquipmentLook? look;final int enemy;final bool boss;
 _ActorPainter(this.look,this.enemy,this.boss);
 @override void paint(Canvas canvas,Size size){
  final s=Scene3D();
  if(look!=null){Models3D.hero(s,const V3(0,0,0),look!);}else{Models3D.monster(s,const V3(0,0,0),enemy,boss:boss);}
  s.draw(canvas,size,Camera3D(eye:V3(look == null ? 2.6 : -2.6,2.3,5),target:const V3(0,1,0),focal:2.25));
 }
 @override bool shouldRepaint(covariant _ActorPainter old)=>old.look!=look||old.enemy!=enemy||old.boss!=boss;
}

class Arena3D extends CustomPainter {
 final int stage;
 const Arena3D(this.stage);
 @override void paint(Canvas canvas,Size size){
  canvas.drawRect(Offset.zero&size,Paint()..color=stage==6?const Color(0xFF292942):const Color(0xFFEADCC7));
  final s=Scene3D(),floor=Scene3D();Models3D.ground(floor,stage);Models3D.scenery(s,stage,includeGround:false);
  floor.draw(canvas,size,const Camera3D(eye:V3(3,6,9),target:V3(0,0,0),focal:1.9));
  s.draw(canvas,size,const Camera3D(eye:V3(3,6,9),target:V3(0,0,0),focal:1.9));
 }
 @override bool shouldRepaint(covariant Arena3D old)=>old.stage!=stage;
}
