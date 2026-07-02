import 'dart:async';

abstract class PlatformModule {
  String get name;
  Future<void> initialize();
  Future<void> shutdown() async {}
  bool checkHealth() => true;
}

class PlatformRegistry {
  PlatformRegistry._();
  static final PlatformRegistry instance = PlatformRegistry._();

  final List<PlatformModule> _modules = [];
  final Map<String, bool> _featureFlags = {};

  void registerModule(PlatformModule module) {
    if (!_modules.any((m) => m.name == module.name)) {
      _modules.add(module);
    }
  }

  Future<void> initializeAll() async {
    for (final module in _modules) {
      try {
        await module.initialize();
      } catch (e) {
        // Log/handle initialization errors in a production logger
        rethrow;
      }
    }
  }

  Future<void> shutdownAll() async {
    for (final module in _modules) {
      await module.shutdown();
    }
  }

  bool isModuleHealthy(String name) {
    final module = _modules.firstWhere((m) => m.name == name, orElse: () => throw StateError('Module not found'));
    return module.checkHealth();
  }

  void setFeatureFlag(String key, bool enabled) {
    _featureFlags[key] = enabled;
  }

  bool isFeatureEnabled(String key) {
    return _featureFlags[key] ?? false;
  }
}
