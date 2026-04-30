import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/services.dart';

void main() {
  group('ConfigManager._normalizeArrays()', () {
    test('does not throw when adapters list contains a null entry', () {
      final cm = ConfigManager();
      expect(
        () => cm.initialize({'adapters': [null, {'id': 'woo', 'route': '/'}]}),
        returnsNormally,
      );
    });

    test('does not throw when adapters list contains a string entry', () {
      final cm = ConfigManager();
      expect(
        () => cm.initialize({'adapters': ['bad-entry', {'id': 'woo', 'route': '/'}]}),
        returnsNormally,
      );
    });

    test('skips malformed adapter entry but keeps valid entries', () {
      final cm = ConfigManager();
      cm.initialize({
        'adapters': [
          'not-a-map',
          {'id': 'woo', 'route': '/'}
        ]
      });
      expect(cm.get('adapters:woo'), isNotNull);
    });

    test('does not throw on adapter entry missing id field', () {
      final cm = ConfigManager();
      expect(
        () => cm.initialize({'adapters': [{'route': '/no-id'}]}),
        returnsNormally,
      );
    });
  });

  group('ConfigManager.get() path parsing', () {
    test('adjacent separators do not crash', () {
      final cm = ConfigManager();
      cm.initialize({'a': {'b': 'value'}});
      expect(() => cm.get('a::b'), returnsNormally);
    });

    test('adjacent separators return null rather than unexpected data', () {
      final cm = ConfigManager();
      cm.initialize({'a': {'b': 'value'}});
      expect(cm.get('a::b'), isNull);
    });

    test('normal path a:b returns correct value', () {
      final cm = ConfigManager();
      cm.initialize({'a': {'b': 'hello'}});
      expect(cm.get('a:b'), 'hello');
    });
  });
}
