import 'package:flutter/material.dart';
import 'scene_3d.dart';

/// Occupational props are cosmetic; equipped items alone award gear bonuses.
class CareerDetails {
  static void add(Scene3D s,String job,Color color,{required bool uncovered}) {
    const gold=Color(0xFFECCC88), cream=Color(0xFFF6E7C7), ink=Color(0xFF33435D);
    void badge(Color c){s.orb(const V3(-.18,1.03,.22),const V3(.07,.08,.03),c,slices:6,rings:3);}
    void cape(Color c){
      s.face([const V3(-.25,1.18,-.22),const V3(.25,1.18,-.22),const V3(.48,.25,-.42),const V3(0,.32,-.5),const V3(-.48,.25,-.42)],c);
      s.box(const V3(0,1.13,-.22),const V3(.58,.1,.15),gold);
    }
    void book(Color c){
      s.box(const V3(-.43,.77,.12),const V3(.25,.34,.12),c);
      s.box(const V3(-.43,.77,.19),const V3(.2,.28,.035),cream);
      s.box(const V3(-.43,.77,.22),const V3(.02,.26,.018),gold);
    }
    void glasses(){for(final x in [-.12,.12]){
      s.orb(V3(x,1.53,.33),const V3(.11,.1,.025),gold,slices:8,rings:2);
      s.orb(V3(x,1.53,.356),const V3(.078,.068,.02),ink,slices:8,rings:2);
    } s.box(const V3(0,1.54,.35),const V3(.07,.025,.02),gold);}
    void quiver(){
      s.box(const V3(.23,.95,-.34),const V3(.22,.65,.2),const Color(0xFF865B45));
      for(final x in [.16,.23,.3]){
        s.box(V3(x,1.3,-.34),const V3(.025,.48,.025),cream);
        s.pyramid(V3(x,1.52,-.34),.06,.13,color);
      }
    }
    switch(job){
      case 'student':
        if(uncovered){s.box(const V3(0,1.02,.205),const V3(.08,.25,.03),const Color(0xFFE8AC6C));badge(gold);}
        s.box(const V3(0,.95,-.29),const V3(.42,.42,.18),const Color(0xFF8B6652));
        break;
      case 'part_timer':
        s.box(const V3(0,1.78,.28),const V3(.6,.045,.23),color);
        if(uncovered){s.box(const V3(0,.78,.2),const V3(.38,.48,.045),cream);badge(color);}
        break;
      case 'apprentice':
        s.box(const V3(.2,1.82,0),const V3(.12,.1,.47),gold);
        if(uncovered)for(final x in [-.2,0.0,.2])s.box(V3(x,.56,.25),const V3(.1,.15,.08),const Color(0xFF77563E));
        break;
      case 'adventurer':
        s.box(const V3(0,1.17,.03),const V3(.56,.12,.44),const Color(0xFFDC8057));
        s.box(const V3(-.28,.52,.11),const V3(.22,.3,.19),const Color(0xFF896043));
        break;
      case 'engineer':
        for(final x in [-.16,.16])s.orb(V3(x,1.76,.28),const V3(.12,.1,.055),const Color(0xFF64D8E2),slices:8,rings:3);
        s.box(const V3(0,1.06,-.32),const V3(.46,.48,.23),ink);
        for(final x in [-.14,.14])s.box(V3(x,1.08,-.46),const V3(.06,.3,.04),gold);
        break;
      case 'artist':
        s.orb(const V3(-.45,.87,.15),const V3(.22,.17,.055),cream,slices:8,rings:3);
        for(final pair in <(double,Color)>[(-.56,Colors.pink),(-.43,Colors.teal),(-.32,Colors.amber)])
          s.orb(V3(pair.$1,.9,.21),const V3(.045,.05,.02),pair.$2,slices:6,rings:2);
        break;
      case 'warrior':
        s.box(const V3(0,1.86,-.08),const V3(.12,.2,.38),const Color(0xFFB85C58));
        if(uncovered)badge(gold);
        break;
      case 'scholar': glasses();book(const Color(0xFF795FB1));break;
      case 'doctor':
        s.box(const V3(0,1.81,0),const V3(.55,.13,.46),cream);
        if(uncovered){
          for(final x in [-.15,.15])s.box(V3(x,.99,.21),const V3(.03,.25,.025),ink);
          s.orb(const V3(.15,.83,.22),const V3(.065,.065,.03),gold,slices:8,rings:2);
        }break;
      case 'mage':
        s.orb(const V3(0,1.94,.29),const V3(.09,.12,.07),const Color(0xFF91D9F4),slices:6,rings:3);
        if(uncovered)cape(color);break;
      case 'ranger':quiver();s.pyramid(const V3(-.27,1.83,-.04),.07,.24,cream);break;
      case 'merchant':
        s.orb(const V3(-.36,.55,0),const V3(.16,.21,.14),gold,slices:8,rings:4);
        if(uncovered)for(final y in [.75,.88,1.01])s.orb(V3(.13,y,.21),const V3(.035,.035,.025),gold,slices:6,rings:2);
        break;
      case 'president':
        glasses();if(uncovered){
          s.face([const V3(-.25,1.16,.19),const V3(0,.8,.22),const V3(-.06,1.16,.21)],ink);
          s.face([const V3(.25,1.16,.19),const V3(0,.8,.22),const V3(.06,1.16,.21)],ink);
          s.box(const V3(0,1.02,.25),const V3(.05,.24,.025),gold);
        }break;
      case 'mentor':
        book(const Color(0xFF387B91));if(uncovered)cape(const Color(0xFF655198));
        s.orb(const V3(0,1.87,.14),const V3(.08,.06,.05),gold,slices:6,rings:3);break;
      case 'hero':
        if(uncovered)cape(const Color(0xFFB84D59));
        for(final x in [-.4,.4])s.pyramid(V3(x,1.12,0),.13,.23,gold);break;
      case 'archmage':
        if(uncovered)cape(const Color(0xFF694589));
        for(final x in [-.3,.3])s.orb(V3(x,1.87,0),const V3(.1,.14,.1),const Color(0xFF84E2DF),slices:6,rings:3);
        book(const Color(0xFF9167B9));break;
      case 'paladin':
        s.box(const V3(-.45,.85,.21),const V3(.38,.48,.09),cream);
        s.box(const V3(-.45,.85,.28),const V3(.055,.36,.02),gold);
        s.box(const V3(-.45,.88,.28),const V3(.25,.055,.02),gold);break;
      case 'ranger_master':
        quiver();if(uncovered)cape(const Color(0xFF356F69));
        for(final x in [-.3,.3])s.pyramid(V3(x,1.79,0),.11,.28,gold);break;
      case 'alchemist':
      case 'sage':
        glasses();
        s.box(const V3(-.43,.77,.1),const V3(.045,.35,.045),gold);
        s.orb(const V3(-.43,.61,.12),const V3(.18,.2,.16),const Color(0xFF88D3B7),slices:8,rings:4);
        if(job=='sage'){book(const Color(0xFF506BA1));if(uncovered)cape(color);s.pyramid(const V3(0,1.8,0),.42,.25,color,sides:6);}
        break;
      case 'bard':
      case 'maestro':
        s.orb(const V3(-.42,.72,.19),const V3(.22,.29,.09),gold,slices:8,rings:4);
        s.orb(const V3(-.42,.77,.29),const V3(.1,.15,.035),ink,slices:8,rings:3);
        for(final x in [-.47,-.42,-.37])s.box(V3(x,.85,.33),const V3(.012,.4,.012),cream);
        s.box(const V3(-.42,1.08,.24),const V3(.27,.045,.09),gold);
        if(job=='maestro'){s.box(const V3(0,1.82,0),const V3(.6,.11,.47),ink);if(uncovered)cape(color);}
        break;
      case 'chef':
      case 'gourmet_master':
        for(final x in [-.19,0.0,.19])s.orb(V3(x,1.96,0),const V3(.2,.23,.25),cream,slices:8,rings:4);
        s.box(const V3(0,1.82,0),const V3(.56,.12,.43),cream);
        if(uncovered)s.box(const V3(0,.8,.21),const V3(.42,.48,.035),cream);
        s.orb(const V3(-.43,.86,.16),const V3(.18,.12,.18),job=='chef'?ink:gold,slices:8,rings:3);
        if(job=='gourmet_master')badge(gold);break;
      case 'guardian':
      case 'warlord':
        s.box(const V3(-.46,.77,.22),const V3(.37,.56,.13),color);
        s.box(const V3(-.46,.77,.3),const V3(.065,.42,.03),gold);
        s.box(const V3(0,1.82,0),const V3(.16,.17,.47),gold);
        if(job=='warlord'){for(final x in [-.42,.42])s.pyramid(V3(x,1.13,0),.17,.24,gold);if(uncovered)cape(color);}
        break;
      case 'dancer':
      case 'celestial_dancer':
        s.orb(const V3(-.3,1.7,.04),const V3(.17,.19,.07),color,slices:6,rings:3);
        for(final sign in [-1.0,1.0]){
          s.face([V3(sign*.33,1.08,-.06),V3(sign*.68,.93,-.05),V3(sign*.62,.51,.02),V3(sign*.43,.7,.02)],color);
          s.orb(V3(sign*.44,.64,.15),const V3(.1,.055,.09),gold,slices:8,rings:3);
        }
        if(job=='celestial_dancer')for(final x in [-.2,0.0,.2])s.pyramid(V3(x,1.83,0),.09,.21,gold);
        break;
      case 'beast_tamer':
      case 'dragon_tamer':
        s.box(const V3(0,1.16,0),const V3(.6,.12,.42),cream);
        for(final x in [-.2,.2])s.pyramid(V3(x,1.84,0),.13,.27,color);
        s.orb(const V3(-.4,.88,.12),const V3(.16,.19,.15),color,slices:8,rings:4);
        s.orb(const V3(-.4,1.07,.16),const V3(.14,.12,.11),cream,slices:6,rings:3);
        if(job=='dragon_tamer')for(final sign in [-1.0,1.0])s.face([V3(sign*.25,1.17,-.24),V3(sign*.65,1.35,-.28),V3(sign*.58,.7,-.3)],color);
        break;
      default: break;
    }
  }
}
