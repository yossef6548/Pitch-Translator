import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows home screen with navigation tiles', (tester) async {
    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Live Pitch'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('tapping Live Pitch tile navigates to live pitch screen',
      (tester) async {
    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Live Pitch'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Live Pitch'), findsWidgets);
  });

  testWidgets('tapping History tile navigates to history screen',
      (tester) async {
    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.textContaining('History'), findsWidgets);
  });

  testWidgets('tapping Settings tile navigates to settings screen',
      (tester) async {
    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
  });
}
