// Dependency-free v0.28 equipment regression suite. No Flutter invocation.
import 'dart:io';

import '../lib/domain/models/player.dart';
import '../lib/domain/models/shop_item.dart';
import '../lib/domain/services/shop_service.dart';
import '../lib/domain/services/job_manager.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void rejects(void Function() action, String message) {
  try {
    action();
  } on StateError {
    return;
  }
  throw StateError('Expected rejection: $message');
}

Future<void> main() async {
  const service = ShopService();
  final jobs = JobManager(loadJson: (path) => File(path).readAsString());
  await jobs.load();
  check(shopCatalog.length == 52, '31 legacy + 21 new catalog entries');
  check(
    shopCatalog.map((i) => i.id).toSet().length == shopCatalog.length,
    'Unique IDs',
  );
  const oldIds = {
    'train_stamina',
    'train_intelligence',
    'train_charm',
    'train_morality',
    'sword',
    'staff',
    'spellblade',
    'longbow',
    'dawnblade',
    'astral_staff',
    'fate_bow',
    'ember_spear',
    'frost_wand',
    'thunder_hammer',
    'moon_blades',
    'ranger_cloak',
    'scholar_coat',
    'flame_armor',
    'astral_robe',
    'ruby_ring',
    'sapphire_pendant',
    'guardian_brooch',
    'wing_charm',
    'coat',
    'robe',
    'plate',
    'ring',
    'pendant',
    'charm',
    'potion',
    'ether',
  };
  check(
    oldIds.every((id) => shopCatalog.any((i) => i.id == id)),
    'Legacy IDs preserved',
  );
  for (final item in shopCatalog.where((i) => i.isEquipment)) {
    check(
      shopById(item.visualId).slot == item.slot,
      'Valid rendered silhouette: ${item.id}',
    );
    check(
      item.price > 0 && item.unlockStage >= 1 && item.unlockStage <= 6,
      'Valid price/stage',
    );
  }
  for (final family in EquipmentFamily.values) {
    final gear = shopCatalog.where((i) => i.families.contains(family));
    check(
      EquipmentSlot.values.every((s) => gear.any((i) => i.slot == s)),
      '${family.name} all slots',
    );
    check(
      jobs.jobs.any((j) => equipmentFamilies(j.id).contains(family)),
      'Reachable family',
    );
  }
  for (final job in jobs.jobs) {
    if (job.tier >= 2)
      check(equipmentFamilies(job.id).isNotEmpty, '${job.id} specialization');
    var player = Player(jobId: job.id, money: 99999, clearedStages: 5);
    for (final item in shopCatalog.where((i) => i.isEquipment)) {
      if (item.allowsJob(job.id)) {
        player = service.equip(service.buy(player, item.id), item.id);
        check(
          equippedId(player, item.slot!) == item.id,
          '${job.id} allowed ${item.id}',
        );
        rejects(() => service.buy(player, item.id), 'duplicate purchase');
        final off = service.equip(player, 'none', slot: item.slot);
        check(equippedId(off, item.slot!) == 'none', 'unequip');
      } else {
        rejects(
          () => service.buy(player, item.id),
          '${job.id} purchase ${item.id}',
        );
        final forged = player.copyWith(
          inventory: {...player.inventory, item.id: 1},
        );
        rejects(
          () => service.equip(forged, item.id),
          '${job.id} equip ${item.id}',
        );
      }
    }
  }
  const novice = Player(money: 99999);
  for (final id in ['practice_blade', 'travel_vest', 'woven_token']) {
    check(shopById(id).allowsJob('unemployed'), 'Starter universal');
    service.equip(service.buy(novice, id), id);
  }
  const stageLocked = Player(
    jobId: 'warrior',
    money: 99999,
    inventory: {'duelist_sabre': 1},
  );
  rejects(() => service.buy(stageLocked, 'duelist_sabre'), 'stage purchase');
  rejects(() => service.equip(stageLocked, 'duelist_sabre'), 'stage equip');
  final incompatible = novice.copyWith(
    weaponId: 'dawnblade',
    armorId: 'rune_mantle',
    accessoryId: 'sage_sigil',
    inventory: {'dawnblade': 1, 'rune_mantle': 1, 'sage_sigil': 1},
  );
  final sanitized = sanitizeEquipment(incompatible);
  check(
    sanitized.weaponId == 'none' &&
        sanitized.armorId == 'none' &&
        sanitized.accessoryId == 'none',
    'Legacy incompatible gear removed',
  );
  check(sanitized.inventory.length == 3, 'Legacy possessions preserved');
  check(
    equipmentAttack(incompatible) == 0 &&
        equipmentMagic(incompatible) == 0 &&
        finalBossWeaponBonus(incompatible) == 0,
    'No invalid combat bonuses',
  );
  var artist = const Player(
    jobId: 'artist',
    money: 99999,
    stamina: 200,
    intelligence: 200,
    charm: 200,
    morality: 200,
    clearedStages: 5,
  );
  artist = service.equip(service.buy(artist, 'rhythm_blade'), 'rhythm_blade');
  artist = service.equip(service.buy(artist, 'coat'), 'coat');
  final ranger = jobs.changeJob(artist, 'ranger_master');
  check(
    ranger.weaponId == 'none' && ranger.armorId == 'coat',
    'Career transition selectively unequips',
  );
  check(
    ranger.inventory['rhythm_blade'] == 1,
    'Career transition retains purchase',
  );
  check(
    ranger.money == artist.money && ranger.stamina == artist.stamina,
    'No transition charge',
  );
  rejects(
    () => service.equip(ranger, 'coat', slot: EquipmentSlot.weapon),
    'wrong slot',
  );
  rejects(() => service.equip(novice, 'sword'), 'unowned gear');
  rejects(() => service.equip(novice, 'potion'), 'consumable cannot equip');
  check(
    service.buy(novice, 'potion').inventory['potion'] == 3,
    'Consumables unaffected',
  );
  check(
    service.buy(novice, 'train_stamina').stamina == 15,
    'Training unaffected',
  );
  print(
    'PASS: 52 catalog entries; all 31 careers, six families, purchase/equip locks, stage gates, migration, job changes and visual aliases.',
  );
}
