import 'package:flutter/material.dart';

const creatorName='TSENGSHOUHSIEN';
const gameCopyright='© 2026 TSENGSHOUHSIEN. All rights reserved.';
class CreatorCredit extends StatelessWidget {
 const CreatorCredit({super.key});
 @override Widget build(BuildContext context)=>Material(
   color:const Color(0xFFF7F0E5),
   child:SafeArea(top:false,child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
     child:Text('遊戲創作者 $creatorName\n$gameCopyright',textAlign:TextAlign.center,
       style:const TextStyle(fontSize:10,height:1.4,color:Color(0xFF665A4D))))),
 );
}
