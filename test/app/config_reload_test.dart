import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MooseBootstrapper config initialization', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('flat config key is accessible after bootstrap', () async {
      final ctx = MooseAppContext();
      await MooseBootstrapper(appContext: ctx).run(
        config: {'theme': 'light'},
        adapters: [],
        plugins: [],
      );
      expect(ctx.configManager.get('theme'), equals('light'));
    });

    test('nested config key is accessible after bootstrap', () async {
      final ctx = MooseAppContext();
      await MooseBootstrapper(appContext: ctx).run(
        config: {
          'app': {'version': '2.0.0'},
        },
        adapters: [],
        plugins: [],
      );
      expect(ctx.configManager.get('app:version'), equals('2.0.0'));
      expect(ctx.configManager.get('app.version'), equals('2.0.0'));
    });

    test('config key absent from bootstrap returns null', () async {
      final ctx = MooseAppContext();
      await MooseBootstrapper(appContext: ctx).run(
        config: {'theme': 'dark'},
        adapters: [],
        plugins: [],
      );
      expect(ctx.configManager.get('missing_key'), isNull);
    });

    test('config defaultValue is returned when key is absent', () async {
      final ctx = MooseAppContext();
      await MooseBootstrapper(appContext: ctx).run(
        config: {},
        adapters: [],
        plugins: [],
      );
      expect(
        ctx.configManager.get('missing_key', defaultValue: 42),
        equals(42),
      );
    });

    test('two MooseAppContext instances have independent registries', () {
      final ctx1 = MooseAppContext();
      final ctx2 = MooseAppContext();
      expect(ctx1.widgetRegistry, isNot(same(ctx2.widgetRegistry)));
      expect(ctx1.configManager, isNot(same(ctx2.configManager)));
      expect(ctx1.hookRegistry, isNot(same(ctx2.hookRegistry)));
    });

    test('reloadConfig is a no-op when no handler is registered', () async {
      final ctx = MooseAppContext();
      await MooseBootstrapper(appContext: ctx).run(
        config: {'env': 'staging'},
        adapters: [],
        plugins: [],
      );
      // No _reloadHandler set — should complete without throwing
      await expectLater(
        ctx.reloadConfig({'env': 'production'}),
        completes,
      );
      // Config is unchanged because no handler was present to swap it
      expect(ctx.configManager.get('env'), equals('staging'));
    });
  });
}
