import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pt_contracts/pt_contracts.dart';
import 'package:sqflite/sqflite.dart';

class DriftSnippetRecorder {
  DriftSnippetRecorder({
    this.historyWindowMs = 1500,
    Future<String> Function()? baseDirectoryProvider,
  }) : _baseDirectoryProvider = baseDirectoryProvider ?? getDatabasesPath;

  final int historyWindowMs;
  final Future<String> Function() _baseDirectoryProvider;
  final List<DspFrame> _buffer = <DspFrame>[];

  void addFrame(DspFrame frame) {
    _buffer.add(frame);
    final cutoff = frame.timestampMs - historyWindowMs;
    while (_buffer.isNotEmpty && _buffer.first.timestampMs < cutoff) {
      _buffer.removeAt(0);
    }
  }

  Future<String> persistSnippet({
    required int sessionStartMs,
    required int eventIndex,
  }) async {
    final baseDir = await _baseDirectoryProvider();
    final snippetsDir = Directory(p.join(baseDir, 'drift_snippets'));
    if (!await snippetsDir.exists()) {
      await snippetsDir.create(recursive: true);
    }
    final filePath = p.join(
      snippetsDir.path,
      'session-${sessionStartMs}_drift-$eventIndex.json',
    );

    final payload = {
      'sessionStartMs': sessionStartMs,
      'eventIndex': eventIndex,
      'capturedAtMs': DateTime.now().millisecondsSinceEpoch,
      'frameCount': _buffer.length,
      'frames': _buffer
          .map(
            (frame) => {
              'timestampMs': frame.timestampMs,
              'freqHz': frame.freqHz,
              'centsError': frame.centsError,
              'confidence': frame.confidence,
              'nearestMidi': frame.nearestMidi,
              'isVoiced': frame.isVoiced,
            },
          )
          .toList(growable: false),
    };

    final file = File(filePath);
    await file.writeAsString(jsonEncode(payload));
    return file.path;
  }
}
