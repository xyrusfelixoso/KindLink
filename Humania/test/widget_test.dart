import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const phoneSizes = <Size>[Size(320, 568), Size(360, 640), Size(412, 915)];

  for (final size in phoneSizes) {
    testWidgets('login fits ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });
  }
}
