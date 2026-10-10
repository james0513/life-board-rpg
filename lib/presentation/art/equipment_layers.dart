import 'dart:math' as math;
import 'dart:ui';
import '../../domain/models/player.dart';
import 'appearance.dart';

/// Visual state only; gameplay bonuses remain in the domain equipment model.
class EquipmentLook {
  final String weapon, armor, accessory, jobId;
  final CharacterGender gender;
  const EquipmentLook({this.jobId='unemployed',this.gender=CharacterGender.male,this.weapon='none',this.armor='none',this.accessory='none'});
  factory EquipmentLook.fromPlayer(Player p)=>EquipmentLook(jobId:p.jobId,gender:p.gender,weapon:p.weaponId,armor:p.armorId,accessory:p.accessoryId);
  EquipmentLook withCharacter(String id,CharacterGender sex)=>EquipmentLook(jobId:id,gender:sex,weapon:weapon,armor:armor,accessory:accessory);
  bool get isEmpty=>weapon=='none' && armor=='none' && accessory=='none';
  @override
  bool operator ==(Object other)=>other is EquipmentLook && jobId==other.jobId && gender==other.gender && weapon==other.weapon && armor==other.armor && accessory==other.accessory;
  @override
  int get hashCode=>Object.hash(jobId,gender,weapon,armor,accessory);
}

