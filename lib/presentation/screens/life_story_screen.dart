import 'package:flutter/material.dart';

import '../../domain/models/player.dart';
import '../../domain/services/story_service.dart';

/// Story and family decisions are committed by the parent before they appear.
/// Opening this screen, changing panes, and canceling a dialog are read-only.
class LifeStoryScreen extends StatefulWidget {
  final Player player;
  final String Function(String) jobTitle;
  final Future<Player> Function(String action, String? npcId) onRelationship;
  final Future<Player> Function(
    String chainId,
    int expectedStep,
    String optionId,
  )
  onStoryChoice;
  final Future<Player> Function(String endingId) onConclude;

  const LifeStoryScreen({
    super.key,
    required this.player,
    required this.jobTitle,
    required this.onRelationship,
    required this.onStoryChoice,
    required this.onConclude,
  });

  @override
  State<LifeStoryScreen> createState() => _LifeStoryScreenState();
}

enum _StoryPane {
  stories('stories', '故事', Icons.auto_stories_outlined),
  relationships('relationships', '羈絆', Icons.favorite_border),
  household('household', '家計', Icons.cottage_outlined),
  endings('endings', '人生結局', Icons.bookmark_border);

  const _StoryPane(this.id, this.title, this.icon);
  final String id, title;
  final IconData icon;
}

class _LifeStoryScreenState extends State<LifeStoryScreen> {
  static const _service = StoryService();
  static const _ink = Color(0xFF244B43);
  static const _teal = Color(0xFF3D7167);
  static const _paper = Color(0xFFFFFAEF);
  static const _muted = Color(0xFF68756B);
  static const _gold = Color(0xFFB6853B);
  final _scroll = ScrollController();

  late Player _player = widget.player;
  _StoryPane _pane = _StoryPane.stories;
  bool _busy = false;
  bool _confirming = false;
  String? _error;
  String? _notice;
  Future<void> Function()? _retry;

  bool get _locked => _busy || _confirming;
  String _money(int amount) => '\$$amount';

