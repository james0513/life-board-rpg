import 'package:flutter/material.dart';

import '../../domain/models/player.dart';
import '../../domain/services/life_service.dart';
import '../../domain/services/story_service.dart';

/// A quiet place to make life choices between trips around the board.
/// All changes go through the application's persisted action callbacks.
class LifeJournalScreen extends StatefulWidget {
  final Player player;
  final String Function(String) jobTitle;
  final Future<Player> Function(String action) onAction;
  final Future<Player> Function(String? skill) onReincarnate;

  const LifeJournalScreen({
    super.key,
    required this.player,
    required this.jobTitle,
    required this.onAction,
    required this.onReincarnate,
  });

  @override
  State<LifeJournalScreen> createState() => _LifeJournalScreenState();
}

class _LifeJournalScreenState extends State<LifeJournalScreen> {
  static const _ink = Color(0xFF244B43);
  static const _teal = Color(0xFF3D7167);
  static const _paper = Color(0xFFFFFAEF);
  static const _muted = Color(0xFF68756B);
  static const _gold = Color(0xFFB6853B);
  static const _seasons = ['春', '夏', '秋', '冬'];
  static const _lifeService = LifeService();

  late Player _player = widget.player;
  bool _busy = false;
  bool _confirming = false;
  String? _error;
  String? _notice;

  bool get _canReincarnate => _lifeService.canReincarnate(_player);

  String get _relationshipTitle => switch (_player.life.affection) {
    < 25 => '相識',
    < 60 => '知己',
    < 100 => '相伴',
    _ => '長久羈絆',
  };

  int get _lifeHpBonus =>
      (_player.life.eq - 50) ~/ 10 -
      _player.life.stress ~/ 10 +
      _player.life.homeLevel * 3;

  String _money(int value) => '\$$value';

  String get _homeTitle => switch (_player.life.homeLevel) {
    0 => '尚未置產',
    1 => '溫馨小屋',
    _ => '舒適宅邸',
  };