/// Normalized, layered paper-doll artwork. Same renderer in Flame and Flutter.
/// Base atlas, armor, weapon, hand, accessory. Coordinates are relative to a cell.
class EquipmentLayers {
  static const weapons={'sword','staff','spellblade','longbow','dawnblade','astral_staff','fate_bow','ember_spear','frost_wand','thunder_hammer','moon_blades'};
  static const armors={'coat','robe','plate','ranger_cloak','scholar_coat','flame_armor','astral_robe'};
  static const accessories={'ring','pendant','charm','ruby_ring','sapphire_pendant','guardian_brooch','wing_charm'};
  static void paint(Canvas canvas,Rect bounds,EquipmentLook look,{int frame=0}) {
    if(look.isEmpty)return;
    canvas.save();canvas.translate(bounds.left,bounds.top);
    canvas.scale(bounds.width/100,bounds.height/100);
    final rig=EquipmentRig.forLook(look,frame);
    canvas.save();canvas.translate(rig.bodyX-50,0);
    if(look.armor!='none')_armor(canvas,look.armor);
    if(look.accessory!='ring')_accessory(canvas,look.accessory);
    canvas.restore();
    canvas.save();canvas.translate(rig.hand.dx-72,rig.hand.dy-62);
    if(look.weapon!='none')_weapon(canvas,look.weapon);
    if(look.accessory=='ring')_accessory(canvas,look.accessory);
    canvas.restore();
    canvas.restore();
  }
  static void _shape(Canvas c,Path path,Color color,{double stroke=1.1}) {
    c.drawPath(path,Paint()..shader=Gradient.linear(const Offset(35,43),const Offset(66,82),
      [color,Color.lerp(color,const Color(0xFF231F29),.3)!]));
    c.drawPath(path,Paint()..color=const Color(0xFF4B3730)..style=PaintingStyle.stroke..strokeWidth=stroke..strokeJoin=StrokeJoin.round);
  }
  static void _line(Canvas c,Offset a,Offset b,Color color,double width){
    c.drawLine(a,b,Paint()..color=color..strokeWidth=width..strokeCap=StrokeCap.round);
  }
  static Path _torso()=>Path()..moveTo(40,43)..quadraticBezierTo(50,48,59,43)
    ..lineTo(64,51)..lineTo(60,64)..lineTo(62,73)..quadraticBezierTo(50,77,37,73)
    ..lineTo(40,62)..lineTo(36,51)..close();
  static void _armor(Canvas c,String id) {
    if(!armors.contains(id))return;
    const extra={'ranger_cloak':Color(0xFF417D69),'scholar_coat':Color(0xFF446C92),'flame_armor':Color(0xFFB85648),'astral_robe':Color(0xFF765AAA)};
    if(extra.containsKey(id)){
      _shape(c,_torso(),extra[id]!);
      _line(c,const Offset(42,46),const Offset(42,72),const Color(0xFFEACC85),2);
      _star(c,const Offset(52,59),5,extra[id]!.withValues(red:.9));
      return;
    }
    const gold=Color(0xFFECCF84);
    if(id=='robe') {
      final skirt=Path()..moveTo(39,58)..lineTo(61,58)..quadraticBezierTo(65,76,70,87)
        ..quadraticBezierTo(51,96,30,87)..quadraticBezierTo(36,75,39,58)..close();
      _shape(c,skirt,const Color(0xFF3F4F9C));
      _shape(c,_torso(),const Color(0xFF5266B5));
      _line(c,const Offset(43,44),const Offset(51,63),gold,1.5);
      _line(c,const Offset(57,44),const Offset(51,63),gold,1.5);
      _line(c,const Offset(51,64),const Offset(51,90),gold,1.3);
      for(final pos in [const Offset(39,79),const Offset(59,83),const Offset(48,53)])_star(c,pos,2.3,gold);
    } else if(id=='coat') {
      _shape(c,_torso(),const Color(0xFFA87141));
      final collar=Path()..moveTo(40,43)..lineTo(48,49)..lineTo(43,57)..lineTo(37,49)..close();
      _shape(c,collar,const Color(0xFFEBD1A2));
      final other=Path()..moveTo(59,43)..lineTo(50,49)..lineTo(54,57)..lineTo(63,49)..close();
      _shape(c,other,const Color(0xFFEBD1A2));
      _line(c,const Offset(42,57),const Offset(58,66),const Color(0xFF573C2A),3);
      for(var y=59.0;y<69;y+=4)c.drawCircle(Offset(49,y),.9,Paint()..color=gold);
    } else {
      _shape(c,_torso(),const Color(0xFFC5D1DC));
      for(final x in [34.0,59.0]) {
        final shoulder=Path()..moveTo(x,45)..quadraticBezierTo(x+6,40,x+12,47)
          ..lineTo(x+10,54)..lineTo(x,52)..close();
        _shape(c,shoulder,const Color(0xFFDDE5EF));
        _line(c,Offset(x+1,49),Offset(x+10,50),gold,1.6);
      }
      final breast=Path()..moveTo(42,49)..lineTo(58,49)..lineTo(56,63)..lineTo(50,68)..lineTo(43,63)..close();
      _shape(c,breast,const Color(0xFF7596B7));
      _star(c,const Offset(50,57),4,gold);
      for(var y=68.0;y<76;y+=3)_line(c,Offset(39,y),Offset(61,y),const Color(0xFF728395),1.6);
    }
    _line(c,const Offset(39,69),const Offset(61,69),const Color(0xFF51392D),3.2);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(48,67,5,4),const Radius.circular(.7)),Paint()..color=gold);
  }
  static void _weapon(Canvas c,String id) {
    if(!weapons.contains(id))return;
    const newColors={'ember_spear':Color(0xFFFFAC6B),'frost_wand':Color(0xFF9DEBFF),'thunder_hammer':Color(0xFF7C88B6),'moon_blades':Color(0xFFF0D6F7)};
    if(newColors.containsKey(id)){
      _line(c,const Offset(72,75),const Offset(72,24),const Color(0xFF8A6D52),3);
      _star(c,const Offset(72,25),id=='thunder_hammer'?9:6,newColors[id]!);
      return;
    }
    final legendary=['dawnblade','astral_staff','fate_bow'].contains(id);
    if(legendary){
      _star(c,const Offset(72,36),7,const Color(0xFFFFD974));
      id=switch(id){'dawnblade'=>'sword','astral_staff'=>'staff',_=>'longbow'};
    }
    c.save();c.translate(72,62);c.rotate(.12);
    if(id=='longbow')c.scale(.65,.9);
    const gold=Color(0xFFE6BA61),edge=Color(0xFF4B3730);
    if(id=='staff') {
      _line(c,const Offset(0,17),const Offset(0,-32),edge,4.2);
      _line(c,const Offset(0,16),const Offset(0,-32),gold,2.4);
      final crystal=Path()..moveTo(0,-48)..lineTo(6,-38)..lineTo(0,-29)..lineTo(-6,-38)..close();
      _shape(c,crystal,const Color(0xFF67DCED));
      _line(c,const Offset(0,-45),const Offset(0,-32),const Color(0xFFDFFFFF),1.2);
      c.drawOval(const Rect.fromLTWH(-8,-39,16,13),Paint()..color=gold..style=PaintingStyle.stroke..strokeWidth=1.4);
    } else if(id=='longbow') {
      final bow=Path()..moveTo(-2,-29)..cubicTo(19,-24,19,18,-2,24);
      c.drawPath(bow,Paint()..color=edge..style=PaintingStyle.stroke..strokeWidth=5..strokeCap=StrokeCap.round);
      c.drawPath(bow,Paint()..color=const Color(0xFF5FA77D)..style=PaintingStyle.stroke..strokeWidth=3);
      _line(c,const Offset(-2,-29),const Offset(-2,24),const Color(0xFFF1E5C5),.8);
      _line(c,const Offset(-10,-2),const Offset(23,-2),gold,1.3);
      _shape(c,Path()..moveTo(26,-2)..lineTo(20,-5)..lineTo(20,1)..close(),const Color(0xFFE6F2F5));
    } else {
      final magic=id=='spellblade';
      final blade=Path()..moveTo(0,-43)..lineTo(5,-33)..lineTo(4,-8)..lineTo(-4,-8)..lineTo(-5,-33)..close();
      _shape(c,blade,magic?const Color(0xFFAD95E4):const Color(0xFFD8E5EA));
      _line(c,const Offset(0,-39),const Offset(0,-10),const Color(0xFFF4FBFF),1);
      if(magic)for(var y=-29.0;y<-10;y+=6)_star(c,Offset(0,y),1.7,const Color(0xFF75F3E5));
      _line(c,const Offset(-8,-7),const Offset(8,-7),edge,4);
      _line(c,const Offset(-8,-7),const Offset(8,-7),gold,2.2);
      _line(c,const Offset(0,-5),const Offset(0,10),edge,4);
      _line(c,const Offset(0,-5),const Offset(0,10),const Color(0xFF9C6144),2);
      c.drawCircle(const Offset(0,11),2.2,Paint()..color=gold);
    }
    // Forward glove holds the newly drawn equipment, hiding the grip seam.
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-3,-2,6,5),const Radius.circular(2)),Paint()..color=const Color(0xFFE8B58E));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-3,-2,6,5),const Radius.circular(2)),Paint()..color=edge..style=PaintingStyle.stroke..strokeWidth=.7);
    c.restore();
  }
  static void _accessory(Canvas c,String id) {
    const extra={'ruby_ring':Color(0xFFE96D7B),'sapphire_pendant':Color(0xFF75BCF5),'guardian_brooch':Color(0xFF70DBB7),'wing_charm':Color(0xFFBA9DF0)};
    if(extra.containsKey(id)){
      _star(c,id=='ruby_ring'?const Offset(72,61):const Offset(49,56),4,extra[id]!);return;
    }
    const gold=Color(0xFFFFD56E);
    if(id=='pendant') {
      final chain=Path()..moveTo(42,44)..quadraticBezierTo(46,58,51,59)..quadraticBezierTo(57,54,58,44);
      c.drawPath(chain,Paint()..color=const Color(0xFF745025)..strokeWidth=2.5..style=PaintingStyle.stroke);
      c.drawPath(chain,Paint()..color=gold..strokeWidth=1.3..style=PaintingStyle.stroke);
      _shape(c,Path()..moveTo(51,57)..lineTo(55,62)..lineTo(51,67)..lineTo(47,62)..close(),const Color(0xFFDF6966));
    } else if(id=='ring') {
      c.drawOval(const Rect.fromLTWH(69,60,6,4),Paint()..color=const Color(0xFF775629)..style=PaintingStyle.stroke..strokeWidth=2);
      c.drawOval(const Rect.fromLTWH(69,60,6,4),Paint()..color=gold..style=PaintingStyle.stroke..strokeWidth=1.2);
      _shape(c,Path()..moveTo(72,57)..lineTo(74,59)..lineTo(72,61)..lineTo(70,59)..close(),const Color(0xFF86DAF1),stroke:.6);
    } else if(id=='charm') {
      _shape(c,Path()..moveTo(39,52)..lineTo(45,52)..lineTo(44,64)..lineTo(42,62)..lineTo(39,64)..close(),const Color(0xFF3D9173));
      c.drawCircle(const Offset(42,54),4,Paint()..color=const Color(0xFF826032));
      _star(c,const Offset(42,54),3.5,gold);
    }
  }
  static void _star(Canvas c,Offset center,double radius,Color color) {
    final path=Path();
    for(var i=0;i<10;i++) {
      final a=-math.pi/2+i*math.pi/5,r=i.isEven?radius:radius*.45;
      final x=center.dx+math.cos(a)*r,y=center.dy+math.sin(a)*r;
      if(i==0){path.moveTo(x,y);}else{path.lineTo(x,y);}
    }
    path.close();c.drawPath(path,Paint()..color=color);
  }
}

