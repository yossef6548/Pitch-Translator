import 'package:flutter/material.dart';
import 'package:pt_contracts/pt_contracts.dart';

class LivePitchMeter extends StatelessWidget {
  const LivePitchMeter({super.key, required this.state});

  final LivePitchUiState state;

  @override
  Widget build(BuildContext context) {
    final alignmentX = (state.xOffsetPx / PtConstants.semitoneWidthPx)
        .clamp(-1.0, 1.0)
        .toDouble();

    return SizedBox(
      height: 24,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(height: 2, color: Colors.white24),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(width: 2, height: 20, color: Colors.white70),
          ),
          Align(
            alignment: Alignment(alignmentX, 0),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: state.haloIntensity > 0.3 ? Colors.greenAccent : Colors.orangeAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
