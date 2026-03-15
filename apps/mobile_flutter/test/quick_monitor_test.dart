import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Home screen navigation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders home screen with shell tabs', (tester) async {
      await tester.pumpWidget(const PitchTranslatorApp());
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Home'), findsWidgets);
      expect(find.text('Analyze'), findsWidgets);
    });

    testWidgets('tap Train tab opens train screen', (tester) async {
      await tester.pumpWidget(const PitchTranslatorApp());
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.text('Train').last);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Train'), findsWidgets);
    });
  });
}