/// Hand calibration for each row-major career and its two base walk frames.
class EquipmentRig {
  final double bodyX;
  final Offset hand;
  const EquipmentRig(this.bodyX,this.hand);
  static EquipmentRig forLook(EquipmentLook look,int frame) {
    final extra=CareerAppearance.isExtra(look.jobId);
    final ids=extra?CareerAppearance.extraJobs:CareerAppearance.baseJobs;
    final index=ids.indexOf(look.jobId);
    if(index<0)return const EquipmentRig(50,Offset(72,62));
    final female=look.gender==CharacterGender.female;
    const baseMaleX=[50.0,48.0,51.0,52.0,50.0,48.0,49.0,52.0,51.0,58.0];
    const baseFemaleX=[58.0,56.0,52.0,52.0,53.0,56.0,52.0,52.0,52.0,59.0];
    const extraMaleX=[56.0,54.0,51.0,55.0,55.0,50.0,55.0,56.0,58.0];
    const extraFemaleX=[66.0,59.0,52.0,65.0,60.0,54.0,65.0,58.0,58.0];
    const baseMale=[Offset(72,57),Offset(72,58),Offset(74,58),Offset(75,59),Offset(79,57),Offset(78,58),Offset(77,54),Offset(74,59),Offset(82,56),Offset(86,59)];
    const baseMaleWalk=[Offset(74,59),Offset(71,57),Offset(74,57),Offset(75,60),Offset(79,56),Offset(77,57),Offset(77,55),Offset(74,58),Offset(82,59),Offset(86,57)];
    const baseFemale=[Offset(82,59),Offset(69,59),Offset(70,58),Offset(71,57),Offset(74,58),Offset(82,66),Offset(77,65),Offset(74,65),Offset(75,63),Offset(82,66)];
    const baseFemaleWalk=[Offset(82,60),Offset(69,60),Offset(70,59),Offset(71,58),Offset(74,59),Offset(84,64),Offset(77,61),Offset(74,64),Offset(75,61),Offset(82,65)];
    const extraMale=[Offset(73,59),Offset(72,65),Offset(65,59),Offset(77,56),Offset(74,63),Offset(67,60),Offset(81,51),Offset(76,56),Offset(74,53)];
    const extraMaleWalk=[Offset(69,66),Offset(71,68),Offset(60,56),Offset(74,62),Offset(74,62),Offset(67,62),Offset(73,59),Offset(76,54),Offset(74,55)];
    const extraFemale=[Offset(85,64),Offset(71,65),Offset(58,64),Offset(86,61),Offset(73,60),Offset(64,59),Offset(86,58),Offset(74,57),Offset(64,58)];
    const extraFemaleWalk=[Offset(81,65),Offset(70,65),Offset(57,65),Offset(85,61),Offset(73,62),Offset(64,60),Offset(83,59),Offset(74,56),Offset(64,57)];
    final walk=frame%2==1;
    final xs=extra?(female?extraFemaleX:extraMaleX):(female?baseFemaleX:baseMaleX);
    final hands=extra?(female?(walk?extraFemaleWalk:extraFemale):(walk?extraMaleWalk:extraMale))
      :(female?(walk?baseFemaleWalk:baseFemale):(walk?baseMaleWalk:baseMale));
    return EquipmentRig(xs[index],hands[index]);
  }
}
