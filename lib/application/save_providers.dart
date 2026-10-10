import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/preferences_save_store.dart';
import '../domain/models/acceptance_scenarios.dart';
import '../domain/services/save_repository.dart';
import '../domain/services/save_store.dart';

final saveStoreProvider = Provider<SaveStore>((ref) => PreferencesSaveStore(
  storageKey: acceptanceMode ? acceptanceSaveKey : PreferencesSaveStore.key));
final saveRepositoryProvider = Provider((ref) => SaveRepository(ref.watch(saveStoreProvider)));
