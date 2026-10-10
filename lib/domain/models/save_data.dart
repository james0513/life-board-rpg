import 'dart:convert';

import 'board_tile.dart';
import 'json_checks.dart';
import 'life_progress.dart';
import 'life_story.dart';
import 'player.dart';
import 'shop_item.dart';

class SaveData {
  final Player player;
  final DateTime savedAt;
  const SaveData(this.player, this.savedAt);

  String encode() => jsonEncode({
    'schemaVersion': 9,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'player': {
      'life': player.life.toJson(),
      'story': player.story.toJson(),
      'clearedStages': player.clearedStages,
      'stageWins': player.stageWins,
      'stageTurns': player.stageTurns,
      'turnsPerStage': player.turnsPerStage,
      'position': player.position,
      'stamina': player.stamina,
      'intelligence': player.intelligence,
      'charm': player.charm,
      'money': player.money,
      'jobId': player.jobId,
      'experience': player.experience,
      'morality': player.morality,
      'armorId': player.armorId,
      'accessoryId': player.accessoryId,
      'gender': player.gender.name,
      'weaponId': player.weaponId,
      'inventory': player.inventory,
    },
  });

  factory SaveData.decode(String raw, Set<String> validJobIds) {
    final root = jsonObject(jsonDecode(raw), 'save');
    checkKeys(root, {'schemaVersion', 'savedAt', 'player'}, 'save');
    final version = jsonInt(root['schemaVersion'], 'schemaVersion');
    if (version < 1 || version > 9) {
      throw const FormatException('不支援的存檔版本，原存檔已保留');
    }
    final p = jsonObject(root['player'], 'player');
    checkKeys(p, {
      'position',
      'stamina',
      'intelligence',
      'charm',
      'money',
      'jobId',
      if (version >= 2) 'experience',
      if (version >= 3) 'morality',
      if (version >= 4) ...['gender', 'weaponId', 'inventory'],
      if (version >= 5) ...['clearedStages', 'stageWins'],
      if (version >= 6) ...['armorId', 'accessoryId'],
      if (version >= 7) 'life',
      if (version >= 8) 'story',
      if (version >= 9) ...['stageTurns', 'turnsPerStage'],
    }, 'player');
    int nonnegative(String key) {
      final value = jsonInt(p[key], key);
      if (value < 0) throw FormatException('$key 不可為負數');
      return value;
    }

    final cleared = version >= 5 ? nonnegative('clearedStages') : 0;
    final wins = version >= 5 ? nonnegative('stageWins') : 0;
    if (cleared > 6 || wins > 3 || (cleared == 6 && wins != 0))
      throw const FormatException('關卡進度無效');
    final turnsPerStage = version >= 9 ? nonnegative('turnsPerStage') : 8;
    final stageTurns = version >= 9
        ? nonnegative('stageTurns')
        : (cleared < 6 && wins == 3 ? 8 : 0);
    if (![4, 8, 12].contains(turnsPerStage) ||
        stageTurns > turnsPerStage ||
        (cleared == 6 && stageTurns != 0)) {
      throw const FormatException('地圖回合設定或進度無效');
    }
    var gender = CharacterGender.male;
    var weapon = 'none';
    Map<String, int> inventory = const {'potion': 2, 'ether': 1};
    if (version >= 4) {
      final g = jsonText(p['gender'], 'gender');
      if (!CharacterGender.values.any((v) => v.name == g))
        throw const FormatException('未知角色性別');
      gender = CharacterGender.values.byName(g);
      weapon = jsonText(p['weaponId'], 'weaponId');
      final bag = jsonObject(p['inventory'], 'inventory');
      final parsed = <String, int>{};
      for (final entry in bag.entries) {
        final matches = shopCatalog.where(
          (s) => s.id == entry.key && s.kind != ShopKind.training,
        );
        if (matches.isEmpty) throw const FormatException('未知背包物品');
        final count = jsonInt(entry.value, 'inventory count');
        if (count < 0 || count > (matches.single.isEquipment ? 1 : 99))
          throw const FormatException('無效物品數量');
        parsed[entry.key] = count;
      }
      inventory = Map.unmodifiable(parsed);
      if (weapon != 'none' &&
          (!shopCatalog.any(
                (s) => s.id == weapon && s.kind == ShopKind.weapon,
              ) ||
              (inventory[weapon] ?? 0) != 1)) {
        throw const FormatException('裝備未持有');
      }
    }
    String loadSlot(String key, ShopKind kind) {
      if (version < 6) return 'none';
      final id = jsonText(p[key], key);
      if (id != 'none' &&
          (!shopCatalog.any((s) => s.id == id && s.kind == kind) ||
              (inventory[id] ?? 0) != 1)) {
        throw FormatException('$key 裝備欄位或持有數量錯誤');
      }
      return id;
    }

    final armor = loadSlot('armorId', ShopKind.armor),
        accessory = loadSlot('accessoryId', ShopKind.accessory);
    final position = nonnegative('position');
    if (position >= boardTiles.length) throw const FormatException('存檔位置超出棋盤');
    final oldJobId = jsonText(p['jobId'], 'jobId');
    const legacyJobs = {
      'junior_engineer': 'engineer',
      'senior_engineer': 'mentor',
      'police_trainee': 'warrior',
      'police_officer': 'hero',
      'entrepreneur': 'president',
    };
    final jobId = version < 3 ? (legacyJobs[oldJobId] ?? oldJobId) : oldJobId;
    if (!validJobIds.contains(jobId)) throw const FormatException('存檔職業不存在');
    final date = DateTime.tryParse(jsonText(root['savedAt'], 'savedAt'));
    if (date == null) throw const FormatException('存檔時間格式錯誤');
    final life = version >= 7
        ? LifeProgress.fromJson(
            jsonObject(p['life'], 'player.life'),
            validJobIds,
          )
        : const LifeProgress();
    final story = version >= 8
        ? LifeStory.fromJson(
            jsonObject(p['story'], 'player.story'),
            validJobIds,
            life: life,
          )
        : LifeStory(lastSettledTurn: life.turns);
    return SaveData(
      sanitizeEquipment(
        Player(
          story: story,
          life: life,
          armorId: armor,
          accessoryId: accessory,
          clearedStages: cleared,
          stageWins: wins,
          stageTurns: stageTurns,
          turnsPerStage: turnsPerStage,
          gender: gender,
          weaponId: weapon,
          inventory: inventory,
          position: position,
          stamina: nonnegative('stamina'),
          intelligence: nonnegative('intelligence'),
          charm: nonnegative('charm'),
          money: nonnegative('money'),
          morality: version < 3 ? 10 : nonnegative('morality'),
          jobId: jobId,
          experience: version == 1 ? 0 : nonnegative('experience'),
        ),
      ),
      date,
    );
  }
}

/// Retain the exact pre-upgrade bytes; never serialize a migrated replacement.
String? legacySnapshotForV28Backup(String? raw) {
  if (raw == null) return null;
  try {
    final value = jsonDecode(raw);
    if (value is Map && value['schemaVersion'] is int &&
        value['schemaVersion'] >= 1 && value['schemaVersion'] <= 8) return raw;
  } on FormatException {
    return null;
  }
  return null;
}
