import 'package:perf_engine/perf_engine.dart';

final catalog = PartCatalog.seed();

T part<T extends Part>(String id) {
  final p = catalog.byId(id);
  if (p is! T) throw StateError('No $T with id $id in seed catalog');
  return p;
}

GameProfile game(String id) => kGames.firstWhere((g) => g.id == id);

LlmModel llm(String id) => kLlmModels.firstWhere((m) => m.id == id);

AppProfile app(String id) => kApps.firstWhere((a) => a.id == id);
