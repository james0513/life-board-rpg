import 'package:flutter/material.dart';
import '../../domain/services/story_service.dart';

class StoryChoiceDialog extends StatefulWidget {
  final StoryChapter chapter;
  const StoryChoiceDialog({super.key, required this.chapter});
  @override
  State<StoryChoiceDialog> createState() => _StoryChoiceDialogState();
}

class _StoryChoiceDialogState extends State<StoryChoiceDialog> {
  bool _selected = false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: Text('連續故事 ${widget.chapter.step + 1}/3 · ${widget.chapter.title}'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.chapter.description, style: const TextStyle(height: 1.6)),
          const SizedBox(height: 16),
          for (final option in widget.chapter.options) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(
              onPressed: _selected || !option.enabled ? null : () {
                setState(() => _selected = true);
                Navigator.pop(context, option.id);
              },
              child: Padding(padding: const EdgeInsets.all(12), child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${option.label}\n${option.description}\n費用 ${option.cost}${option.enabled ? "" : "\n${option.blockedReason}"}'),
              )),
            ),
          ),
          const Text('選擇會留下故事進度，完成後前進一季並結算家計。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ))),
    ),
  );
}
