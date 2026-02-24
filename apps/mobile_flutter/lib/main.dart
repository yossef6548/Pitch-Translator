import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pt_contracts/pt_contracts.dart';

import 'audio/native_audio_bridge.dart';
import 'training/training_engine.dart';

void main() {
  runApp(const PitchTranslatorApp());
}

class PitchTranslatorApp extends StatelessWidget {
  const PitchTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pitch Translator',
      theme: ThemeData.dark(useMaterial3: true),
      home: const LivePitchScreen(),
    );
  }
}

class LivePitchScreen extends StatefulWidget {
  const LivePitchScreen({super.key});

  @override
  State<LivePitchScreen> createState() => _LivePitchScreenState();
}

class _LivePitchScreenState extends State<LivePitchScreen> {
  final _engine = TrainingEngine(config: const ExerciseConfig(driftAwarenessMode: true));
  final _bridge = NativeAudioBridge();
  StreamSubscription<DspFrame>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _bridge.frames().listen((frame) {
      setState(() => _engine.onDspFrame(frame));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _engine.state;
    return Scaffold(
      appBar: AppBar(title: const Text('LIVE_PITCH')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _TargetHeader(),
            const SizedBox(height: 24),
            _PitchLine(state: state),
            const SizedBox(height: 24),
            _PitchShape(state: state),
            const SizedBox(height: 24),
            Text(
              state.errorReadoutVisible ? 'Cents: ${state.displayCents} ${state.arrow}' : 'Cents: —',
              style: const TextStyle(fontSize: 32),
            ),
            Text('State: ${state.id.name}'),
            const Spacer(),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(onPressed: () => setState(() => _engine.onIntent(TrainingIntent.start)), child: const Text('Start')),
                ElevatedButton(onPressed: () => setState(() => _engine.onIntent(TrainingIntent.pause)), child: const Text('Pause')),
                ElevatedButton(onPressed: () => setState(() => _engine.onIntent(TrainingIntent.resume)), child: const Text('Resume')),
                ElevatedButton(onPressed: () => setState(() => _engine.onIntent(TrainingIntent.stop)), child: const Text('Stop')),
                ElevatedButton(onPressed: () => setState(() => _engine.onIntent(TrainingIntent.restart)), child: const Text('Restart')),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _TargetHeader extends StatelessWidget {
  const _TargetHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Target: A4', style: TextStyle(fontSize: 22)),
        Text('MIDI 69', style: TextStyle(fontSize: 22)),
      ],
    );
  }
}

class _PitchLine extends StatelessWidget {
  const _PitchLine({required this.state});

  final LivePitchUiState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Stack(
        children: [
          Center(child: Container(height: 2, color: Colors.white24)),
          Center(child: Container(width: 2, color: Colors.white, height: 24)),
          Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(state.xOffsetPx, 0),
              child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PitchShape extends StatelessWidget {
  const _PitchShape({required this.state});

  final LivePitchUiState state;

  @override
  Widget build(BuildContext context) {
    final saturation = state.saturation.clamp(0.0, 1.0);
    final color = HSVColor.fromAHSV(1, 0, saturation, 1).toColor();
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withOpacity(state.haloIntensity.clamp(0.0, 1.0)), blurRadius: 24, spreadRadius: 6),
        ],
      ),
      child: Center(child: Text('E=${state.errorFactorE.toStringAsFixed(2)}')),
    );
  }
}
