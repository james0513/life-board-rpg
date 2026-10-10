import 'package:flutter/material.dart';
import '../../domain/models/tile_event.dart';
import '../components/tile_component.dart';

class ChoiceEventDialog extends StatefulWidget {
  const ChoiceEventDialog({super.key, required this.event, this.workPercent = 100, this.livingCost = 0});
  final TileEvent event;
  final int workPercent;
  final int livingCost;
  @override
  State<ChoiceEventDialog> createState() => _ChoiceEventDialogState();
}
class _ChoiceEventDialogState extends State<ChoiceEventDialog> {
  bool _selected = false;
  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return PopScope(canPop: false, child: AlertDialog(
      backgroundColor: const Color(0xFFFFFAEE),
      title: Text('${TileComponent.labels[event.kind.index]} · ${event.title}'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 6, color: TileComponent.colors[event.kind.index]),
          const SizedBox(height: 16),
          Text(event.description, style: const TextStyle(fontSize: 17, height: 1.6)),
          if (widget.workPercent != 100) Text('職業收入加成 ×${widget.workPercent / 100}（下方已計入）'),
          const SizedBox(height: 20),
          for (final option in event.options) Padding(padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(onPressed: _selected ? null : () {
              setState(() => _selected = true);
              Navigator.pop(context, option.id);
            }, style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: Align(alignment: Alignment.centerLeft, child: Text(
                '${option.id}　${option.label}\n${option.effects.withMoney(option.effects.money > 0 ? option.effects.money * widget.workPercent ~/ 100 : option.effects.money).summary}${option.battleEnemyId == null ? "" : " · 進入戰鬥"}',
                style: const TextStyle(height: 1.7))))),
          Text('選擇後才結算；負值最多扣至 0。完成後前進一季，另計生活費 ${widget.livingCost}，並依活動調整 EQ 與壓力。工作格可累積職業熟練。', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]))),
    ));
  }
}
