import '../models/life_progress.dart';
import '../models/life_story.dart';
import '../models/player.dart';
import 'life_service.dart';

class StoryNpc {
  final String id, name, description;
  const StoryNpc(this.id, this.name, this.description);
}

class StoryOption {
  final String id, label, description;
  final int cost;
  final bool enabled;
  final String? blockedReason;
  final StatDelta effects;
  final int eq, stress, minEq, minIntelligence, minHome, minLearned;
  final bool requiresMarriage;
  const StoryOption({
    required this.id,
    required this.label,
    required this.description,
    this.cost = 0,
    this.enabled = true,
    this.blockedReason,
    this.effects = const StatDelta(),
    this.eq = 0,
    this.stress = 0,
    this.minEq = 0,
    this.minIntelligence = 0,
    this.minHome = 0,
    this.minLearned = 0,
    this.requiresMarriage = false,
  });

  StoryOption _evaluated(String? reason) => StoryOption(
    id: id,
    label: label,
    description: description,
    cost: cost,
    enabled: reason == null,
    blockedReason: reason,
    effects: effects,
    eq: eq,
    stress: stress,
    minEq: minEq,
    minIntelligence: minIntelligence,
    minHome: minHome,
    minLearned: minLearned,
    requiresMarriage: requiresMarriage,
  );
}

class StoryChapter {
  final String chainId, id, title, description;
  final int step, minAge;
  final List<StoryOption> options;
  const StoryChapter({
    required this.chainId,
    required this.step,
    required this.id,
    required this.title,
    required this.description,
    required this.options,
    this.minAge = 18,
  });

  StoryChapter _evaluated(List<StoryOption> options, {String? context}) =>
      StoryChapter(
        chainId: chainId,
        step: step,
        id: id,
        title: title,
        description: context == null ? description : '$context\n$description',
        minAge: minAge,
        options: List<StoryOption>.unmodifiable(options),
      );
}

class StoryChain {
  final String id, title, description;
  final List<StoryChapter> chapters;
  const StoryChain(this.id, this.title, this.description, this.chapters);
}

class StoryActionInfo {
  final String label, description;
  final int cost;
  final bool enabled;
  final String? blockedReason;
  const StoryActionInfo({
    required this.label,
    required this.description,
    required this.cost,
    required this.enabled,
    this.blockedReason,
  });
}

class LifeEnding {
  final String id, title, description, requirement;
  const LifeEnding(this.id, this.title, this.description, this.requirement);
}

/// Original deterministic stories layered over the existing life/battle rules.
/// Every successful choice or relationship action spends precisely one season.
/// Failed validation never mutates the supplied player or takes a payment.
class StoryService {
  const StoryService();
  static const _life = LifeService();
  static const actions = {
    'talk',
    'date',
    'commit',
    'propose',
    'child',
    'familyTime',
  };

  List<StoryNpc> get npcs => const [
    StoryNpc('cen_yu', '岑雨', '成年修復師。喜歡老書與街角故事，相信耐心能修好許多事。'),
    StoryNpc('chu_ye', '楚野', '成年嚮導。熱愛遠足與料理，總想把旅途的風景帶回家。'),
    StoryNpc('luo_qing', '洛青', '成年舞臺設計師。安靜細心，喜歡一起完成小小的創作。'),
  ];

