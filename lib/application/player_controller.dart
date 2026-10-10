import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/player.dart';

final playerProvider = NotifierProvider<PlayerController, Player>(PlayerController.new);
class PlayerController extends Notifier<Player> {
  @override
  Player build() => const Player();
  void moveTo(int index) => state = state.copyWith(position: index);
  void apply(StatDelta delta) => state = state.apply(delta);
  void replace(Player updated) => state = updated;
}
