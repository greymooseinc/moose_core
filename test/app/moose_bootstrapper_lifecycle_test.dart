import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/app.dart';
import 'package:moose_core/plugin.dart';
import 'package:moose_core/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BootstrapRecordingPlugin extends FeaturePlugin {
  _BootstrapRecordingPlugin(this.log, {this.throwOnStart = false});

  final List<String> log;
  final bool throwOnStart;

  @override
  String get name => 'bootstrap_plugin';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    log.add('register');
  }

  @override
  Future<void> onInit() async {
    log.add('init');
  }

  @override
  Future<void> onStart() async {
    log.add('start');
    if (throwOnStart) {
      throw Exception('start failed');
    }
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MooseBootstrapper lifecycle orchestration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('runs registration -> onInit -> onStart', () async {
      final appContext = MooseAppContext();
      final log = <String>[];
      final bootstrapper = MooseBootstrapper(appContext: appContext);

      final report = await bootstrapper.run(
        config: const {},
        plugins: [() => _BootstrapRecordingPlugin(log)],
      );

      expect(log, equals(['register', 'init', 'start']));
      expect(report.failures, isEmpty);
      expect(report.pluginTimings.containsKey('bootstrap_plugin'), isTrue);
      expect(report.pluginStartTimings.containsKey('bootstrap_plugin'), isTrue);
    });

    test('captures start-phase failures under plugin:startAll', () async {
      final appContext = MooseAppContext();
      final bootstrapper = MooseBootstrapper(appContext: appContext);

      final report = await bootstrapper.run(
        config: const {},
        plugins: [
          () => _BootstrapRecordingPlugin(<String>[], throwOnStart: true)
        ],
      );

      expect(report.failures.containsKey('plugin:startAll'), isTrue);
    });
  });

  group('Bootstrap failure handling', () {
    test('config init failure is recorded in BootstrapReport', () async {
      final ctx = MooseAppContext(
        configManager: _ThrowingConfigManager(),
      );
      final report = await MooseBootstrapper(appContext: ctx).run(
        config: {},
        adapters: [],
        plugins: [],
      );
      expect(report.failures, contains('bootstrap:configInit'));
      expect(report.succeeded, isFalse);
    });

    test('page route registration failure is recorded in BootstrapReport', () async {
      final ctx = MooseAppContext(
        configManager: _PagesThrowingConfigManager(),
      );
      final report = await MooseBootstrapper(appContext: ctx).run(
        config: {},
        adapters: [],
        plugins: [],
      );
      expect(report.failures, contains('bootstrap:pagesRoutes'));
    });
  });
}

class _ThrowingConfigManager extends ConfigManager {
  @override
  void initialize(Map<String, dynamic> config) {
    throw StateError('intentional config init failure');
  }
}

class _PagesThrowingConfigManager extends ConfigManager {
  @override
  dynamic get(String key, {dynamic defaultValue}) {
    if (key == 'pages') throw StateError('intentional pages failure');
    return super.get(key, defaultValue: defaultValue);
  }
}
