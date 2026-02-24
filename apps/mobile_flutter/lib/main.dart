import 'package:flutter/material.dart';
import 'package:pt_contracts/pt_contracts.dart';

void main() {
  // TODO: initialize native audio bridge + DSP stream
  runApp(const PitchTranslatorApp());
}

class PitchTranslatorApp extends StatelessWidget {
  const PitchTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pitch Translator',
      home: const PlaceholderHome(),
    );
  }
}

class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pitch Translator (Skeleton)')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scaffold only — implementation pending.'),
            const SizedBox(height: 12),
            Text('Contract version: ${PtContracts.version}'),
          ],
        ),
      ),
    );
  }
}
