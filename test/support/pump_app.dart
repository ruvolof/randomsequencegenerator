import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_sequence_generator/l10n/generated/app_localizations.dart';
import 'package:random_sequence_generator/services/saved_store.dart';
import 'package:random_sequence_generator/state/saved_store_scope.dart';
import 'package:random_sequence_generator/theme/app_theme.dart';

import 'fake_key_value_store.dart';

/// A store backed by memory, so no plugin is involved.
SavedStore fakeStore([FakeKeyValueStore? backing]) =>
    SavedStore(backing ?? FakeKeyValueStore());

/// Pumps [child] inside the same MaterialApp the real app builds: the dark
/// theme, the localization delegates, and a [SavedStoreScope].
///
/// [theme] overrides the app theme, which is how a test proves a widget takes a
/// colour from the theme rather than from a constant that happens to match it.
extension PumpApp on WidgetTester {
  Future<SavedStore> pumpApp(
    Widget child, {
    SavedStore? store,
    ThemeData? theme,
  }) async {
    final resolved = store ?? fakeStore();
    addTearDown(resolved.dispose);
    theme ??= AppTheme.build();
    await pumpWidget(
      SavedStoreScope(
        store: resolved,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          darkTheme: theme,
          themeMode: ThemeMode.dark,
          home: child,
        ),
      ),
    );
    return resolved;
  }
}

/// The English strings, for tests that assert on user-facing text.
AppLocalizations l10nOf(WidgetTester tester, Finder finder) =>
    AppLocalizations.of(tester.element(finder));
