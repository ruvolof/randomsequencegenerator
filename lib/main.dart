import 'package:flutter/material.dart';

import 'app.dart';
import 'services/key_value_store.dart';
import 'services/saved_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SavedStore(SharedPreferencesKeyValueStore());
  // Awaited so the saved list is populated before the first frame; a failed
  // read leaves the store empty rather than blocking startup.
  await store.load();
  runApp(RsgApp(savedStore: store));
}
