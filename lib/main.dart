import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'src/localization/app_localizations.dart';
import 'src/services/app_state.dart';
import 'src/screens/splash_screen.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  runApp(OdiaTradersApp(appState: appState));
  unawaited(appState.init());
}

class OdiaTradersApp extends StatelessWidget {
  final AppState appState;

  const OdiaTradersApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(builder: (context, state, child) {
        return MaterialApp(
          title: 'OdiaTraders',
          theme: AppTheme.light,
          locale: state.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        );
      }),
    );
  }
}
