import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/qa/drift_snippet_recorder.dart';
import 'package:pt_contracts/pt_contracts.dart';

void main() {
  test('persists recent frame window to snippet payload', () async {
    final tempDir = await Directory.systemTemp.createTemp('pt_drift_snippet_test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final recorder = DriftSnippetRecorder(
      historyWindowMs: 200,
      baseDirectoryProvider: () async => tempDir.path,
    );

    recorder.addFrame(
      const DspFrame(
        timestampMs: 1000,
        freqHz: 440.0,
        midiFloat: 69.0,
        nearestMidi: 69,
        centsError: 10.0,
        confidence: 0.95,
        vibrato: VibratoInfo(detected: false),
      ),
    );
    recorder.addFrame(
      const DspFrame(
        timestampMs: 1190,
        freqHz: 441.0,
        midiFloat: 69.0,
        nearestMidi: 69,
        centsError: 6.0,
        confidence: 0.96,
        vibrato: VibratoInfo(detected: false),
      ),
    );
    recorder.addFrame(
      const DspFrame(
        timestampMs: 1300,
        freqHz: 439.0,
        midiFloat: 68.97,
        nearestMidi: 69,
        centsError: -8.0,
        confidence: 0.92,
        vibrato: VibratoInfo(detected: false),
      ),
    );

    final snippetPath = await recorder.persistSnippet(sessionStartMs: 100, eventIndex: 2);

    final snippetFile = File(snippetPath);
    expect(await snippetFile.exists(), isTrue);

    final json = jsonDecode(await snippetFile.readAsString()) as Map<String, dynamic>;
    expect(json['sessionStartMs'], 100);
    expect(json['eventIndex'], 2);
    expect(json['frameCount'], 2);

    final frames = (json['frames'] as List).cast<Map<String, dynamic>>();
    expect(frames.map((f) => f['timestamp_ms']), [1190, 1300]);
  });
}
