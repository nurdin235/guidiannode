import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidiannode/core/services/app_preferences.dart';
import 'package:guidiannode/core/services/session_service.dart';
import 'package:guidiannode/features/auth/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpSplashAtSize(WidgetTester tester, Size logicalSize) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = logicalSize;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  SharedPreferences.setMockInitialValues({});
  SessionService.resetForTesting();
  await AppPreferences.ensureInitialized();
  await SessionService.ensureInitialized();

  await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

  expect(find.text('GuardianNode'), findsOneWidget);
  expect(
    find.text('Help is one tap away.\nStronger together,\nsafer Bamenda.'),
    findsOneWidget,
  );
  expect(tester.takeException(), isNull);

  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('splash fits a small Android viewport without overflow', (
    tester,
  ) async {
    await pumpSplashAtSize(tester, const Size(320, 480));
  });

  testWidgets('splash fits a large Android viewport without overflow', (
    tester,
  ) async {
    await pumpSplashAtSize(tester, const Size(430, 932));
  });
}