  List<StoryChain> get storyChains => const [
    StoryChain('lantern', '街角的燈', '從一次伸手幫忙，到替街坊留下長久的光。', [
      StoryChapter(
        chainId: 'lantern',
        step: 0,
        id: 'lantern_0',
        title: '第一盞燈',
        description: '街坊準備夜間小市集，還缺人手與一批燈。你願意怎麼參與？',
        options: [
          StoryOption(
            id: 'a',
            label: '親自幫忙',
            description: '免費 · 道德 +3 · EQ +2 · 壓力 −1',
            effects: StatDelta(morality: 3),
            eq: 2,
            stress: -1,
          ),
          StoryOption(
            id: 'b',
            label: '贊助燈具',
            cost: 200,
            description: '費用 200 · 魅力 +3 · EQ +1',
            effects: StatDelta(charm: 3),
            eq: 1,
          ),
        ],
      ),
      StoryChapter(
        chainId: 'lantern',
        step: 1,
        id: 'lantern_1',
        title: '讓每個人被聽見',
        minAge: 22,
        description: '22 歲起，街坊請你協調攤位爭議。溝通與實作都能讓市集繼續。',
        options: [
          StoryOption(
            id: 'a',
            label: '主持討論',
            cost: 100,
            minEq: 55,
            description: '需要 EQ 55 · 費用 100 · 道德 +4 · EQ +3 · 壓力 +2',
            effects: StatDelta(morality: 4),
            eq: 3,
            stress: 2,
          ),
          StoryOption(
            id: 'b',
            label: '協助重新布置',
            description: '免費 · 體力 +3 · 壓力 +1',
            effects: StatDelta(stamina: 3),
            stress: 1,
          ),
        ],
      ),
      StoryChapter(
        chainId: 'lantern',
        step: 2,
        id: 'lantern_2',
        title: '一條街的記憶',
        minAge: 30,
        description: '30 歲起，第一批燈已經老舊。大家想把這些年的故事留給下一批新鄰居。',
        options: [
          StoryOption(
            id: 'a',
            label: '支持常設展覽',
            cost: 400,
            description: '費用 400 · 道德 +6 · 魅力 +3 · EQ +3',
            effects: StatDelta(morality: 6, charm: 3),
            eq: 3,
          ),
          StoryOption(
            id: 'b',
            label: '整理口述故事',
            description: '免費 · 智力 +3 · 魅力 +3 · EQ +2',
            effects: StatDelta(intelligence: 3, charm: 3),
            eq: 2,
          ),
        ],
      ),
    ]),
    StoryChain('craft', '未完成的圖紙', '用工作、學習與不同選擇，找到自己的創作方式。', [
      StoryChapter(
        chainId: 'craft',
        step: 0,
        id: 'craft_0',
        title: '桌上的空白',
        description: '一間小工坊提供兩種入門機會：先讀懂設計，或先從親手做起。',
        options: [
          StoryOption(
            id: 'a',
            label: '學習設計',
            cost: 150,
            description: '費用 150 · 智力 +4 · 壓力 +2',
            effects: StatDelta(intelligence: 4),
            stress: 2,
          ),
          StoryOption(
            id: 'b',
            label: '接下實作委託',
            description: '免費 · 金錢 +120 · 體力 +3 · 壓力 +3',
            effects: StatDelta(money: 120, stamina: 3),
            stress: 3,
          ),
        ],
      ),
      StoryChapter(
        chainId: 'craft',
        step: 1,
        id: 'craft_1',
        title: '第二次試作',
        minAge: 24,
        description: '24 歲起，工坊邀請你再次合作。學識能改善設計，熟練技能也能幫助新人。',
        options: [
          StoryOption(
            id: 'a',
            label: '改良原型',
            cost: 300,
            minIntelligence: 18,
            description: '需要智力 18 · 費用 300 · 智力 +6 · EQ +2 · 壓力 +3',
            effects: StatDelta(intelligence: 6),
            eq: 2,
            stress: 3,
          ),
          StoryOption(
            id: 'b',
            label: '帶領新學徒',
            minLearned: 1,
            description: '需要 1 項人生技能 · 免費 · 金錢 +150 · 魅力 +4 · 道德 +2',
            effects: StatDelta(money: 150, charm: 4, morality: 2),
          ),
        ],
      ),
      StoryChapter(
        chainId: 'craft',
        step: 2,
        id: 'craft_2',
        title: '自己的簽名',
        minAge: 35,
        description: '35 歲起，你可以策畫一件代表作，也能把經驗整理成人人能用的工作坊。',
        options: [
          StoryOption(
            id: 'a',
            label: '完成跨域代表作',
            cost: 500,
            minLearned: 2,
            description: '需要 2 項人生技能 · 費用 500 · 智力 +6 · 魅力 +4 · EQ +4',
            effects: StatDelta(intelligence: 6, charm: 4),
            eq: 4,
          ),
          StoryOption(
            id: 'b',
            label: '開放經驗工作坊',
            cost: 100,
            description: '費用 100 · 道德 +5 · EQ +5 · 壓力 −4',
            effects: StatDelta(morality: 5),
            eq: 5,
            stress: -4,
          ),
        ],
      ),
    ]),
    StoryChain('roots', '把日子種下', '在陌生城市建立連結，再找到值得珍藏的日常。', [
      StoryChapter(
        chainId: 'roots',
        step: 0,
        id: 'roots_0',
        title: '新鄰居',
        minAge: 22,
        description: '22 歲起，你逐漸熟悉住處附近的小路。有人邀你分享一頓飯。',
        options: [
          StoryOption(
            id: 'a',
            label: '帶菜參加聚餐',
            cost: 80,
            description: '費用 80 · 魅力 +3 · EQ +3 · 壓力 −3',
            effects: StatDelta(charm: 3),
            eq: 3,
            stress: -3,
          ),
          StoryOption(
            id: 'b',
            label: '相約在公園散步',
            description: '免費 · 體力 +2 · EQ +2 · 壓力 −2',
            effects: StatDelta(stamina: 2),
            eq: 2,
            stress: -2,
          ),
        ],
      ),
      StoryChapter(
        chainId: 'roots',
        step: 1,
        id: 'roots_1',
        title: '一個可以回來的地方',
        minAge: 28,
        description: '28 歲起，一位老鄰居需要陪伴。家的意義，也可以是願意空出一段時間。',
        options: [
          StoryOption(
            id: 'a',
            label: '在家招待朋友',
            cost: 150,
            minHome: 1,
            description: '需要 1 級家園 · 費用 150 · 道德 +4 · EQ +4 · 壓力 −3',
            effects: StatDelta(morality: 4),
            eq: 4,
            stress: -3,
          ),
          StoryOption(
            id: 'b',
            label: '一起照顧社區花圃',
            description: '免費 · 道德 +3 · EQ +3 · 壓力 −2',
            effects: StatDelta(morality: 3),
            eq: 3,
            stress: -2,
          ),
        ],
      ),
      StoryChapter(
        chainId: 'roots',
        step: 2,
        id: 'roots_2',
        title: '日常的收藏',
        minAge: 40,
        description: '40 歲起，你整理散落多年的照片。重要的日子不一定轟轟烈烈。',
        options: [
          StoryOption(
            id: 'a',
            label: '與配偶製作相冊',
            cost: 100,
            requiresMarriage: true,
            description: '需要已婚 · 費用 100 · EQ +5 · 壓力 −8',
            eq: 5,
            stress: -8,
          ),
          StoryOption(
            id: 'b',
            label: '寫下自己的旅行記',
            description: '免費 · 智力 +3 · EQ +4 · 壓力 −6',
            effects: StatDelta(intelligence: 3),
            eq: 4,
            stress: -6,
          ),
        ],
      ),
    ]),
  ];

