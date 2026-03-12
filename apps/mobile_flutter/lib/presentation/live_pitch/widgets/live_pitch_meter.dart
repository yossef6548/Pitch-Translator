import 'package:flutter/material.dart';
import 'package:pt_contracts/pt_contracts.dart';

class LivePitchMeter extends StatefulWidget {
  const LivePitchMeter({
    super.key,
    required this.state,
    required this.onWidthMeasured,
  });

  final LivePitchUiState state;
  final ValueChanged<double> onWidthMeasured;

  @override
  State<LivePitchMeter> createState() => _LivePitchMeterState();
}

class _LivePitchMeterState extends State<LivePitchMeter> {
  double _lastReportedWidth = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The full width of the meter represents exactly one semitone.
        // Therefore semitoneWidthPxW == widget width.
        final width = constraints.maxWidth;
        if (constraints.hasBoundedWidth && width.isFinite && width > 0 && width != _lastReportedWidth) {
          _lastReportedWidth = width;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onWidthMeasured(width);
          });
        }

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
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(widget.state.xOffsetPx, 0),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: widget.state.haloIntensity > 0.3
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
