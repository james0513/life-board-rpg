import 'package:flutter/material.dart';
import '../../domain/models/player.dart';
import '../../domain/services/job_manager.dart';
import '../art/atlas_portrait.dart';

class CareerDialog extends StatefulWidget {
  const CareerDialog({super.key,required this.player,required this.jobs});
  final Player player;
  final JobManager jobs;
  @override
  State<CareerDialog> createState()=>_CareerDialogState();
}
class _CareerDialogState extends State<CareerDialog> {
  bool chosen=false;
  int selectedTier=1;
  @override
  void initState(){super.initState();final tier=widget.jobs.byId(widget.player.jobId).tier;selectedTier=tier<3?tier+1:3;}
  void select(String? id) {
    if(chosen)return;
    setState(()=>chosen=true);
    Navigator.pop(context,id);
  }
  @override
  Widget build(BuildContext context)=>PopScope(canPop:false,child:Dialog(
    backgroundColor:const Color(0xFFFFFAEE),
    child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:800),
      child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('人生職業樹 · 30 職業',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
          Text('目前：${widget.jobs.byId(widget.player.jobId).title}　金錢 \$${widget.player.money}'),
          const Text('需符合前置職業與全部門檻；金錢為資格條件，不會扣款。'),
          const SizedBox(height:12),
          Wrap(spacing:8,children:[for(final t in [1,2,3]) ChoiceChip(label:Text('${['','初階','中階','高階'][t]} · ${widget.jobs.jobs.where((j)=>j.tier==t).length} 種'),selected:selectedTier==t,onSelected:chosen?null:(_)=>setState(()=>selectedTier=t))]),
          const SizedBox(height:12),
          for(final tier in [selectedTier]) ...[
            Text('${['','初階','中階','高階'][tier]} · 打工收入 ×${[1.0,1.1,1.4,1.8][tier]}',
              style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:Color(0xFF675485))),
            for(final job in widget.jobs.jobs.where((j)=>j.tier==tier)) Builder(builder:(_){
              final eligible=widget.jobs.evaluate(widget.player,job.id);
              final current=widget.player.jobId==job.id;
              return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,children:[
                  CareerPortrait(jobId: job.id,gender:widget.player.gender, width: 74, height: 88),
                  Text('${job.title}${current ? " · 目前職業" : ""}',
                    style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
                  Text('前置：${job.fromJobIds.map((id)=>widget.jobs.byId(id).title).join("／")}'),
                  Text('門檻：${job.requirements.isEmpty ? "無屬性限制" : job.requirements.map((r)=>r.label).join("、")}'),
                  Text('技能：${job.skillName} · 消耗 1 SP\n基礎傷害：${job.skillFormula}'),
                  Text('目前預估基礎技能傷害 ${job.skillPower(widget.player)}（另計隨機值與會心）'),
                  if(!eligible.allowed&&!current)Text(eligible.reasons.join('\n'),style:const TextStyle(color:Colors.brown)),
                  const SizedBox(height:8),
                  FilledButton(onPressed:!chosen&&eligible.allowed?()=>select(job.id):null,
                    child:Text(current?'目前職業':eligible.allowed?'轉職為${job.title}':'條件未達成')),
                ])));
            }),
            const SizedBox(height:12),
          ],
          OutlinedButton(onPressed:chosen?null:()=>select(null),child:const Text('維持原職業，返回地圖')),
        ])))));
}
