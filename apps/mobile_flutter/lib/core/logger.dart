import 'dart:collection';

import 'package:flutter/foundation.dart';

@immutable
class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  final DateTime timestamp;
  final String level;
  final String message;

  String toDisplayLine() {
    final iso = timestamp.toIso8601String();
    return '[$iso][$level] $message';
  }
}

class AppLogger {
  AppLogger._();

  static const int _maxEntries = 400;
  static final List<AppLogEntry> _entries = <AppLogEntry>[];
  static final ValueNotifier<UnmodifiableListView<AppLogEntry>> _notifier =
      ValueNotifier<UnmodifiableListView<AppLogEntry>>(
    UnmodifiableListView<AppLogEntry>(<AppLogEntry>[]),
  );

  static ValueListenable<UnmodifiableListView<AppLogEntry>> get entries =>
      _notifier;

  static void info(String message) => _record('INFO', message);

  static void warning(String message) => _record('WARN', message);

  static void error(String message, [Object? error]) {
    _record('ERROR', '$message${error == null ? '' : ' • $error'}');
  }

  static List<String> exportLines() {
    return _entries.map((entry) => entry.toDisplayLine()).toList(growable: false);
  }

  static void clear() {
    _entries.clear();
    _publish();
  }

  static void _record(String level, String message) {
    final entry = AppLogEntry(
      timestamp: DateTime.now().toUtc(),
      level: level,
      message: message,
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    _publish();
    debugPrint('[${entry.level}] ${entry.message}');
  }

  static void _publish() {
    _notifier.value = UnmodifiableListView<AppLogEntry>(List<AppLogEntry>.from(_entries));
  }
}
