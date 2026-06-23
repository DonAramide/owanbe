import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/event_config_api.dart';
import '../../../core/api/persistence_providers.dart';

final eventConfigApiProvider = Provider<EventConfigApi>((ref) => EventConfigApi(http.Client()));

final eventCategoriesProvider = FutureProvider.autoDispose<List<EventCategoryConfig>>((ref) async {
  try {
    return await ref.read(eventConfigApiProvider).listCategories();
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
    return EventCategoryConfig.fallbackDefaults;
  }
});

final eventTagsProvider = FutureProvider.autoDispose<List<EventTagConfig>>((ref) async {
  try {
    return await ref.read(eventConfigApiProvider).listTags();
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
    return EventTagConfig.fallbackDefaults;
  }
});

final eventTemplatesProvider = FutureProvider.autoDispose<List<EventTemplateConfig>>((ref) async {
  try {
    return await ref.read(eventConfigApiProvider).listTemplates();
  } catch (_) {
    if (!allowMockPersistenceFallback()) rethrow;
    return const [];
  }
});
