import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adaptive_layout.dart';

/// The preview always stays 3:4. Only its position and available size change;
/// camera frames, landmark coordinates and exercise logic are not transformed.
class TabletCameraWorkspace extends StatelessWidget {
  const TabletCameraWorkspace({
    super.key,
    required this.header,
    required this.preview,
    required this.panel,
  });

  final Widget header;
  final Widget preview;
  final Widget panel;

  Widget _preview(double width) => SizedBox(
    key: const ValueKey('tablet-camera-viewport'),
    width: width,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(aspectRatio: 3 / 4, child: preview),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9F9F9),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxContentWidth,
          ),
          child: Column(
            children: [
              header,
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 840) {
                      final cameraWidth = math.min(
                        constraints.maxWidth * 0.48,
                        math.max(0.0, constraints.maxHeight - 48) * 3 / 4,
                      );
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _preview(cameraWidth),
                            const SizedBox(width: 24),
                            Expanded(
                              child: SingleChildScrollView(child: panel),
                            ),
                          ],
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: Column(
                        children: [
                          _preview(math.min(420, constraints.maxWidth - 48)),
                          const SizedBox(height: 24),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: panel,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
