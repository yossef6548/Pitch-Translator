import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void info(String message) => debugPrint('[INFO] $message');

  static void warning(String message) => debugPrint('[WARN] $message');

  static void error(String message, [Object? error]) {
    debugPrint('[ERROR] $message${error == null ? '' : ' • $error'}');
  }
}
