import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Small CPU polygon renderer: real XYZ geometry, perspective, lighting and
/// painter depth ordering. It deliberately has no native or WebGL dependency.
class V3 {
  final double x,y,z;
  const V3(this.x,this.y,this.z);
  V3 operator +(V3 b)=>V3(x+b.x,y+b.y,z+b.z);
  V3 operator -(V3 b)=>V3(x-b.x,y-b.y,z-b.z);
  V3 operator *(double n)=>V3(x*n,y*n,z*n);
  double dot(V3 b)=>x*b.x+y*b.y+z*b.z;
  V3 cross(V3 b)=>V3(y*b.z-z*b.y,z*b.x-x*b.z,x*b.y-y*b.x);
  V3 get unit {final n=math.sqrt(dot(this));return n<.00001?const V3(0,0,0):this*(1/n);}
}
class Camera3D {
  final V3 eye,target;
  final double focal;
  const Camera3D({required this.eye,this.target=const V3(0,0,0),this.focal=.95});
  V3 get forward=>(target-eye).unit;
  V3 get right=>forward.cross(const V3(0,1,0)).unit;
  V3 get up=>right.cross(forward).unit;
  double depth(V3 p)=>(p-eye).dot(forward);
  Offset? project(V3 p,Size size) {
    final d=p-eye,z=d.dot(forward);
    if(z<=.1)return null;
    final f=math.min(size.width,size.height)*focal;
    return Offset(size.width/2+d.dot(right)*f/z,size.height/2-d.dot(up)*f/z);
  }
}
class Face3D {
  final List<V3> points;
  final Color color;
  Face3D(this.points,this.color);
  V3 get center=>points.fold(const V3(0,0,0),(V3 a,b)=>a+b)*(1/points.length);
}
class Scene3D {
  final List<Face3D> faces=[];
  void face(List<V3> p,Color color)=>faces.add(Face3D(p,color));
  void box(V3 c,V3 size,Color color) {
    final x=size.x/2,y=size.y/2,z=size.z/2;
    final p=[for(final v in [V3(-x,-y,-z),V3(x,-y,-z),V3(x,y,-z),V3(-x,y,-z),V3(-x,-y,z),V3(x,-y,z),V3(x,y,z),V3(-x,y,z)])c+v];
    for(final q in [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]])face(q.map((i)=>p[i]).toList(),color);
  }
  void pyramid(V3 c,double radius,double height,Color color,{int sides=4}){
    final ring=[for(var i=0;i<sides;i++)c+V3(math.cos(i*math.pi*2/sides)*radius,0,math.sin(i*math.pi*2/sides)*radius)];
    final peak=c+V3(0,height,0);
    for(var i=0;i<sides;i++)face([ring[i],ring[(i+1)%sides],peak],color);
    face(ring.reversed.toList(),color);
  }
  void orb(V3 c,V3 radius,Color color,{int slices=8,int rings=5}){
    V3 point(int a,int b){final lat=-math.pi/2+math.pi*b/rings,lon=math.pi*2*a/slices;return c+V3(radius.x*math.cos(lat)*math.cos(lon),radius.y*math.sin(lat),radius.z*math.cos(lat)*math.sin(lon));}
    for(var b=0;b<rings;b++)for(var a=0;a<slices;a++)face([point(a,b),point(a+1,b),point(a+1,b+1),point(a,b+1)],color);
  }
  /// Board readability policy: labels and terrain can never overpaint the pawn.
  /// Each layer still depth-sorts its own geometry. This is not z-buffering.
  void drawWithForeground(Canvas canvas,Size size,Camera3D camera,Scene3D foreground,
      {void Function()? labels}) {
    draw(canvas,size,camera);
    labels?.call();
    foreground.draw(canvas,size,camera);
  }
  void draw(Canvas canvas,Size size,Camera3D camera) {
    final sorted=List<Face3D>.from(faces)..sort((a,b)=>camera.depth(b.center).compareTo(camera.depth(a.center)));
    final light=const V3(-.4,.9,.5).unit;
    for(final face in sorted){
      final points=face.points.map((p)=>camera.project(p,size)).toList();
      if(points.any((p)=>p==null))continue;
      final normal=(face.points[1]-face.points[0]).cross(face.points[2]-face.points[0]).unit;
      final brightness=.52+.48*normal.dot(light).abs();
      final c=face.color;
      final shade=Color.fromARGB(255,(c.r*255*brightness).round(),(c.g*255*brightness).round(),(c.b*255*brightness).round());
      final path=Path()..moveTo(points.first!.dx,points.first!.dy);
      for(final p in points.skip(1)){path.lineTo(p!.dx,p.dy);}path.close();
      canvas.drawPath(path,Paint()..color=shade..isAntiAlias=true);
      canvas.drawPath(path,Paint()..color=shade..style=PaintingStyle.stroke..strokeWidth=.45);
    }
  }
}
