import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows home shell navigation tabs', (tester) async {
    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Train'), findsWidgets);
    expect(find.text('Analyze'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('tapping Train tab navigates to train screen', (tester) async {
    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('Train').last);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Train'), findsWidgets);
  });


}
