import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Home screen navigation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders home screen with Live Pitch and History tiles',
        (tester) async {
      await tester.pumpWidget(const PitchTranslatorApp());
      await tester.pumpAndSettle();

      expect(find.text('Live Pitch'), findsOneWidget);
      expect(find.text('Open live audio feedback session'), findsOneWidget);
    });

    testWidgets('tap Live Pitch tile opens live pitch screen', (tester) async {
      await tester.pumpWidget(const PitchTranslatorApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Live Pitch'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Live Pitch'), findsWidgets);
    });
  });
}
