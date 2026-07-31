import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/models/generation_mode.dart';
import 'package:random_sequence_generator/models/saved_entry.dart';
import 'package:random_sequence_generator/services/saved_store.dart';

import '../support/fake_key_value_store.dart';

SavedEntry entry(
  String name, {
  String sequence = 'abc',
  int millis = 1000,
  GenerationMode mode = GenerationMode.binary,
}) => SavedEntry(
  name: name,
  sequence: sequence,
  createdAt: DateTime.fromMillisecondsSinceEpoch(millis),
  mode: mode,
);

void main() {
  group('decode', () {
    test('tolerates every malformed input instead of throwing', () {
      for (final raw in <String?>[
        null,
        '',
        '   ',
        'not json',
        '{}',
        '[1,2,3]',
        '[{"name":"a"}]',
      ]) {
        expect(SavedStore.decode(raw), isEmpty, reason: 'input: $raw');
      }
    });

    test('drops only the malformed records of a mixed list', () {
      final raw = jsonEncode([
        entry('good').toJson(),
        {'name': 'missing everything else'},
        entry('also good', millis: 2000).toJson(),
      ]);
      expect(SavedStore.decode(raw).map((e) => e.name), ['good', 'also good']);
    });

    test('rejects an entry with an unknown mode or a blank name', () {
      final unknownMode = jsonEncode([
        {'name': 'x', 'sequence': 'y', 'createdAt': 1, 'mode': 'octal'},
      ]);
      final blankName = jsonEncode([
        {'name': '', 'sequence': 'y', 'createdAt': 1, 'mode': 'binary'},
      ]);
      expect(SavedStore.decode(unknownMode), isEmpty);
      expect(SavedStore.decode(blankName), isEmpty);
    });
  });

  group('SavedStore', () {
    late FakeKeyValueStore backing;
    late SavedStore store;

    setUp(() {
      backing = FakeKeyValueStore();
      store = SavedStore(backing);
    });

    tearDown(() => store.dispose());

    test('starts empty and loads what was persisted', () async {
      expect(store.entries, isEmpty);
      expect(store.isEmpty, isTrue);

      backing.values[SavedStore.storageKey] = jsonEncode([entry('a').toJson()]);
      await store.load();

      expect(store.entries.single.name, 'a');
      expect(store.isEmpty, isFalse);
    });

    test('a failed read leaves the store empty instead of throwing', () async {
      final failing = SavedStore(ThrowingKeyValueStore());
      addTearDown(failing.dispose);
      var notifications = 0;
      failing.addListener(() => notifications++);

      // `main` awaits this before `runApp`: throwing here means no first frame.
      await failing.load();

      expect(failing.entries, isEmpty);
      expect(failing.isEmpty, isTrue);
      expect(notifications, 1);
    });

    test(
      'round-trips a JSON entry preserving the millisecond and the mode',
      () async {
        final original = entry(
          'key',
          sequence: r'$%&aA0',
          millis: 1234567890123,
          mode: GenerationMode.charClass,
        );
        await store.upsert(original);

        final reloaded = SavedStore(backing);
        addTearDown(reloaded.dispose);
        await reloaded.load();

        expect(reloaded.entries.single, original);
        expect(
          reloaded.entries.single.createdAt.millisecondsSinceEpoch,
          1234567890123,
        );
        expect(reloaded.entries.single.mode, GenerationMode.charClass);
      },
    );

    test(
      'upsert replaces in place, keeping the length and the position',
      () async {
        await store.upsert(entry('a', millis: 100));
        await store.upsert(entry('b', millis: 200));
        await store.upsert(entry('c', millis: 300));

        await store.upsert(entry('b', sequence: 'REPLACED', millis: 200));

        expect(store.entries.length, 3);
        expect(store.entries.map((e) => e.name), ['a', 'b', 'c']);
        expect(store.entries[1].sequence, 'REPLACED');
      },
    );

    test(
      'bug 4 — deleting the middle of three leaves the right survivors',
      () async {
        await store.upsert(entry('first', sequence: '1', millis: 100));
        await store.upsert(entry('second', sequence: '2', millis: 200));
        await store.upsert(entry('third', sequence: '3', millis: 300));

        await store.deleteByName('second');

        expect(store.entries.map((e) => e.name), ['first', 'third']);
        expect(store.entries.map((e) => e.sequence), ['1', '3']);

        // And it stays deleted across a reload — the legacy code only hid a
        // recycled row, so the entry came back on scroll.
        final reloaded = SavedStore(backing);
        addTearDown(reloaded.dispose);
        await reloaded.load();
        expect(reloaded.entries.map((e) => e.name), ['first', 'third']);
      },
    );

    test(
      'deleting an absent name changes nothing and does not write',
      () async {
        await store.upsert(entry('a'));
        backing.writes.clear();

        await store.deleteByName('nope');

        expect(store.entries.map((e) => e.name), ['a']);
        expect(backing.writes, isEmpty);
      },
    );

    test('deleteByNames removes every named entry in one write', () async {
      await store.upsert(entry('first', sequence: '1', millis: 100));
      await store.upsert(entry('second', sequence: '2', millis: 200));
      await store.upsert(entry('third', sequence: '3', millis: 300));
      backing.writes.clear();

      // 'nope' is not there: a selection cannot contain it, but ignoring it is
      // what makes this the same operation as deleteByName, which delegates.
      expect(await store.deleteByNames({'first', 'third', 'nope'}), isTrue);

      expect(store.entries.map((e) => e.name), ['second']);
      // One write, not one per name — so the rows go together and a failure
      // cannot leave half the selection on disk.
      expect(backing.writes, hasLength(1));
    });

    test('deleteByNames with nothing to remove does not write', () async {
      await store.upsert(entry('a'));
      backing.writes.clear();

      expect(await store.deleteByNames({'nope'}), isTrue);
      expect(await store.deleteByNames(const {}), isTrue);

      expect(store.entries.map((e) => e.name), ['a']);
      expect(backing.writes, isEmpty);
    });

    test(
      'a failed write reports false and keeps the change on screen',
      () async {
        await store.upsert(entry('a'));
        backing.failWrites = true;

        expect(await store.upsert(entry('b', millis: 2000)), isFalse);

        // The list the user is looking at holds the entry; only the disk does
        // not. Deliberate — see _commit.
        expect(store.entries.map((e) => e.name), ['a', 'b']);
        expect(
          jsonDecode(backing.values[SavedStore.storageKey]!),
          hasLength(1),
        );
      },
    );

    test('a failed delete reports false, on both delete paths', () async {
      await store.upsert(entry('a'));
      backing.failWrites = true;

      expect(await store.deleteByName('a'), isFalse);
      expect(store.entries, isEmpty);

      await store.upsert(entry('b'));
      expect(await store.deleteByNames({'b'}), isFalse);
      expect(store.entries, isEmpty);
    });

    test('a successful write reports true', () async {
      expect(await store.upsert(entry('a')), isTrue);
      expect(await store.deleteByName('a'), isTrue);
      // Removing a name that is not there writes nothing, and is not a failure.
      expect(await store.deleteByName('gone'), isTrue);
      expect(await store.deleteByNames({'gone'}), isTrue);
    });

    test('removing every name persists an empty list', () async {
      // What Select all followed by Delete does, now that the store has no
      // delete-everything method of its own.
      await store.upsert(entry('a'));
      await store.upsert(entry('b', millis: 2000));
      await store.deleteByNames({'a', 'b'});

      expect(store.entries, isEmpty);
      expect(backing.values[SavedStore.storageKey], '[]');
    });

    test(
      'orders by createdAt, with the name as a same-millisecond tiebreak',
      () async {
        await store.upsert(entry('zulu', millis: 500));
        await store.upsert(entry('alpha', millis: 500));
        await store.upsert(entry('early', millis: 100));
        await store.upsert(entry('late', millis: 900));

        expect(store.entries.map((e) => e.name), [
          'early',
          'alpha',
          'zulu',
          'late',
        ]);
      },
    );

    test('containsName reflects the current entries', () async {
      expect(store.containsName('a'), isFalse);
      await store.upsert(entry('a'));
      expect(store.containsName('a'), isTrue);
      await store.deleteByName('a');
      expect(store.containsName('a'), isFalse);
    });

    test('notifies exactly once per mutation', () async {
      var notifications = 0;
      store.addListener(() => notifications++);

      await store.load();
      expect(notifications, 1);

      await store.upsert(entry('a'));
      expect(notifications, 2);

      await store.upsert(entry('a', sequence: 'changed'));
      expect(notifications, 3);

      await store.deleteByName('a');
      expect(notifications, 4);

      await store.upsert(entry('b'));
      expect(notifications, 5);
      await store.upsert(entry('c', millis: 2000));
      expect(notifications, 6);

      // One notification for the whole set, not one per name — otherwise the
      // list would rebuild once per row it is dropping.
      await store.deleteByNames({'b', 'c'});
      expect(notifications, 7);
    });

    test('entries is an unmodifiable view', () async {
      await store.upsert(entry('a'));
      expect(() => store.entries.add(entry('b')), throwsUnsupportedError);
    });
  });
}
