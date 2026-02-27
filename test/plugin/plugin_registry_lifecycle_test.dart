import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/app.dart';
import 'package:moose_core/plugin.dart';

class _RecordingPlugin extends FeaturePlugin {
  _RecordingPlugin(this._id, this.log);

  final String _id;
  final List<String> log;

  @override
  String get name => _id;

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    log.add('$_id:register');
  }

  @override
  Future<void> onInit() async {
    log.add('$_id:init');
  }

  @override
  Future<void> onStart() async {
    log.add('$_id:start');
  }

  @override
  Future<void> onStop() async {
    log.add('$_id:stop');
  }

  @override
  Future<void> onAppLifecycle(AppLifecycleState state) async {
    log.add('$_id:lifecycle:$state');
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() => null;
}

void main() {
  group('PluginRegistry lifecycle', () {
    test('init/start run in registration order and stop runs in reverse',
        () async {
      final appContext = MooseAppContext();
      appContext.configManager.initialize({});
      final log = <String>[];
      final a = _RecordingPlugin('a', log);
      final b = _RecordingPlugin('b', log);

      appContext.pluginRegistry.register(a, appContext: appContext);
      appContext.pluginRegistry.register(b, appContext: appContext);

      await appContext.pluginRegistry.initAll();
      await appContext.pluginRegistry.startAll();
      await appContext.pluginRegistry.stopAll();

      expect(
        log,
        equals([
          'a:register',
          'b:register',
          'a:init',
          'b:init',
          'a:start',
          'b:start',
          'b:stop',
          'a:stop',
        ]),
      );
    });

    test('forwards AppLifecycleState to plugins in registration order',
        () async {
      final appContext = MooseAppContext();
      appContext.configManager.initialize({});
      final log = <String>[];
      final a = _RecordingPlugin('a', log);
      final b = _RecordingPlugin('b', log);

      appContext.pluginRegistry.register(a, appContext: appContext);
      appContext.pluginRegistry.register(b, appContext: appContext);

      await appContext.pluginRegistry
          .notifyAppLifecycle(AppLifecycleState.paused);

      expect(
        log,
        equals([
          'a:register',
          'b:register',
          'a:lifecycle:AppLifecycleState.paused',
          'b:lifecycle:AppLifecycleState.paused',
        ]),
      );
    });
  });
}
