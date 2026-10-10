import 'package:flutter/material.dart';

/// Board-only help. Opening this dialog never creates or advances a battle.
class CardBattleTutorialDialog extends StatelessWidget {
  const CardBattleTutorialDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('戰鬥卡牌教學'),
    content: const SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('進入戰鬥即開始；右上角可隨時暫停。'),
          SizedBox(height: 16),
          Text('一般交鋒', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('雙方行動條各自蓄力。選好同系武器，可再搭魔法牌；蓄滿就能出牌。'),
          SizedBox(height: 16),
          Text('終章試煉', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('終章採輪流出牌：你出牌後，魔王再行動。沒有倒數壓力。'),
          SizedBox(height: 16),
          Text('牌面攻防相加；防禦抵擋下一擊後消耗。出牌自動補牌。\n動畫與暫停不計時；切離視窗會自動暫停，回來後手動繼續。'),
          SizedBox(height: 16),
          Text(
            '依一代公開畫面與玩家資料重建結構；卡牌、公式與秒數為本作調整。',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        autofocus: true,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('返回棋盤'),
      ),
    ],
  );
}
