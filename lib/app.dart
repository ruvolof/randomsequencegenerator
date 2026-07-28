import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'screens/main_screen.dart';
import 'services/saved_store.dart';
import 'state/saved_store_scope.dart';
import 'theme/app_theme.dart';

class RsgApp extends StatelessWidget {
  const RsgApp({required this.savedStore, super.key});

  final SavedStore savedStore;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.build();
    return SavedStoreScope(
      store: savedStore,
      child: MaterialApp(
        onGenerateTitle: (context) =>
            AppLocalizations.of(context).titleActivityRsgMain,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The app is dark-only regardless of the system setting, so both slots
        // get the same theme.
        theme: theme,
        darkTheme: theme,
        themeMode: ThemeMode.dark,
        home: const MainScreen(),
      ),
    );
  }
}