  List<LifeEnding> get endings => const [
    LifeEnding('trials', '越過六座山', '你完成六章試煉，把勇氣留給後來的旅人。', '完成六章試煉'),
    LifeEnding(
      'scholar',
      '不熄的求知心',
      '不同職涯的經驗，成了能照亮新人生的知識。',
      '完成六章或年滿 60 歲，並習得至少 3 項人生技能',
    ),
    LifeEnding(
      'family',
      '有人等你回家',
      '你與家人一起，把普通的四季過成珍貴的回憶。',
      '完成六章或年滿 60 歲，且已婚並育有至少 1 名孩子',
    ),
    LifeEnding(
      'prosperity',
      '安穩而豐盛',
      '你用耐心築起安穩的家，也為未來留下一份餘裕。',
      '完成六章或年滿 60 歲，擁有 2 級家園與至少 5000 金錢',
    ),
    LifeEnding(
      'peaceful',
      '平凡日子的光',
      '走過屬於自己的路，你願意珍惜這一生的每一步。',
      '完成六章試煉或年滿 60 歲',
    ),
  ];

  /// One next chapter per unfinished chain. Locked chapters stay visible with
  /// exact per-option reasons, so the journal also explains future goals.
  List<StoryChapter> availableStories(Player p) =>
      List<StoryChapter>.unmodifiable([
        for (final chain in storyChains)
          if (p.story.storySteps[chain.id]! < chain.chapters.length)
            _chapterFor(p, chain.chapters[p.story.storySteps[chain.id]!]),
      ]);

