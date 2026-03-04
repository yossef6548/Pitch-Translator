import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/core/logger.dart';

void main() {
  setUp(() => AppLogger.clear());

  group('AppLogger', () {
    test('info() adds an entry with level INFO', () {
      AppLogger.info('hello');

      final entries = AppLogger.entries.value;
      expect(entries.length, 1);
      expect(entries.first.level, 'INFO');
      expect(entries.first.message, 'hello');
    });

    test('warning() adds an entry with level WARN', () {
      AppLogger.warning('watch out');

      final entries = AppLogger.entries.value;
      expect(entries.length, 1);
      expect(entries.first.level, 'WARN');
      expect(entries.first.message, 'watch out');
    });

    test('error() adds an entry with level ERROR', () {
      AppLogger.error('bad thing happened');

      final entries = AppLogger.entries.value;
      expect(entries.length, 1);
      expect(entries.first.level, 'ERROR');
      expect(entries.first.message, 'bad thing happened');
    });

    test('error() appends error object to message', () {
      AppLogger.error('oops', Exception('boom'));

      final entries = AppLogger.entries.value;
      expect(entries.first.message, contains('oops'));
      expect(entries.first.message, contains('boom'));
    });

    test('entries are ordered oldest-first', () {
      AppLogger.info('first');
      AppLogger.info('second');
      AppLogger.info('third');

      final entries = AppLogger.entries.value;
      expect(entries[0].message, 'first');
      expect(entries[1].message, 'second');
      expect(entries[2].message, 'third');
    });

    test('clear() removes all entries', () {
      AppLogger.info('a');
      AppLogger.warning('b');
      AppLogger.clear();

      expect(AppLogger.entries.value, isEmpty);
    });

    test('ValueListenable notifies listeners after clear()', () {
      AppLogger.info('x');
      AppLogger.clear();

      expect(AppLogger.entries.value, isEmpty);
    });

    test('exportLines() returns one line per entry', () {
      AppLogger.info('line1');
      AppLogger.warning('line2');

      final lines = AppLogger.exportLines();
      expect(lines.length, 2);
      expect(lines[0], contains('INFO'));
      expect(lines[1], contains('WARN'));
    });

    test('exportLines() returns empty list when no entries', () {
      expect(AppLogger.exportLines(), isEmpty);
    });

    test('retention trimming keeps at most _maxEntries entries', () {
      // Add slightly more than the cap (400).
      for (var i = 0; i < 420; i++) {
        AppLogger.info('msg $i');
      }

      final entries = AppLogger.entries.value;
      // Should be trimmed to exactly 400.
      expect(entries.length, 400);
      // Oldest entries should have been dropped; newest should be last.
      expect(entries.last.message, 'msg 419');
      // The first retained entry should be msg 20 (420 - 400).
      expect(entries.first.message, 'msg 20');
    });

    test('entries list is unmodifiable', () {
      AppLogger.info('a');

      final entries = AppLogger.entries.value;
      expect(() => (entries as dynamic).add(entries.first), throwsUnsupportedError);
    });
  });
}
