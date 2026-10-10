import '../models/player.dart';
import '../models/shop_item.dart';

class ShopService {
  const ShopService();
  Player buy(Player player, String id) {
    final item = shopById(id);
    final lockReason = equipmentLockReason(player, item);
    if (lockReason != null) throw StateError(lockReason);
    if (player.money < item.price) throw StateError('金錢不足');
    final owned = player.inventory[id] ?? 0;
    if (item.isEquipment && owned > 0) throw StateError('已擁有這件裝備');
    if (item.kind == ShopKind.item && owned >= 99)
      throw StateError('道具已達 99 個上限');
    var next = player.apply(item.effects.withMoney(-item.price));
    if (item.kind != ShopKind.training) {
      next = next.copyWith(
        inventory: Map.unmodifiable({...player.inventory, id: owned + 1}),
      );
    }
    return next;
  }

  Player equip(Player player, String id, {EquipmentSlot? slot}) {
    final target =
        slot ?? (id == 'none' ? EquipmentSlot.weapon : shopById(id).slot);
    if (target == null) throw StateError('此物品不可裝備');
    if (id != 'none') {
      final item = shopById(id);
      final lockReason = equipmentLockReason(player, item);
      if (lockReason != null) throw StateError(lockReason);
      if (item.slot != target || (player.inventory[id] ?? 0) < 1)
        throw StateError('裝備欄位不符或尚未持有');
    }
    return switch (target) {
      EquipmentSlot.weapon => player.copyWith(weaponId: id),
      EquipmentSlot.armor => player.copyWith(armorId: id),
      EquipmentSlot.accessory => player.copyWith(accessoryId: id),
    };
  }
}