  Future<void> _act(String action, String title) async {
    if (_busy || _confirming) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final updated = await widget.onAction(action);
      if (!mounted) return;
      setState(() {
        _player = updated;
        _notice = '$title完成。新的一季，繼續寫下你的人生。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '這次行動未完成：$error');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_error!)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reincarnate() async {
    if (_busy || _confirming || !_canReincarnate) return;
    setState(() => _confirming = true);
    var selected = '';
    var closing = false;
    void dismiss(BuildContext context, _InheritanceChoice? choice) {
      if (closing) return;
      closing = true;
      Navigator.pop(context, choice);
    }
    final skills = _player.life.learnedSkills.toSet().toList();
    final choice = await showDialog<_InheritanceChoice>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => PopScope<_InheritanceChoice>(
          onPopInvokedWithResult: (didPop, result) { if (didPop) closing = true; },
          child: AlertDialog(
          key: const ValueKey('life-reincarnation-dialog'),
          scrollable: true,
          title: const Text('翻開下一段人生？'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('第 ${_player.life.generation + 1} 世，從 18 歲重新出發。'),
                const SizedBox(height: 12),
                const Text(
                  '這會重設本世的金錢、裝備、道具、職業、屬性與棋盤關卡進度，'
                  '也會重設人際關係、房屋、連續故事與職業練習。性別與已記錄的人生結局保留，世代數加一。',
                  style: TextStyle(height: 1.6),
                ),
                const SizedBox(height: 12),
                const Text(
                  '可以選擇一項已學會的職業心得，把它的屬性加成帶進下一世。'
                  '其他已學心得不會保留，也可以不選擇傳承。尚未記錄結局時會先記下目前最優先符合的結局；若想自行選擇，請先到「人生故事」。此操作不能復原。',
                  style: TextStyle(height: 1.6),
                ),
                const SizedBox(height: 20),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '傳承一項職業心得',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const ValueKey('life-inherit-skill'),
                      value: selected,
                      isExpanded: true,
                      isDense: true,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text(
                            '不傳承，重新開始',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final id in skills)
                          DropdownMenuItem(
                            value: id,
                            child: Text(
                              '${widget.jobTitle(id)}心得',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          updateDialog(() => selected = value ?? ''),
                    ),
                  ),
                ),
                if (skills.isEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    '本世尚未學會職業心得，仍然可以開啟下一世。',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
                if (selected.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _lifeService.skillDescription(selected),
                    style: const TextStyle(color: _teal, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('life-reincarnation-cancel'),
              onPressed: () => dismiss(dialogContext, null),
              child: const Text('留在這一世'),
            ),
            FilledButton(
              key: const ValueKey('life-reincarnation-confirm'),
              onPressed: () => dismiss(
                dialogContext,
                _InheritanceChoice(selected.isEmpty ? null : selected),
              ),
              child: const Text('確認轉生'),
            ),
          ],
        )),
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (choice == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final updated = await widget.onReincarnate(choice.skill);
      if (!mounted) return;
      setState(() {
        _player = updated;
        _busy = false;
      });
      // Let PopScope see the completed state before dismissing this route.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '轉生未完成：$error';
        _busy = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_error!)));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_confirming,
    child: Scaffold(
      backgroundColor: const Color(0xFFF1EBDC),
      appBar: AppBar(
        title: const Text('人生手帳'),
        backgroundColor: _paper,
        foregroundColor: _ink,
        leading: IconButton(
          key: const ValueKey('life-journal-back'),
          tooltip: '返回棋盤',
          onPressed: _busy || _confirming ? null : () => Navigator.pop(context, _player),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              key: const ValueKey('life-journal-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
              children: [
                _hero(context),
                const SizedBox(height: 20),
                _wellbeing(context),
                const SizedBox(height: 8),
                const Text('此處好感是整體社交熟悉度；具名伴侶、婚姻及孩子請到「人生故事」查看。',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.5)),
                const SizedBox(height: 12),
                Text(
                  '生活狀態影響戰鬥最大 HP：目前 ${_lifeHpBonus >= 0 ? '+' : ''}$_lifeHpBonus。'
                  'EQ 高於 50 的每 10 點約 +1，低於 50 則相反；'
                  '每 10 點壓力 −1，每級家園 +3。',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 18),
                _goals(),
                const SizedBox(height: 24),
                _sectionTitle(context, '01', '把日子過成喜歡的樣子', '每次行動花一季，四季為一年。'),
                const SizedBox(height: 8),
                Text('${const StoryService().livingCostDescription(_player)}\n下方費用僅為行動費；購屋當季按新家園等級計算生活費。',
                  style: const TextStyle(color: _muted, fontSize: 12, height: 1.6)),
                const SizedBox(height: 12),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(
                      key: ValueKey('life-action-progress'),
                      semanticsLabel: '正在儲存人生進度',
                      color: _teal,
                    ),
                  ),
                if (_error != null) _feedback(_error!, isError: true),
                if (_notice != null) _feedback(_notice!, isError: false),
                _actions(),
                const SizedBox(height: 26),
                _sectionTitle(
                  context,
                  '02',
                  '一路累積的本領',
                  '在同一職業完成 3 次打工，學會專屬心得。',
                ),
                const SizedBox(height: 12),
                _careers(context),
                const SizedBox(height: 26),
                _reincarnationCard(context),
                const SizedBox(height: 20),
                const Text(
                  '原創人生棋盤玩法，以經典人生桌遊類型為靈感，'
                  '融合四季成長、職業心得與轉生傳承。'
                  '每一步選擇，都是屬於你的故事。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, height: 1.6, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _hero(BuildContext context) {
    final life = _player.life;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ink, _teal],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                Icons.auto_stories_outlined,
                color: Color(0xFFE2CFA8),
                size: 20,
              ),
              Text(
                '第 ${life.generation} 世的人生',
                style: const TextStyle(color: Color(0xFFE2CFA8)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_player.displayName}的四季',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: _paper, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            '旅途之外，也為自己留一點時間。',
            style: TextStyle(color: Color(0xFFD4E1D7), height: 1.5),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroTag(Icons.cake_outlined, '${life.age} 歲', 'life-age'),
              _heroTag(
                Icons.eco_outlined,
                '${_seasons[life.turns % 4]}季',
                'life-season',
              ),
              _heroTag(
                Icons.work_outline,
                widget.jobTitle(_player.jobId),
                'life-job',
              ),
              _heroTag(
                Icons.savings_outlined,
                _money(_player.money),
                'life-money',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '已走過 ${life.turns} 季 · 體力 ${_player.stamina} · 智力 ${_player.intelligence}',
            style: const TextStyle(
              color: Color(0xFFD4E1D7),
              height: 1.5,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroTag(IconData icon, String label, String key) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: .16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFFE2CFA8)),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            key: ValueKey(key),
            style: const TextStyle(color: _paper, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _wellbeing(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 700 ? 4 : 2;
      final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _metric(
            width,
            Icons.psychology_outlined,
            '情緒智慧 EQ',
            _player.life.eq,
            _teal,
          ),
          _metric(
            width,
            Icons.air,
            '壓力',
            _player.life.stress,
            const Color(0xFFAD754D),
          ),
          _metric(
            width,
            Icons.favorite_border,
            '關係 · $_relationshipTitle',
            _player.life.affection,
            const Color(0xFFB27577),
          ),
          Container(
            width: width,
            padding: const EdgeInsets.all(15),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cottage_outlined, color: _gold, size: 22),
                const SizedBox(height: 9),
                const Text(
                  '我的家',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  _homeTitle,
                  key: const ValueKey('life-home'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '房屋等級 ${_player.life.homeLevel} / 2',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _metric(
    double width,
    IconData icon,
    String label,
    int value,
    Color color,
  ) => Container(
    width: width,
    padding: const EdgeInsets.all(15),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 9),
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 3),
        Text(
          '$value / 100',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _ink,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 4,
            value: (value / 100).clamp(0.0, 1.0),
            color: color,
            backgroundColor: color.withValues(alpha: .13),
            semanticsLabel: label,
            semanticsValue: '$value / 100',
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(
    BuildContext context,
    String number,
    String title,
    String subtitle,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _teal.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          number,
          style: const TextStyle(color: _teal, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: _ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _goals() {
    final goals = [
      ('學會一項職業心得', _player.life.learnedSkills.isNotEmpty),
      ('擁有自己的家', _player.life.homeLevel > 0),
      ('建立相伴的關係', _player.life.affection >= 60),
      ('完成六章人生試煉', _player.campaignComplete),
    ];
    return Container(
      key: const ValueKey('life-goals'),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '這一世的目標',
            style: TextStyle(
              color: _ink,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < goals.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Semantics(
                label: '${goals[index].$1}，${goals[index].$2 ? '已完成' : '尚未完成'}',
                excludeSemantics: true,
                child: Row(
                  key: ValueKey('life-goal-$index'),
                  children: [
                    Icon(
                      goals[index].$2
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 19,
                      color: goals[index].$2 ? _teal : const Color(0xFFB7BBA7),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        goals[index].$1,
                        style: const TextStyle(color: _ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _feedback(String message, {required bool isError}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      liveRegion: true,
      child: Container(
        key: ValueKey(isError ? 'life-action-error' : 'life-action-notice'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFFE6DE) : const Color(0xFFE1EDE1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 20,
              color: isError ? const Color(0xFF913F2D) : _teal,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? const Color(0xFF913F2D) : _ink,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _actions() {
    final homeMaxed = _player.life.homeLevel >= 2;
    final options = [
      _LifeAction(
        'study',
        '進修學習',
        '讓好奇心帶你向前。',
        _lifeService.actionDescription('study'),
        200,
        Icons.menu_book_outlined,
      ),
      _LifeAction(
        'exercise',
        '運動鍛鍊',
        '為明天累積一點力氣。',
        _lifeService.actionDescription('exercise'),
        100,
        Icons.directions_run,
      ),
      _LifeAction(
        'socialize',
        '相聚交心',
        '把時間留給重要的人。',
        _lifeService.actionDescription('socialize'),
        150,
        Icons.people_outline,
      ),
      _LifeAction(
        'rest',
        '放慢腳步',
        '休息也是人生的一部分。',
        _lifeService.actionDescription('rest'),
        0,
        Icons.spa_outlined,
      ),
      _LifeAction(
        'buyHome',
        homeMaxed
            ? '安居生活'
            : _player.life.homeLevel == 0
            ? '安一個家'
            : '升級家園',
        homeMaxed
            ? '已擁有最高等級的家園。'
            : _player.life.homeLevel == 0
            ? '把漂泊的日子安放下來。'
            : '讓日常多一點從容與舒適。',
        homeMaxed ? '家園已圓滿' : _lifeService.actionDescription('buyHome'),
        _lifeService.homeCost(_player),
        Icons.cottage_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 2 : 1;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in options)
              _actionCard(
                action,
                width,
                maxed: action.id == 'buyHome' && homeMaxed,
              ),
          ],
        );
      },
    );
  }

  Widget _actionCard(_LifeAction action, double width, {required bool maxed}) {
    final affordable = _player.money >= action.cost;
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, color: _teal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            action.effect,
            style: const TextStyle(color: _teal, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            maxed
                ? '房屋等級已達 2 / 2'
                : '${action.cost == 0 ? '免費' : _money(action.cost)} · 花費 1 季',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              key: ValueKey('life-action-${action.id}'),
              onPressed: _busy || _confirming || !affordable || maxed
                  ? null
                  : () => _act(action.id, action.title),
              child: Text(
                maxed
                    ? '已完成家園'
                    : !affordable
                    ? '金錢不足'
                    : action.title,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _careers(BuildContext context) {
    final life = _player.life;
    final learned = life.learnedSkills.toSet();
    final practiced = life.jobPractice.keys.toSet();
    final ids = {...learned, ...practiced}.toList()
      ..sort((a, b) => widget.jobTitle(a).compareTo(widget.jobTitle(b)));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                '已學會 ${learned.length} 項心得',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (life.inheritedSkill != null)
                Text(
                  '傳承：${widget.jobTitle(life.inheritedSkill!)}心得',
                  style: const TextStyle(color: _gold, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '每份職業心得都會給予一次屬性加成；轉生時可以挑選一份傳承。',
            style: TextStyle(color: _muted, height: 1.6, fontSize: 12),
          ),
          if (ids.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 6),
              child: Text(
                '手帳還有很多空白。\n到棋盤上的打工格累積實踐，為目前職業留下心得。',
                style: TextStyle(color: _muted, height: 1.8),
              ),
            ),
          for (final id in ids) ...[
            const SizedBox(height: 16),
            Row(
              key: ValueKey('life-practice-$id'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  learned.contains(id)
                      ? Icons.verified_outlined
                      : Icons.work_history_outlined,
                  color: learned.contains(id) ? _gold : _teal,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.jobTitle(id)}${learned.contains(id) ? '心得 · 已學會' : ' · 練習中'}',
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '已實踐 ${life.jobPractice[id] ?? 0} 次${learned.contains(id) ? '' : ' / 3 次'}',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      if (learned.contains(id)) ...[
                        const SizedBox(height: 4),
                        Text(
                          _lifeService.skillDescription(id),
                          style: const TextStyle(
                            color: _teal,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (!learned.contains(id)) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ((life.jobPractice[id] ?? 0) / 3).clamp(
                              0.0,
                              1.0,
                            ),
                            minHeight: 4,
                            color: _teal,
                            backgroundColor: const Color(0xFFE5E4D5),
                            semanticsLabel: '${widget.jobTitle(id)}職業練習',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _reincarnationCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFFE6E8D8),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFD3D6BE)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.auto_awesome_outlined, color: _gold, size: 26),
        const SizedBox(height: 12),
        Text(
          '下一世，帶著一點光出發',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: _ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          '通關全部六章，或年滿 60 歲，就能轉生。\n挑選一項已學會的職業心得，將它的屬性加成帶進新的人生。',
          style: TextStyle(color: _muted, height: 1.7),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('life-reincarnate'),
          onPressed: _busy || _confirming || !_canReincarnate
              ? null
              : _reincarnate,
          icon: const Icon(Icons.autorenew),
          label: Text(_canReincarnate ? '選擇傳承，開啟下一世' : '繼續書寫這一世'),
        ),
        if (!_canReincarnate) ...[
          const SizedBox(height: 10),
          Text(
            '目前 ${_player.life.age} 歲 · 已完成 ${_player.clearedStages} / 6 章',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ],
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: _paper,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE3D9C4)),
  );
}

class _LifeAction {
  final String id, title, subtitle, effect;
  final int cost;
  final IconData icon;

  const _LifeAction(
    this.id,
    this.title,
    this.subtitle,
    this.effect,
    this.cost,
    this.icon,
  );
}

class _InheritanceChoice {
  final String? skill;

  const _InheritanceChoice(this.skill);
}
