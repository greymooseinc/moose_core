import 'dart:async';

import 'package:moose_core/repositories.dart';

import 'backend_adapter.dart';

/// Manages repository factory registration and lazy instance caching.
///
/// Extracted from [BackendAdapter] so the adapter stays focused on
/// initialization, configuration validation, and backend-specific setup.
/// [BackendAdapter] delegates all factory/caching operations here.
class RepositoryManager {
  /// Key: repository Type → ordered list of registered entries (last = default).
  final Map<Type, List<_RMEntry>> _repos = {};

  /// Register a synchronous factory for [T].
  void registerFactory<T extends CoreRepository>(
    T Function() factory, {
    required String provider,
  }) {
    _repos.putIfAbsent(T, () => []).add(_RMEntry(provider: provider, factory: factory));
  }

  /// Register an asynchronous factory for [T].
  void registerAsyncFactory<T extends CoreRepository>(
    Future<T> Function() factory, {
    required String provider,
  }) {
    _repos.putIfAbsent(T, () => []).add(_RMEntry(provider: provider, factory: factory));
  }

  /// Retrieve [T] synchronously. Throws [RepositoryAsyncOnlyException] if the
  /// registered factory is async.
  T getSync<T extends CoreRepository>({String? provider}) {
    final entry = _entryFor<T>(provider);
    if (entry.instance is T) return entry.instance as T;
    final factory = entry.factory;
    if (factory is Future<T> Function()) {
      throw RepositoryAsyncOnlyException(
        'Repository $T was registered with an async factory. '
        'Use getRepositoryAsync<$T>() instead of getRepository<$T>().',
      );
    }
    final instance = (factory as T Function())();
    instance.initialize();
    entry.instance = instance;
    return instance;
  }

  /// Retrieve [T] asynchronously. Safe for both sync and async factories.
  ///
  /// Concurrent calls for the same type share a [Completer] so the factory is
  /// only invoked once even under parallel awaits.
  Future<T> getAsync<T extends CoreRepository>({String? provider}) async {
    final entry = _entryFor<T>(provider);
    if (entry.instance is T) return entry.instance as T;
    if (entry.instance is Completer<T>) {
      return (entry.instance as Completer<T>).future;
    }
    final completer = Completer<T>();
    entry.instance = completer;
    try {
      final factory = entry.factory;
      final T instance;
      if (factory is Future<T> Function()) {
        instance = await factory();
      } else {
        instance = (factory as T Function())();
      }
      instance.initialize();
      entry.instance = instance;
      completer.complete(instance);
      return instance;
    } catch (e, stack) {
      entry.instance = null;
      completer.completeError(e, stack);
      rethrow;
    }
  }

  /// Returns `true` if [T] has a registered factory.
  bool hasFactory<T extends CoreRepository>({String? provider}) {
    final entries = _repos[T];
    if (entries == null || entries.isEmpty) return false;
    if (provider != null) return entries.any((e) => e.provider == provider);
    return true;
  }

  /// Returns `true` if the cached instance for [T] is already resolved.
  bool isCached<T extends CoreRepository>({String? provider}) {
    final entries = _repos[T];
    if (entries == null || entries.isEmpty) return false;
    if (provider != null) {
      return entries.any((e) => e.provider == provider && e.instance is T);
    }
    return entries.last.instance is T;
  }

  /// Clear cached instance for [T] (factory registration is kept).
  void clearCache<T extends CoreRepository>({String? provider}) {
    final entries = _repos[T];
    if (entries == null) return;
    if (provider != null) {
      for (final e in entries.where((e) => e.provider == provider)) {
        e.instance = null;
      }
    } else {
      for (final e in entries) {
        e.instance = null;
      }
    }
  }

  /// Clear all cached instances (factories remain registered).
  void clearAllCaches() {
    for (final entries in _repos.values) {
      for (final e in entries) {
        e.instance = null;
      }
    }
  }

  /// Clear all factories and cached instances.
  void reset() => _repos.clear();

  /// All registered repository types (for introspection / debugging).
  List<Type> get registeredTypes => _repos.keys.toList();

  /// Retrieve by runtime [Type] — used by [AdapterRegistry].
  CoreRepository getByType(Type type) {
    final entries = _repos[type];
    if (entries == null || entries.isEmpty) {
      throw RepositoryNotRegisteredException(
        'No factory registered for repository type: $type',
      );
    }
    final entry = entries.last;
    if (entry.instance is CoreRepository) return entry.instance as CoreRepository;
    final factory = entry.factory;
    if (factory is Future Function()) {
      throw RepositoryNotRegisteredException(
        'Repository $type has async factory — use getRepositoryAsync.',
      );
    }
    final instance = (factory as CoreRepository Function())();
    instance.initialize();
    entry.instance = instance;
    return instance;
  }

  _RMEntry _entryFor<T extends CoreRepository>(String? provider) {
    final entries = _repos[T];
    if (entries == null || entries.isEmpty) {
      throw RepositoryNotRegisteredException(
        'No factory registered for repository type: $T',
      );
    }
    if (provider != null) {
      return entries.lastWhere(
        (e) => e.provider == provider,
        orElse: () => throw RepositoryNotRegisteredException(
          'No factory registered for repository type: $T with provider "$provider"',
        ),
      );
    }
    return entries.last;
  }
}

class _RMEntry {
  final String provider;
  final Object factory;
  Object? instance;

  _RMEntry({required this.provider, required this.factory});
}