  StoryChapter _chapterFor(Player p, StoryChapter chapter) {
    String? context;
    if (chapter.step > 0) {
      final previous = storyChains
          .singleWhere((c) => c.id == chapter.chainId)
          .chapters[chapter.step - 1];
      final choice = p.story.storyChoices[previous.id];
      if (choice != null) {
        final label = previous.options.singleWhere((o) => o.id == choice).label;
        context = '前一章選擇：$label。這段經驗成為下一次選擇的起點。';
      }
    }
    return chapter._evaluated([
      for (final option in chapter.options)
        option._evaluated(_optionBlock(p, chapter, option)),
    ], context: context);
  }

  String? _optionBlock(Player p, StoryChapter chapter, StoryOption option) {
    final reasons = <String>[];
    if (p.life.turns >= LifeProgress.maxCounter) reasons.add('回合已達記錄上限');
    if (p.life.age < chapter.minAge) reasons.add('需年滿 ${chapter.minAge} 歲');
    if (p.life.eq < option.minEq) reasons.add('需要 EQ ${option.minEq}');
    if (p.intelligence < option.minIntelligence)
      reasons.add('需要智力 ${option.minIntelligence}');
    if (p.life.homeLevel < option.minHome)
      reasons.add('需要 ${option.minHome} 級家園');
    if (p.life.learnedSkills.length < option.minLearned)
      reasons.add('需要 ${option.minLearned} 項人生技能');
    if (option.requiresMarriage && !p.story.married) reasons.add('需要已婚');
    if (p.money < option.cost) reasons.add('金錢不足，需要 ${option.cost}');
    return reasons.isEmpty ? null : reasons.join('；');
  }

  Player chooseStory(
    Player p,
    String chainId,
    String optionId, {
    required int expectedStep,
  }) {
    if (!LifeStory.chainIds.contains(chainId))
      throw ArgumentError.value(chainId, 'chainId', '未知故事');
    final step = p.story.storySteps[chainId]!;
    if (expectedStep != step) throw StateError('故事已更新，請重新開啟本章');
    if (step >= 3) throw StateError('這條故事已完成');
    final chapter = storyChains
        .singleWhere((c) => c.id == chainId)
        .chapters[step];
    final matches = chapter.options.where((o) => o.id == optionId);
    if (matches.isEmpty)
      throw ArgumentError.value(optionId, 'optionId', '未知故事選項');
    final option = matches.single;
    final reason = _optionBlock(p, chapter, option);
    if (reason != null) throw StateError(reason);
    var next = p.apply(option.effects).apply(StatDelta(money: -option.cost));
    next = next.copyWith(
      story: p.story.copyWith(
        storySteps: {...p.story.storySteps, chainId: step + 1},
        storyChoices: {...p.story.storyChoices, chapter.id: option.id},
      ),
    );
    return settleSeason(_advance(next, eq: option.eq, stress: option.stress));
  }

