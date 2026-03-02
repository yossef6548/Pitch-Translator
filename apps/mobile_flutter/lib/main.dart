import 'package:flutter/widgets.dart';

import 'app/app.dart';

/// Alias retained for backwards compatibility with existing widget tests.
typedef PitchTranslatorApp = App;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}