  @override
  void didUpdateWidget(covariant LifeStoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player && !_locked) {
      _player = widget.player;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _npcName(String? id) {
    for (final npc in _service.npcs) {
      if (npc.id == id) return npc.name;
    }
    return '尚未選擇伴侶';
  }

  String _endingTitle(String id) {
    for (final ending in _service.endings) {
      if (ending.id == id) return ending.title;
    }
    return id;
  }

  String get _homeTitle => switch (_player.life.homeLevel) {
    0 => '尚未置產',
    1 => '溫馨小屋',
    _ => '舒適宅邸',
  };

  Future<void> _run(
    Future<Player> Function() save,
    String success, {
    Future<void> Function()? retry,
  }) async {
    if (_locked) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _retry = null;
    });
    try {
      final updated = await save();
      if (!mounted) return;
      setState(() {
        _player = updated;
        _notice = success;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '這次沒有完成，畫面保留原先進度。$error';
        _retry = retry;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_error!)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String description,
    required String confirmLabel,
  }) async {
    if (_locked) return false;
    setState(() => _confirming = true);
    var closing = false;
    void dismiss(BuildContext dialogContext, bool accepted) {
      if (closing) return;
      closing = true;
      Navigator.pop(dialogContext, accepted);
    }

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => PopScope<bool>(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) closing = true;
          },
          child: AlertDialog(
            key: const ValueKey('life-story-confirmation'),
            scrollable: true,
            title: Text(title),
            content: SizedBox(
              width: 400,
              child: Text(description, style: const TextStyle(height: 1.65)),
            ),
            actions: [
              TextButton(
                key: const ValueKey('life-story-cancel'),
                onPressed: () => dismiss(dialogContext, false),
                child: const Text('先等等'),
              ),
              FilledButton(
                key: const ValueKey('life-story-confirm'),
                onPressed: () => dismiss(dialogContext, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ),
      );
      return result == true;
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _relationship(String action, String? npcId) async {
    if (_locked) return;
    final info = _service.relationshipActionInfo(_player, action, npcId: npcId);
    if (!info.enabled) return;
    final chosenName = _npcName(npcId ?? _player.story.partnerId);
    if (const {'commit', 'propose', 'child'}.contains(action)) {
      final consequences = switch (action) {
        'commit' =>
          '將與$chosenName成為本世唯一伴侶。這一世不能更換伴侶，'
              '其他角色仍可作為朋友聊天。',
        'propose' => '將與$chosenName結婚。本世婚姻會保留，不能在此解除。',
        _ =>
          '將與$chosenName共同領養一名孩子。孩子會留在本世家庭中，'
              '每季生活費增加 \$15，最多養育兩名孩子。',
      };
      final accepted = await _confirm(
        title: '${info.label}？',
        description:
            '$consequences\n\n'
            '本次花費 ${_money(info.cost)}，推進 1 季；'
            '另結算行動後的家庭生活費。\n${info.description}\n\n'
            '以上都是遊戲內選擇。轉生會重設伴侶、婚姻、孩子與住宅；'
            '已記錄的人生結局會保留。取消不扣款，也不推進時間。',
        confirmLabel: '確認${info.label}',
      );
      if (!mounted || !accepted) return;
    }
    await _run(
      () => widget.onRelationship(action, npcId),
      '${info.label}已儲存，時間前進一季。',
      retry: () => _relationship(action, npcId),
    );
  }

  Future<void> _choose(StoryChapter chapter, StoryOption option) async {
    if (_locked || !option.enabled) return;
    final completed =
        chapter.step + 1 >=
        _service.storyChains
            .singleWhere((chain) => chain.id == chapter.chainId)
            .chapters
            .length;
    await _run(
      () => widget.onStoryChoice(chapter.chainId, chapter.step, option.id),
      completed
          ? '「${chapter.title}」的選擇已儲存，這段故事已完成。'
          : '「${chapter.title}」的選擇已儲存，下一章已更新。',
      retry: () => _choose(chapter, option),
    );
  }

  Future<void> _conclude(LifeEnding ending) async {
    if (_locked || _player.story.currentEndingId != null) return;
    final accepted = await _confirm(
      title: '記錄「${ending.title}」？',
      description:
          '將保存第 ${_player.life.generation} 世、'
          '${_player.life.age} 歲此刻的職業、資產與心得數。\n\n'
          '每一世只能記錄一次，選定後不能改寫。這是一張人生快照，'
          '不會多花一季、不額外扣款或發放獎勵，仍能繼續遊玩本世。\n\n'
          '想開始下一世時，請回到「人生手帳」確認轉生與傳承。',
      confirmLabel: '確認記錄',
    );
    if (!mounted || !accepted) return;
    await _run(
      () => widget.onConclude(ending.id),
      '「${ending.title}」已留下人生快照。可繼續遊玩，或回人生手帳轉生。',
      retry: () => _conclude(ending),
    );
  }

  void _select(_StoryPane pane) {
    if (_locked || _pane == pane) return;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _pane = pane);
  }

  void _back() {
    if (_locked) return;
    Navigator.pop(context, _player);
  }

  @override
  Widget build(BuildContext context) => PopScope<Player>(
    canPop: !_locked,
    child: Scaffold(
      backgroundColor: const Color(0xFFF1EBDC),
      appBar: AppBar(
        backgroundColor: _paper,
        foregroundColor: _ink,
        title: const Text('人生故事'),
        leading: IconButton(
          key: const ValueKey('life-story-back'),
          tooltip: '返回棋盤',
          onPressed: _locked ? null : _back,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  key: ValueKey('life-story-saving'),
                  strokeWidth: 2,
                  semanticsLabel: '正在儲存，請稍候',
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            62 +
                (MediaQuery.textScalerOf(context).scale(14) - 14)
                    .clamp(0.0, 100.0)
                    .toDouble(),
          ),
          child: SingleChildScrollView(
            key: const ValueKey('life-story-tabs'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                for (final pane in _StoryPane.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey('life-story-tab-${pane.id}'),
                      avatar: Icon(pane.icon, size: 18),
                      label: Text(pane.title),
                      selected: _pane == pane,
                      showCheckmark: false,
                      onSelected: _locked ? null : (_) => _select(pane),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              key: const ValueKey('life-story-scroll'),
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
              children: [
                _hero(),
                const SizedBox(height: 16),
                if (_error != null) _feedback(_error!, isError: true),
                if (_notice != null) _feedback(_notice!, isError: false),
                ...switch (_pane) {
                  _StoryPane.stories => _stories(),
                  _StoryPane.relationships => _relationships(),
                  _StoryPane.household => _household(),
                  _StoryPane.endings => _endings(),
                },
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _hero() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [_ink, _teal]),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '把每一季，寫成自己的故事',
          style: TextStyle(
            color: _paper,
            fontSize: 23,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('第 ${_player.life.generation} 世', style: _heroStyle),
            Text(
              '${_player.life.age} 歲 · ${_player.life.season}季',
              key: const ValueKey('life-story-age'),
              style: _heroStyle,
            ),
            Text(widget.jobTitle(_player.jobId), style: _heroStyle),
            Text(
              _money(_player.money),
              key: const ValueKey('life-story-money'),
              style: _heroStyle,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '故事選擇與互動各花 1 季；每季家庭支出 ${_money(_service.livingCost(_player))}。',
          style: const TextStyle(color: Color(0xFFD4E1D7), height: 1.5),
        ),
      ],
    ),
  );

  static const _heroStyle = TextStyle(
    color: _paper,
    fontWeight: FontWeight.w600,
  );

  Widget _card({required Widget child, Key? key}) => Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE0DDCE)),
    ),
    child: child,
  );

  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: _muted, height: 1.55)),
      ],
    ),
  );

  Widget _feedback(String message, {required bool isError}) => _card(
    key: ValueKey(isError ? 'life-story-error' : 'life-story-notice'),
    child: Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              color: isError ? const Color(0xFF913F2D) : _ink,
              height: 1.5,
            ),
          ),
          if (isError && _retry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('life-story-retry'),
              onPressed: _locked ? null : _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('重試這次行動'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _requirement(String message, {required bool met}) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          met ? Icons.check_circle_outline : Icons.lock_outline,
          size: 17,
          color: met ? _teal : _muted,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: met ? _teal : _muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );

  List<Widget> _stories() {
    final available = _service.availableStories(_player);
    return [
      _heading('三段相遇，九個篇章', '每條故事依序展開。先看條件與花費，選擇儲存成功後才會進入下一章。'),
      for (final chain in _service.storyChains)
        _card(
          key: ValueKey('life-story-chain-${chain.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chain.title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                chain.description,
                style: const TextStyle(color: _muted, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                '已完成 ${_player.story.storySteps[chain.id] ?? 0} / ${chain.chapters.length} 章',
                key: ValueKey('life-story-progress-${chain.id}'),
                style: const TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (final chapter in chain.chapters) _chapterProgress(chapter),
              if ((_player.story.storySteps[chain.id] ?? 0) >=
                  chain.chapters.length)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    '這段故事已寫完，選擇與成長會留在這一世。',
                    style: TextStyle(color: _teal, height: 1.5),
                  ),
                ),
              for (final chapter in available.where(
                (chapter) => chapter.chainId == chain.id,
              )) ...[
                const Divider(height: 30),
                Text(
                  chapter.title,
                  key: ValueKey(
                    'life-story-chapter-${chapter.chainId}-${chapter.step}',
                  ),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  chapter.description,
                  style: const TextStyle(color: _ink, height: 1.6),
                ),
                for (final option in chapter.options)
                  _storyOption(chapter, option),
              ],
            ],
          ),
        ),
    ];
  }

  Widget _chapterProgress(StoryChapter chapter) {
    final step = _player.story.storySteps[chapter.chainId] ?? 0;
    final complete = chapter.step < step;
    final current = chapter.step == step;
    final selectedId = _player.story.storyChoices[chapter.id];
    final chosen = chapter.options.where((option) => option.id == selectedId);
    final detail = complete
        ? chosen.isEmpty
              ? '已完成'
              : '已選擇：${chosen.first.label}'
        : current
        ? '當前篇章 · 年滿 ${chapter.minAge} 歲可展開'
        : '先完成前章 · 年滿 ${chapter.minAge} 歲可展開';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            complete
                ? Icons.check_circle_outline
                : current
                ? Icons.play_circle_outline
                : Icons.lock_outline,
            size: 18,
            color: complete || current ? _teal : _muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 ${chapter.step + 1} 章 · ${chapter.title}',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                Text(
                  detail,
                  key: complete && chosen.isNotEmpty
                      ? ValueKey('life-story-chosen-${chapter.id}')
                      : null,
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
    );
  }

  Widget _storyOption(StoryChapter chapter, StoryOption option) => Container(
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F1E6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          option.label,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          option.description,
          style: const TextStyle(color: _muted, height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          '${_money(option.cost)} · 花費 1 季 · 另計家庭生活費',
          style: const TextStyle(color: _gold, fontSize: 13),
        ),
        _requirement(option.blockedReason ?? '條件已達成，可以選擇', met: option.enabled),
        const SizedBox(height: 10),
        FilledButton(
          key: ValueKey(
            'life-story-choice-${chapter.chainId}-${chapter.step}-${option.id}',
          ),
          onPressed: _locked || !option.enabled
              ? null
              : () => _choose(chapter, option),
          child: Text('選擇：${option.label}'),
        ),
      ],
    ),
  );

  List<Widget> _relationships() => [
    _heading('在四季裡，慢慢靠近', '三位角色均為原創成年人。聊天認識彼此，再依好感與生活條件選擇下一步。'),
    _card(
      key: const ValueKey('life-story-partner'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '目前伴侶：${_npcName(_player.story.partnerId)}',
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _player.story.married
                ? '關係狀態：已婚'
                : _player.story.partnerId == null
                ? '關係狀態：單身'
                : '關係狀態：穩定交往',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 8),
          const Text(
            '本世只能選擇一位伴侶，確認交往後不能更換。轉生會重設本世好感與家庭。',
            style: TextStyle(color: _muted, height: 1.5),
          ),
        ],
      ),
    ),
    for (final npc in _service.npcs) _npcCard(npc),
  ];

  Widget _npcCard(StoryNpc npc) {
    final affinity = _player.story.affinities[npc.id] ?? 0;
    final chosen = _player.story.partnerId == npc.id;
    return _card(
      key: ValueKey('life-story-npc-${npc.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: _teal.withValues(alpha: .12),
                foregroundColor: _teal,
                radius: 24,
                child: Icon(switch (npc.id) {
                  'cen_yu' => Icons.local_florist_outlined,
                  'chu_ye' => Icons.handyman_outlined,
                  _ => Icons.menu_book_outlined,
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      npc.name,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (chosen)
                      Text(
                        _player.story.married ? '你的配偶' : '你的伴侶',
                        style: const TextStyle(
                          color: _teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      npc.description,
                      style: const TextStyle(color: _muted, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '好感 $affinity / 100',
            key: ValueKey('life-story-affinity-${npc.id}'),
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: affinity / 100,
            color: _teal,
            backgroundColor: _teal.withValues(alpha: .12),
            semanticsLabel: '${npc.name}的好感',
            semanticsValue: '$affinity / 100',
          ),
          for (final action in const ['talk', 'date', 'commit', 'propose'])
            _relationshipAction(action, npc.id),
        ],
      ),
    );
  }

  Widget _relationshipAction(String action, String? npcId) {
    final info = _service.relationshipActionInfo(_player, action, npcId: npcId);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.label,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            info.description,
            style: const TextStyle(color: _muted, height: 1.5),
          ),
          const SizedBox(height: 6),
          Text(
            '${_money(info.cost)} · 花費 1 季 · 另計家庭生活費',
            style: const TextStyle(color: _gold, fontSize: 13),
          ),
          _requirement(info.blockedReason ?? '條件已達成，可以行動', met: info.enabled),
          const SizedBox(height: 8),
          FilledButton(
            key: ValueKey('life-story-action-$action-${npcId ?? 'family'}'),
            onPressed: _locked || !info.enabled
                ? null
                : () => _relationship(action, npcId),
            child: Text(info.label),
          ),
        ],
      ),
    );
  }

  List<Widget> _household() => [
    _heading('一起照顧生活', '房子、陪伴與孩子，都是這一世慢慢累積的日常。'),
    _card(
      key: const ValueKey('life-story-household'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _homeTitle,
            style: const TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '住宅等級 ${_player.life.homeLevel} / 2',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 10),
          Text(
            '伴侶：${_npcName(_player.story.partnerId)}',
            style: const TextStyle(color: _ink),
          ),
          const SizedBox(height: 6),
          Text(
            '孩子：${_player.story.children} / 2',
            key: const ValueKey('life-story-children'),
            style: const TextStyle(color: _ink),
          ),
          const SizedBox(height: 12),
          const Text(
            '購屋與升級請回「人生手帳」。這裡會同步顯示同一座家，不會建立第二份房產。',
            style: TextStyle(color: _muted, height: 1.6),
          ),
        ],
      ),
    ),
    _card(
      key: const ValueKey('life-story-finances'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '每季家庭收支',
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '目前現金 ${_money(_player.money)}',
            style: const TextStyle(color: _ink),
          ),
          const SizedBox(height: 8),
          Text(
            '每季生活費 ${_money(_service.livingCost(_player))}',
            key: const ValueKey('life-story-living-cost'),
            style: const TextStyle(color: _gold, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _service.livingCostDescription(_player),
            style: const TextStyle(color: _muted, height: 1.65),
          ),
          const SizedBox(height: 12),
          const Text(
            '棋盤、手帳、故事與家庭行動推進一季後，生活費只結算一次。'
            '開啟頁面、切換分頁、取消確認與記錄結局都不會扣生活費。',
            style: TextStyle(color: _muted, height: 1.65),
          ),
          const SizedBox(height: 8),
          Text(
            '已結算至第 ${_player.story.lastSettledTurn} 季',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    ),
    _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '家庭時光',
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          _relationshipAction('child', null),
          _relationshipAction('familyTime', null),
        ],
      ),
    ),
  ];

  List<Widget> _endings() {
    final eligible = _service
        .eligibleEndings(_player)
        .map((ending) => ending.id)
        .toSet();
    final recorded = _player.story.currentEndingId;
    final canRetire = _player.campaignComplete || _player.life.age >= 60;
    return [
      _heading('為這一世，留一個名字', '完成六章試煉，或年滿 60 歲後，可以依此刻的人生條件記錄結局。每世限一次。'),
      _card(
        key: const ValueKey('life-story-ending-status'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recorded == null ? '本世尚未記錄結局' : '本世已記錄：${_endingTitle(recorded)}',
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '記錄只保存當下快照，不推進季節、不發放額外獎勵，也不結束本世。'
              '之後繼續遊玩不會改寫舊紀錄。',
              style: TextStyle(color: _muted, height: 1.6),
            ),
            _requirement(
              canRetire
                  ? '已符合轉生門檻。要展開下一世，請回「人生手帳」確認。'
                  : '轉生門檻：完成六章試煉，或年滿 60 歲。',
              met: canRetire,
            ),
          ],
        ),
      ),
      for (final ending in _service.endings)
        _card(
          key: ValueKey('life-story-ending-${ending.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ending.title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ending.description,
                style: const TextStyle(color: _muted, height: 1.6),
              ),
              _requirement(
                ending.requirement,
                met: eligible.contains(ending.id),
              ),
              if (!canRetire) _requirement('先完成六章試煉，或年滿 60 歲。', met: false),
              if (recorded != null)
                _requirement('本世已留下快照，不能再次記錄或更換。', met: false),
              const SizedBox(height: 12),
              FilledButton(
                key: ValueKey('life-story-conclude-${ending.id}'),
                onPressed:
                    _locked || recorded != null || !eligible.contains(ending.id)
                    ? null
                    : () => _conclude(ending),
                child: Text(recorded == ending.id ? '本世已記錄' : '記錄這個結局'),
              ),
            ],
          ),
        ),
      _heading('留在書頁裡的人生', '保存最近 30 世的結局快照。這些數字是記錄當下的資料，不會隨目前進度改變。'),
      if (_player.story.history.isEmpty)
        _card(
          child: const Text(
            '還沒有結局紀錄，第一頁正等你慢慢寫下。',
            style: TextStyle(color: _muted, height: 1.6),
          ),
        ),
      for (final record in _player.story.history.reversed)
        _card(
          key: ValueKey('life-story-record-${record.generation}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '第 ${record.generation} 世 · ${_endingTitle(record.id)}',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${record.age} 歲 · ${widget.jobTitle(record.jobId)}',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 6),
              Text(
                '當時資產 ${_money(record.money)} · 學會 ${record.learnedCount} 項心得',
                style: const TextStyle(color: _muted, height: 1.5),
              ),
            ],
          ),
        ),
    ];
  }
}