  StoryActionInfo relationshipActionInfo(
    Player p,
    String action, {
    String? npcId,
  }) {
    if (!actions.contains(action))
      throw ArgumentError.value(action, 'action', '未知關係行動');
    if (npcId != null && !LifeStory.npcIds.contains(npcId))
      throw ArgumentError.value(npcId, 'npcId', '未知成年角色');
    final target = npcId ?? p.story.partnerId;
    final affinity = target == null ? 0 : p.story.affinities[target]!;
    final label = switch (action) {
      'talk' => '聊天',
      'date' => '相約出遊',
      'commit' => '確認伴侶關係',
      'propose' => '求婚成家',
      'child' => '共同養育孩子',
      _ => '家庭時光',
    };
    final cost = switch (action) {
      'date' => 100,
      'propose' => 1200,
      'child' => 800,
      'familyTime' => 40,
      _ => 0,
    };
    final description = switch (action) {
      'talk' => '成年 18+ · 免費 · 指定角色好感 +8 · EQ +1 · 壓力 −2',
      'date' =>
        '成年 18+ · 好感 16+ · 費用 100 · 指定角色好感 +12 · EQ +2 · 壓力 −4；有伴侶後只與伴侶約會',
      'commit' => '年滿 22 歲 · 指定角色好感 40+ · 尚無伴侶 · 免費 · EQ +2 · 壓力 −3',
      'propose' => '已有伴侶 · 伴侶好感 70+ · 至少 1 級家園 · 費用 1200 · EQ +3 · 壓力 −5',
      'child' => '25–55 歲 · 已婚 · 孩子少於 2 名 · 費用 800 · EQ +3 · 壓力 +4；只在你選擇後新增 1 名孩子，每季生活費 +15',
      _ => '已有伴侶 · 費用 40 · 伴侶好感 +6 · EQ +4 · 壓力 −10',
    };
    final reasons = <String>[];
    if (p.life.age < 18) reasons.add('需年滿 18 歲');
    if (p.life.turns >= LifeProgress.maxCounter) reasons.add('回合已達記錄上限');
    if (target == null) reasons.add('請先選擇成年角色');
    switch (action) {
      case 'talk':
        break;
      case 'date':
        if (affinity < 16) reasons.add('好感需達 16');
        if (p.story.partnerId != null && target != p.story.partnerId)
          reasons.add('只能與目前伴侶約會');
      case 'commit':
        if (p.life.age < 22) reasons.add('需年滿 22 歲');
        if (p.story.partnerId != null) reasons.add('已有伴侶');
        if (affinity < 40) reasons.add('好感需達 40');
      case 'propose':
        if (p.story.partnerId == null || target != p.story.partnerId)
          reasons.add('需與目前伴侶進行');
        if (p.story.married) reasons.add('已經結婚');
        if (affinity < 70) reasons.add('伴侶好感需達 70');
        if (p.life.homeLevel < 1) reasons.add('需要至少 1 級家園');
      case 'child':
        if (!p.story.married) reasons.add('需要已婚');
        if (target != p.story.partnerId) reasons.add('需與目前配偶共同決定');
        if (p.life.age < 25 || p.life.age > 55) reasons.add('需在 25–55 歲之間');
        if (p.story.children >= 2) reasons.add('最多養育 2 名孩子');
      case 'familyTime':
        if (p.story.partnerId == null || target != p.story.partnerId)
          reasons.add('需要目前伴侶');
    }
    if (p.money < cost) reasons.add('金錢不足，需要 $cost');
    return StoryActionInfo(
      label: label,
      description: '$description。每次消耗 1 季，另計當季生活費。',
      cost: cost,
      enabled: reasons.isEmpty,
      blockedReason: reasons.isEmpty ? null : reasons.join('；'),
    );
  }

  Player perform(Player p, String action, {String? npcId}) {
    final info = relationshipActionInfo(p, action, npcId: npcId);
    if (!info.enabled) throw StateError(info.blockedReason!);
    final target = (npcId ?? p.story.partnerId)!;
    final increase = switch (action) {
      'talk' => 8,
      'date' => 12,
      'familyTime' => 6,
      _ => 0,
    };
    final eq = switch (action) {
      'talk' => 1,
      'date' || 'commit' => 2,
      'familyTime' => 4,
      _ => 3,
    };
    final stress = switch (action) {
      'talk' => -2,
      'date' => -4,
      'commit' => -3,
      'propose' => -5,
      'child' => 4,
      _ => -10,
    };
    final story = p.story.copyWith(
      affinities: {
        ...p.story.affinities,
        target: _meter(p.story.affinities[target]! + increase),
      },
      partnerId: action == 'commit' ? target : p.story.partnerId,
      married: action == 'propose' ? true : p.story.married,
      children: p.story.children + (action == 'child' ? 1 : 0),
    );
    final next = p
        .apply(StatDelta(money: -info.cost))
        .copyWith(
          story: story,
          life: p.life.copyWith(affection: _meter(p.life.affection + increase)),
        );
    return settleSeason(_advance(next, eq: eq, stress: stress));
  }

