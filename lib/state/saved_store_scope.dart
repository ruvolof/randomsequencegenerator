import 'package:flutter/widgets.dart';

import '../services/saved_store.dart';

/// Exposes the one piece of state that crosses a screen boundary.
///
/// This is `ChangeNotifierProvider` minus the dependency. It is not a global
/// singleton, so a widget test can inject a fake-backed store.
class SavedStoreScope extends InheritedNotifier<SavedStore> {
  const SavedStoreScope({
    required SavedStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  /// The store, subscribing the caller to its changes.
  static SavedStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SavedStoreScope>();
    assert(scope != null, 'No SavedStoreScope found in context');
    return scope!.notifier!;
  }

  /// The store without subscribing — for callbacks that only mutate it.
  static SavedStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SavedStoreScope>();
    assert(scope != null, 'No SavedStoreScope found in context');
    return scope!.notifier!;
  }
}
