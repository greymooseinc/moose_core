import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moose_core/cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PersistentCache', () {
    // =========================================================================
    // init / lazy init
    // =========================================================================

    group('init', () {
      test('init() can be called multiple times without error', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.init(); // second call is a no-op
        expect(await cache.getString('x'), isNull);
      });

      test('get() throws StateError when called before init()', () {
        final cache = PersistentCache();
        expect(() => cache.get<String>('key'), throwsA(isA<StateError>()));
      });

      test('async methods auto-initialise without explicit init()', () async {
        final cache = PersistentCache();
        // No explicit init() call — getString should still work.
        expect(await cache.getString('missing'), isNull);
      });
    });

    // =========================================================================
    // getString / setString
    // =========================================================================

    group('getString / setString', () {
      test('returns null for missing key', () async {
        final cache = PersistentCache();
        await cache.init();
        expect(await cache.getString('missing'), isNull);
      });

      test('round-trip stores and retrieves a string', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setString('key', 'value');
        expect(await cache.getString('key'), equals('value'));
      });

      test('second write overwrites first (key collision)', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setString('key', 'first');
        await cache.setString('key', 'second');
        expect(await cache.getString('key'), equals('second'));
      });
    });

    // =========================================================================
    // getInt / setInt
    // =========================================================================

    group('getInt / setInt', () {
      test('returns null for missing key', () async {
        final cache = PersistentCache();
        await cache.init();
        expect(await cache.getInt('missing'), isNull);
      });

      test('round-trip stores and retrieves an int', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setInt('count', 42);
        expect(await cache.getInt('count'), equals(42));
      });
    });

    // =========================================================================
    // getDouble / setDouble
    // =========================================================================

    group('getDouble / setDouble', () {
      test('returns null for missing key', () async {
        final cache = PersistentCache();
        await cache.init();
        expect(await cache.getDouble('missing'), isNull);
      });

      test('round-trip stores and retrieves a double', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setDouble('pi', 3.14);
        expect(await cache.getDouble('pi'), closeTo(3.14, 0.0001));
      });
    });

    // =========================================================================
    // getBool / setBool
    // =========================================================================

    group('getBool / setBool', () {
      test('returns null for missing key', () async {
        final cache = PersistentCache();
        await cache.init();
        expect(await cache.getBool('missing'), isNull);
      });

      test('round-trip stores and retrieves true', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setBool('flag', true);
        expect(await cache.getBool('flag'), isTrue);
      });

      test('round-trip stores and retrieves false', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setBool('flag', false);
        expect(await cache.getBool('flag'), isFalse);
      });
    });

    // =========================================================================
    // getStringList / setStringList
    // =========================================================================

    group('getStringList / setStringList', () {
      test('returns null for missing key', () async {
        final cache = PersistentCache();
        await cache.init();
        expect(await cache.getStringList('missing'), isNull);
      });

      test('round-trip stores and retrieves a list of strings', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setStringList('tags', ['a', 'b', 'c']);
        expect(await cache.getStringList('tags'), equals(['a', 'b', 'c']));
      });
    });

    // =========================================================================
    // setJson / getJson
    // =========================================================================

    group('setJson / getJson', () {
      test('returns null for missing key', () async {
        final cache = PersistentCache();
        await cache.init();
        expect(await cache.getJson<Map<String, dynamic>>('missing'), isNull);
      });

      test('round-trip with a Map', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setJson('data', {'id': 1, 'name': 'test'});
        final result = await cache.getJson<Map<String, dynamic>>('data');
        expect(result, equals({'id': 1, 'name': 'test'}));
      });

      test('round-trip with a List', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setJson('list', [1, 2, 3]);
        final result = await cache.getJson<List<dynamic>>('list');
        expect(result, equals([1, 2, 3]));
      });

      test('returns null for malformed JSON without throwing', () async {
        SharedPreferences.setMockInitialValues({'bad_key': 'not json {'});
        final cache = PersistentCache();
        await cache.init();
        expect(
          await cache.getJson<Map<String, dynamic>>('bad_key'),
          isNull,
        );
      });

      test('returns null when stored type does not match requested type T', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setJson('data', {'key': 'value'});
        // Stored a Map but requesting a List — should return null gracefully.
        expect(await cache.getJson<List<dynamic>>('data'), isNull);
      });

      test('setJson returns false for non-encodable value', () async {
        final cache = PersistentCache();
        await cache.init();
        // Functions are not JSON-encodable.
        final result = await cache.setJson('fn', () => 'bad');
        expect(result, isFalse);
      });
    });

    // =========================================================================
    // set (polymorphic)
    // =========================================================================

    group('set (polymorphic)', () {
      test('set stores a String and get<String> retrieves it', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.set('k', 'hello');
        expect(cache.get<String>('k'), equals('hello'));
      });

      test('set stores an int and get<int> retrieves it', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.set('k', 7);
        expect(cache.get<int>('k'), equals(7));
      });

      test('set stores a bool and get<bool> retrieves it', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.set('k', true);
        expect(cache.get<bool>('k'), isTrue);
      });

      test('set stores a List<String> and get<List<String>> retrieves it', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.set('k', <String>['x', 'y']);
        expect(cache.get<List<String>>('k'), equals(['x', 'y']));
      });

      test('set encodes a Map as JSON and getString retrieves the JSON string', () async {
        final cache = PersistentCache();
        await cache.init();
        final result = await cache.set('k', {'a': 1});
        expect(result, isTrue);
        // The value is stored as a JSON string.
        final raw = await cache.getString('k');
        expect(raw, isNotNull);
        expect(raw, contains('"a"'));
      });
    });

    // =========================================================================
    // remove
    // =========================================================================

    group('remove', () {
      test('deletes an existing key', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setString('key', 'value');
        await cache.remove('key');
        expect(await cache.getString('key'), isNull);
      });

      test('removing a non-existent key does not throw', () async {
        final cache = PersistentCache();
        await cache.init();
        expect(() async => cache.remove('nonexistent'), returnsNormally);
      });
    });

    // =========================================================================
    // has
    // =========================================================================

    group('has', () {
      test('returns true for an existing key', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setString('k', 'v');
        expect(await cache.has('k'), isTrue);
      });

      test('returns false for a missing key', () async {
        final cache = PersistentCache();
        await cache.init();
        expect(await cache.has('missing'), isFalse);
      });

      test('returns false after key is removed', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setString('k', 'v');
        await cache.remove('k');
        expect(await cache.has('k'), isFalse);
      });
    });

    // =========================================================================
    // clear
    // =========================================================================

    group('clear', () {
      test('removes all keys', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setString('a', '1');
        await cache.setString('b', '2');
        await cache.clear();
        expect(await cache.getString('a'), isNull);
        expect(await cache.getString('b'), isNull);
      });
    });

    // =========================================================================
    // keys
    // =========================================================================

    group('keys', () {
      test('returns empty list when nothing has been stored', () async {
        final cache = PersistentCache();
        await cache.init();
        expect(await cache.keys, isEmpty);
      });

      test('contains stored keys', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setString('alpha', 'a');
        await cache.setString('beta', 'b');
        final keys = await cache.keys;
        expect(keys, containsAll(['alpha', 'beta']));
      });
    });

    // =========================================================================
    // getOrDefault
    // =========================================================================

    group('getOrDefault', () {
      test('returns stored value when key exists', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setString('k', 'stored');
        expect(await cache.getOrDefault<String>('k', 'default'), equals('stored'));
      });

      test('returns default value when key is missing', () async {
        final cache = PersistentCache();
        await cache.init();
        expect(
          await cache.getOrDefault<String>('missing', 'fallback'),
          equals('fallback'),
        );
      });
    });

    // =========================================================================
    // setAll / removeAll
    // =========================================================================

    group('setAll / removeAll', () {
      test('setAll stores multiple values at once', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setAll({'x': 'one', 'y': 'two'});
        expect(await cache.getString('x'), equals('one'));
        expect(await cache.getString('y'), equals('two'));
      });

      test('removeAll removes multiple keys at once', () async {
        final cache = PersistentCache();
        await cache.init();
        await cache.setAll({'a': 'v1', 'b': 'v2', 'c': 'v3'});
        await cache.removeAll(['a', 'b']);
        expect(await cache.getString('a'), isNull);
        expect(await cache.getString('b'), isNull);
        expect(await cache.getString('c'), equals('v3'));
      });
    });

    // =========================================================================
    // Instance isolation
    // =========================================================================

    group('Instance isolation', () {
      test('two PersistentCache instances share the same SharedPreferences store', () async {
        // SharedPreferences is a singleton under the hood; both instances will
        // see the same data.
        final c1 = PersistentCache();
        final c2 = PersistentCache();
        await c1.init();
        await c2.init();

        await c1.setString('shared', 'from_c1');
        expect(await c2.getString('shared'), equals('from_c1'));
      });

      test('two PersistentCache instances are distinct objects', () {
        final c1 = PersistentCache();
        final c2 = PersistentCache();
        expect(identical(c1, c2), isFalse);
      });
    });
  });
}