  /// Use the existing life service for its single-season/turn-limit rules, then
  /// replace its generic shop meters with the explicitly advertised story ones.
  Player _advance(Player p, {required int eq, required int stress}) {
    final advanced = _life.finishTurn(p, activity: 'shop');
    return advanced.copyWith(
      life: advanced.life.copyWith(
        eq: _meter(p.life.eq + eq),
        stress: _meter(p.life.stress + stress),
      ),
    );
  }

  int livingCost(Player p) => p.life.homeLevel * 10 + p.story.children * 15;
  String livingCostDescription(Player p) =>
      '每季生活費 ${livingCost(p)}：家園 ${p.life.homeLevel} 級 × 10，孩子 ${p.story.children} 名 × 15。'
      '行動費用另外計算；每個付不足的季節壓力 +8，金錢最低為 0。';

  /// Idempotent across repeats and save/load. Migration starts at the existing
  /// turn rather than charging seasons played before this feature existed.
  Player settleSeason(Player p) {
    final elapsed = p.life.turns - p.story.lastSettledTurn;
    if (elapsed < 0) throw StateError('生活費紀錄超前於目前回合');
    if (elapsed == 0) return p;
    final cost = livingCost(p);
    final bill = cost * elapsed;
    final shortfallSeasons = cost == 0
        ? 0
        : (elapsed - p.money ~/ cost).clamp(0, elapsed).toInt();
    return p
        .apply(StatDelta(money: -bill))
        .copyWith(
          life: p.life.copyWith(
            stress: _meter(p.life.stress + shortfallSeasons * 8),
          ),
          story: p.story.copyWith(lastSettledTurn: p.life.turns),
        );
  }

  List<LifeEnding> eligibleEndings(Player p) {
    if (!_life.canReincarnate(p)) return const [];
    return List<LifeEnding>.unmodifiable(
      endings.where(
        (ending) => switch (ending.id) {
          'trials' => p.campaignComplete,
          'scholar' => p.life.learnedSkills.length >= 3,
          'family' => p.story.married && p.story.children > 0,
          'prosperity' => p.life.homeLevel >= 2 && p.money >= 5000,
          _ => true,
        },
      ),
    );
  }

  Player concludeLife(Player p, String endingId) {
    if (!LifeStory.endingIds.contains(endingId))
      throw ArgumentError.value(endingId, 'endingId', '未知人生結局');
    final existing = p.story.history.where(
      (r) => r.generation == p.life.generation,
    );
    if (existing.isNotEmpty) {
      if (existing.single.id != endingId) throw StateError('這一世已留存結局，紀錄不再改寫');
      return p;
    }
    if (!eligibleEndings(p).any((ending) => ending.id == endingId))
      throw StateError('尚未達成人生結局條件');
    final history = [
      ...p.story.history,
      EndingRecord(
        generation: p.life.generation,
        age: p.life.age,
        id: endingId,
        jobId: p.jobId,
        money: p.money,
        learnedCount: p.life.learnedSkills.length,
      ),
    ];
    if (history.length > LifeStory.historyLimit)
      history.removeRange(0, history.length - LifeStory.historyLimit);
    return p.copyWith(
      story: p.story.copyWith(history: history, currentEndingId: endingId),
    );
  }

  Player reincarnate(Player p, {String? inheritSkill}) {
    // Validate first with the existing authoritative skill and reset rules.
    final fresh = _life.reincarnate(p, inheritSkill: inheritSkill);
    final recorded = p.story.currentEndingId == null
        ? concludeLife(p, eligibleEndings(p).first.id)
        : p;
    return fresh.copyWith(
      story: const LifeStory().copyWith(history: recorded.story.history),
    );
  }

  int _meter(int value) => value.clamp(0, 100).toInt();
}
