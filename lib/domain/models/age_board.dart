import 'board_tile.dart';

/// Original age-led board layouts. Trial progress never selects a life board.
///
/// Every layout keeps the same 20 positions, including the two shopping streets,
/// so a saved pawn position and the existing movement path remain valid.
class AgeBoard {
  final String id;
  final String title;
  final String description;
  final int minimumAge;
  final int? maximumAge;

  /// Reuses an existing scene and background, in the inclusive range 1–6.
  final int visualStage;
  final List<BoardTile> tiles;

  const AgeBoard._({
    required this.id,
    required this.title,
    required this.description,
    required this.minimumAge,
    required this.maximumAge,
    required this.visualStage,
    required this.tiles,
  });

  String get ageRange =>
      maximumAge == null ? '$minimumAge 歲以上' : '$minimumAge–$maximumAge 歲';

  static List<BoardTile> _layout(List<TileKind> kinds) =>
      List<BoardTile>.unmodifiable([
        for (var index = 0; index < kinds.length; index++)
          BoardTile(index, kinds[index]),
      ]);

  static final AgeBoard _learning = AgeBoard._(
    id: 'learning',
    title: '學習啟程',
    description: '18–21 歲：在學園探索方向，兼顧學習、打工與初次挑戰。',
    minimumAge: 18,
    maximumAge: 21,
    visualStage: 1,
    // Preserve the exact v0.25 board, rather than copying or reordering it.
    tiles: boardTiles,
  );

  static final AgeBoard _career = AgeBoard._(
    id: 'career',
    title: '職涯築夢',
    description: '22–34 歲：工作與命運格增加，把握職涯選擇並累積專業心得。',
    minimumAge: 22,
    maximumAge: 34,
    visualStage: 3,
    // luck 2, penalty 2, work 6, battle 3, career 5, shop 2.
    tiles: _layout(const [
      TileKind.work,
      TileKind.career,
      TileKind.work,
      TileKind.battle,
      TileKind.career,
      TileKind.shop,
      TileKind.penalty,
      TileKind.work,
      TileKind.battle,
      TileKind.career,
      TileKind.luck,
      TileKind.work,
      TileKind.work,
      TileKind.career,
      TileKind.penalty,
      TileKind.shop,
      TileKind.luck,
      TileKind.work,
      TileKind.battle,
      TileKind.career,
    ]),
  );

  static final AgeBoard _family = AgeBoard._(
    id: 'family',
    title: '關係與家園',
    description: '35–49 歲：幸運格增加，在生活機遇與考驗之間經營關係和家園。',
    minimumAge: 35,
    maximumAge: 49,
    visualStage: 2,
    // luck 6, penalty 4, work 2, battle 2, career 4, shop 2.
    tiles: _layout(const [
      TileKind.luck,
      TileKind.penalty,
      TileKind.luck,
      TileKind.battle,
      TileKind.career,
      TileKind.shop,
      TileKind.luck,
      TileKind.work,
      TileKind.penalty,
      TileKind.career,
      TileKind.luck,
      TileKind.penalty,
      TileKind.luck,
      TileKind.battle,
      TileKind.career,
      TileKind.shop,
      TileKind.luck,
      TileKind.work,
      TileKind.penalty,
      TileKind.career,
    ]),
  );

  static final AgeBoard _legacy = AgeBoard._(
    id: 'legacy',
    title: '人生傳承',
    description: '50 歲以上：命運與幸運機會並重，整理本世成果，準備下一世傳承。',
    minimumAge: 50,
    maximumAge: null,
    visualStage: 6,
    // luck 5, penalty 2, work 3, battle 3, career 5, shop 2.
    tiles: _layout(const [
      TileKind.career,
      TileKind.luck,
      TileKind.work,
      TileKind.battle,
      TileKind.career,
      TileKind.shop,
      TileKind.luck,
      TileKind.penalty,
      TileKind.battle,
      TileKind.career,
      TileKind.luck,
      TileKind.work,
      TileKind.luck,
      TileKind.battle,
      TileKind.career,
      TileKind.shop,
      TileKind.penalty,
      TileKind.work,
      TileKind.luck,
      TileKind.career,
    ]),
  );

  static final List<AgeBoard> all = List<AgeBoard>.unmodifiable([
    _learning,
    _career,
    _family,
    _legacy,
  ]);

  /// Ages below the game's starting age use the learning-board fallback.
  /// There is no upper age cap: every age from 50 onward uses the legacy board.
  static AgeBoard forAge(int age) {
    if (age < 22) return _learning;
    if (age < 35) return _career;
    if (age < 50) return _family;
    return _legacy;
  }
}
