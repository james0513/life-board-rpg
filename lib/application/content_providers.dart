import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/asset_json_loader.dart';
import '../domain/services/tile_event_manager.dart';
import '../domain/services/event_manager.dart';
import '../domain/services/job_manager.dart';
import '../domain/services/json_source.dart';

final jsonLoaderProvider = Provider<JsonLoader>((ref) => AssetJsonLoader().load);
final eventManagerProvider = Provider((ref) => EventManager(loadJson: ref.watch(jsonLoaderProvider)));
final jobManagerProvider = Provider((ref) => JobManager(loadJson: ref.watch(jsonLoaderProvider)));
final tileEventManagerProvider = Provider((ref) => TileEventManager(loadJson: ref.watch(jsonLoaderProvider)));
final contentReadyProvider = FutureProvider<void>((ref) async {
  await Future.wait([
    ref.watch(eventManagerProvider).load(),
    ref.watch(jobManagerProvider).load(),
    ref.watch(tileEventManagerProvider).load(),
  ]);
});
