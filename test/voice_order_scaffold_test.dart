import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hindustan_traders/customer/customer_home_screen.dart';
import 'package:hindustan_traders/src/localization/app_localizations.dart';

Widget createTestApp({required Widget child}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  testWidgets('Customer home shows voice order scaffold and draft history', (tester) async {
    await tester.pumpWidget(createTestApp(child: const CustomerHomeScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Voice order'), findsOneWidget);
    expect(find.textContaining('Record order'), findsOneWidget);
    expect(find.textContaining('Recent drafts'), findsOneWidget);
  });
}
