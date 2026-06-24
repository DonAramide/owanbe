import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/event_config_api.dart';
import '../organizer/providers/event_config_providers.dart';
final platformEventCategoriesProvider = FutureProvider.autoDispose<List<EventCategoryConfig>>((ref) async {
  try {
    return await ref.read(eventConfigApiProvider).listCategories();
  } catch (_) {
    return EventCategoryConfig.fallbackDefaults;
  }
});

final platformEventTagsProvider = FutureProvider.autoDispose<List<EventTagConfig>>((ref) async {
  try {
    return await ref.read(eventConfigApiProvider).listTags();
  } catch (_) {
    return EventTagConfig.fallbackDefaults;
  }
});

final platformVendorCategoriesProvider = FutureProvider.autoDispose<List<VendorCategoryConfig>>((ref) async {
  try {
    return await ref.read(eventConfigApiProvider).listVendorCategories();
  } catch (_) {
    return VendorCategoryConfig.fallbackDefaults;
  }
});

final platformEventTemplatesProvider = FutureProvider.autoDispose<List<EventTemplateConfig>>((ref) async {
  try {
    return await ref.read(eventConfigApiProvider).listTemplates();
  } catch (_) {
    return const [];
  }
});
