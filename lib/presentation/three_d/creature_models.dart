import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'scene_3d.dart';

/// One distinct silhouette per encounter portrait. Boss indices are separate.
class CreatureModels {
 static const monsterCount=18;
 static const colors=[Color(0xFF72A5AE),Color(0xFFC69C77),Color(0xFF9C89C8),
  Color(0xFFE5C9A1),Color(0xFF72CCD4),Color(0xFFD4AF5B),Color(0xFFE5DDD0),
  Color(0xFF7C91AF),Color(0xFF67739F),Color(0xFF5963A5),Color(0xFF8A6357),
  Color(0xFFC29157),Color(0xFF729C73),Color(0xFF8BA6B0),Color(0xFFBB8CCD),
  Color(0xFF9DD2E5),Color(0xFFD88266),Color(0xFF9A8DC4)];
 static const gold=Color(0xFFE9CB83),dark=Color(0xFF343344),ivory=Color(0xFFF8EDCE);
 static void eyes(Scene3D s,double y,{double gap=.17,double z=.35}){
   for(final x in [-gap,gap]){
     s.orb(V3(x,y,z),const V3(.13,.14,.045),ivory,slices:8,rings:3);
     s.orb(V3(x,y,z+.035),const V3(.063,.083,.03),dark,slices:6,rings:3);
     s.orb(V3(x-.02,y+.035,z+.06),const V3(.022,.026,.012),Colors.white,slices:4,rings:2);
   }
 }
 static void wings(Scene3D s,Color c,{double y=1,double reach=1}){
   for(final sign in [-1.0,1.0]){
     s.face([V3(sign*.3,y,0),V3(sign*reach,y+.55,-.08),V3(sign*reach*.85,y-.18,-.03),V3(sign*.55,y-.05,.02)],c);
     s.box(V3(sign*.42,y,.01),const V3(.06,.45,.08),gold);
   }
 }
 static void crystal(Scene3D s,V3 p,Color c,{double scale=1}){
   s.orb(p,V3(.15,.28,.15)*scale,c,slices:4,rings:3);
 }
 static void monster(Scene3D s,int kind){
   final c=colors[kind];
   switch(kind){
    case 0: // clockwork
    case 7: // knight
    case 17: // sentinel
      s.box(const V3(0,.67,0),const V3(.65,.68,.42),c);
      s.orb(const V3(0,1.24,0),const V3(.34,.3,.3),c,slices:8,rings:4);
      for(final x in [-.48,.48]){s.box(V3(x,.73,0),const V3(.2,.5,.26),gold);s.box(V3(x*.4,.15,.06),const V3(.23,.28,.36),dark);}
      eyes(s,1.25,z:.28);
      if(kind==0){s.orb(const V3(0,.75,.25),const V3(.23,.23,.04),ivory,slices:12,rings:2);s.box(const V3(.06,.78,.3),const V3(.17,.025,.015),dark);}
      if(kind==7){s.box(const V3(-.5,.73,.18),const V3(.4,.6,.12),c);s.pyramid(const V3(0,1.5,0),.12,.35,const Color(0xFFD87572));}
      if(kind==17){for(final x in [-.35,0.0,.35])crystal(s,V3(x,1.6,0),const Color(0xFFB3F2EC));wings(s,c,y:.9,reach:.85);}
      break;
    case 1: // raccoon
    case 15: // fox
      s.orb(const V3(0,.58,0),const V3(.4,.52,.32),c);
      s.orb(const V3(0,1.23,0),const V3(.42,.35,.33),c);
      for(final x in [-.27,.27])s.pyramid(V3(x,1.47,-.05),.19,.35,c);
      if(kind==1)s.box(const V3(0,1.27,.3),const V3(.7,.16,.06),dark);
      eyes(s,1.27,z:.34);
      s.orb(const V3(0,1.1,.34),const V3(.22,.13,.13),ivory);
      s.orb(const V3(0,1.13,.47),const V3(.065,.05,.045),dark,slices:6,rings:3);
      s.orb(const V3(.48,.6,-.25),const V3(.28,.5,.22),kind==15?ivory:c);
      if(kind==15)for(final x in [-.36,.36])crystal(s,V3(x,.18,.1),ivory,scale:.65);
      break;
    case 2: // pillow dragon
    case 16: // ember drake
      s.orb(const V3(0,.58,0),const V3(.52,.52,.37),c);
      s.orb(const V3(0,1.13,.1),const V3(.4,.35,.32),c);
      s.orb(const V3(0,.99,.34),const V3(.3,.16,.19),ivory);
      eyes(s,1.22,z:.39);
      wings(s,c,y:.82,reach:.9);
      for(final x in [-.24,.24])s.pyramid(V3(x,1.4,0),.12,.25,gold);
      s.orb(const V3(.4,.24,-.36),const V3(.32,.17,.33),c);
      if(kind==2)s.box(const V3(0,.43,.31),const V3(.62,.34,.17),ivory);
      if(kind==16)crystal(s,const V3(.64,.3,-.4),const Color(0xFFFFCD77));
      break;
    case 3:
      s.box(const V3(0,.85,0),const V3(.92,.65,.2),c);
      s.face([const V3(-.46,1.17,.12),const V3(.46,1.17,.12),const V3(0,.77,.14)],ivory);
      eyes(s,.76,z:.16);s.orb(const V3(0,.96,.18),const V3(.09,.09,.03),const Color(0xFFC26E73));break;
    case 4:
    case 9:
      s.orb(const V3(0,.63,0),const V3(.55,.6,.43),c,slices:10,rings:6);
      eyes(s,.76,z:.4);
      s.pyramid(const V3(0,1.13,0),.24,.35,c,sides:6);
      if(kind==4){s.box(const V3(0,1.3,0),const V3(.65,.05,.56),dark);s.box(const V3(.34,1.16,0),const V3(.03,.24,.03),gold);}
      else for(final x in [-.3,.3])s.orb(V3(x,.1,.18),const V3(.24,.1,.22),c);break;
    case 5:
      s.orb(const V3(0,.62,0),const V3(.55,.4,.45),c);
      s.orb(const V3(0,.98,.17),const V3(.28,.26,.25),dark);eyes(s,1.04,z:.4);
      s.box(const V3(0,.73,.42),const V3(.03,.44,.025),ivory);
      for(final x in [-.57,.57])for(final z in [-.24,.1,.32])s.box(V3(x,.34,z),const V3(.3,.07,.07),dark);
      s.pyramid(const V3(0,1.19,.14),.11,.3,gold);break;
    case 6:
      for(final x in [-.25,0.0,.25])for(final y in [.55,.8,1.05])s.orb(V3(x,y,0),const V3(.28,.28,.32),c,slices:8,rings:4);
      s.orb(const V3(0,1.07,.25),const V3(.27,.32,.24),const Color(0xFF8C797C));eyes(s,1.13,z:.46);
      for(final x in [-.34,.34])s.orb(V3(x,1.16,.17),const V3(.15,.2,.14),gold);break;
    case 8:
      s.orb(const V3(0,.68,0),const V3(.47,.61,.32),c);s.orb(const V3(0,1.24,0),const V3(.43,.37,.3),c);
      for(final x in [-.2,.2])s.orb(V3(x,1.27,.27),const V3(.21,.24,.08),ivory);
      eyes(s,1.3,z:.35);s.pyramid(const V3(0,1.04,.33),.1,.15,gold);wings(s,c,y:.7,reach:.7);break;
    case 10:
      s.orb(const V3(0,.84,0),const V3(.28,.48,.25),c);s.orb(const V3(0,1.28,0),const V3(.3,.27,.26),c);
      wings(s,c,y:1,reach:1.02);eyes(s,1.3,z:.25);
      for(final x in [-.2,.2])s.pyramid(V3(x,1.44,0),.13,.29,c);
      s.box(const V3(0,.74,.24),const V3(.24,.24,.15),ivory);break;
    case 11:
      s.box(const V3(0,.55,0),const V3(.82,.55,.53),c);
      s.box(const V3(0,.99,-.1),const V3(.86,.21,.56),gold);
      eyes(s,.72,z:.29);
      for(final x in [-.3,-.1,.1,.3])s.pyramid(V3(x,.82,.3),.07,.13,ivory);
      s.box(const V3(0,.43,.29),const V3(.16,.16,.05),gold);break;
    case 12:
      s.orb(const V3(0,.52,0),const V3(.65,.45,.55),c,slices:8,rings:4);
      s.orb(const V3(0,.51,.54),const V3(.28,.23,.25),ivory);eyes(s,.58,z:.73,gap:.12);
      for(final x in [-.4,.4])for(final z in [-.3,.3])s.box(V3(x,.13,z),const V3(.25,.2,.27),c);
      for(final x in [-.2,.15])crystal(s,V3(x,.98,-.05),const Color(0xFF97C48A),scale:.7);break;
    case 13:
      s.orb(const V3(0,.72,0),const V3(.4,.35,.35),c);eyes(s,.81,z:.32);
      for(final sign in [-1.0,1.0])for(var i=0;i<4;i++){
        final z=-.35+i*.22;
        s.face([V3(sign*.2,.7,z),V3(sign*.85,.45,z),V3(sign*.72,.09,z),V3(sign*.65,.4,z)],gold);
      }s.orb(const V3(0,1.05,0),const V3(.23,.08,.23),ivory);break;
    case 14:
      s.orb(const V3(0,1.1,0),const V3(.52,.35,.4),c,slices:10,rings:4);eyes(s,1.1,z:.37);
      for(var i=0;i<7;i++){final x=(i-3)*.12;s.box(V3(x,.55,.05),V3(.04,.55+(i%2)*.17,.045),i.isEven?c:gold);}
      break;
   }
 }
 static void boss(Scene3D s,int kind){
   final c=[const Color(0xFF6B9F8F),const Color(0xFFBC995D),const Color(0xFF669CA8),const Color(0xFF9F679D),const Color(0xFFA96659),const Color(0xFF8870B8)][kind];
   s.orb(const V3(0,.7,0),const V3(.53,.66,.36),c,slices:10,rings:5);
   s.orb(const V3(0,1.4,0),const V3(.4,.38,.33),c,slices:10,rings:5);
   eyes(s,1.47,z:.32);
   s.box(const V3(0,.81,.35),const V3(.4,.4,.06),dark);
   for(final x in [-.22,.22])s.box(V3(x,.15,.03),const V3(.3,.25,.4),dark);
   for(final x in [-.27,0.0,.27])s.pyramid(V3(x,1.7,.08),.1,.25,gold);
   switch(kind){
    case 0: // academic sovereign
      s.box(const V3(0,1.87,0),const V3(.8,.07,.65),dark);
      for(final x in [-.59,.59]){s.box(V3(x,1,.14),const V3(.31,.45,.14),gold);s.box(V3(x,1,.23),const V3(.25,.35,.035),ivory);}
      s.face([const V3(-.25,1.2,-.2),const V3(.25,1.2,-.2),const V3(.65,.2,-.4),const V3(-.65,.2,-.4)],c);break;
    case 1:
      s.box(const V3(0,1.92,0),const V3(.55,.36,.45),dark);s.box(const V3(0,1.75,0),const V3(.8,.05,.62),gold);
      s.orb(const V3(.65,.6,.05),const V3(.34,.45,.28),gold);
      for(final y in [.6,.8,1.0])s.orb(V3(0,y,.43),const V3(.07,.07,.025),gold);break;
    case 2:
      for(final x in [-.68,.68]){s.box(V3(x,.9,0),const V3(.35,.65,.4),c);crystal(s,V3(x,1.34,0),const Color(0xFF8FF0E1));}
      crystal(s,const V3(0,.85,.43),const Color(0xFF8FF0E1));
      s.box(const V3(.18,1.92,-.1),const V3(.08,.4,.08),gold);break;
    case 3:
      wings(s,const Color(0xFFB980AB),y:1.15,reach:1.08);
      s.face([const V3(-.36,1.37,-.2),const V3(.36,1.37,-.2),const V3(.72,.13,-.45),const V3(-.72,.13,-.45)],const Color(0xFF644067));
      s.orb(const V3(-.16,1.46,.36),const V3(.21,.19,.055),ivory);
      s.box(const V3(.63,.9,.1),const V3(.05,1.2,.05),gold);crystal(s,const V3(.63,1.53,.1),c);break;
    case 4:
      for(final x in [-.5,.5]){s.orb(V3(x,1.13,0),const V3(.3,.23,.3),dark);s.pyramid(V3(x,1.3,0),.12,.3,gold);}
      s.box(const V3(-.65,.78,.25),const V3(.45,.85,.14),c);
      s.box(const V3(.62,.85,.1),const V3(.16,1.25,.07),gold);s.pyramid(const V3(.62,1.48,.1),.13,.28,ivory);break;
    case 5:
      wings(s,const Color(0xFF675385),y:1.2,reach:1.18);
      for(var i=0;i<8;i++){
        final a=i*math.pi/4;crystal(s,V3(math.cos(a)*.93,1.1+math.sin(a)*.84,-.2),i.isEven?gold:const Color(0xFFC2A8F2),scale:.7);
      }
      s.orb(const V3(0,.86,.44),const V3(.18,.2,.09),const Color(0xFFB5F2E9),slices:6,rings:4);break;
   }
 }
}
