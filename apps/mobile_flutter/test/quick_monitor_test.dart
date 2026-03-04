import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Home screen navigation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders home screen with Live Pitch and History tiles',
        (tester) async {
      await tester.pumpWidget(const PitchTranslatorApp());
      await tester.pumpAndSettle();

      expect(find.text('Live Pitch'), findsOneWidget);
      expect(find.text('Select exercise + level to start session'),
          findsOneWidget);
    });

    testWidgets('tap Live Pitch tile opens exercise select screen',
        (tester) async {
      await tester.pumpWidget(const PitchTranslatorApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Live Pitch'));
      await tester.pumpAndSettle();

      expect(find.text('Select Exercise'), findsOneWidget);
    });
  });
}
