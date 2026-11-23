import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A layout decision based on logical pixels, independent of keyboard height.
/// Phones keep their original widget trees, including in landscape.
abstract final class AppLayout {
  static const tabletBreakpoint = 600.0;
  static const maxContentWidth = 1200.0;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;

  /// Camera orientation must use the real device view even inside a form canvas.
  static bool isTabletView(BuildContext context) {
    final view = View.of(context);
    return (view.physicalSize / view.devicePixelRatio).shortestSide >=
        tabletBreakpoint;
  }
}

/// Keeps legacy forms readable without changing their phone implementation.
/// The outer scroll view owns keyboard avoidance; the nested page sees the
/// dimensions of its actual form canvas, not those of the whole tablet.
class TabletFormSurface extends StatelessWidget {
  const TabletFormSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppLayout.isTablet(context)) return child;
    final media = MediaQuery.of(context);
    return ColoredBox(
      color: const Color(0xFFF3F8F1),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final formWidth = math.min(480.0, constraints.maxWidth - 48);
              final formHeight = math.max(
                880.0,
                math.min(920.0, constraints.maxHeight - 48),
              );
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (constraints.maxWidth >= 1000) ...[
                        SizedBox(
                          width: 280,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/newimage/frog1.png',
                                height: 260,
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Smile Quest',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF427C47),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                      SizedBox(
                        key: const ValueKey('tablet-form-canvas'),
                        width: formWidth,
                        height: formHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D000000),
                                blurRadius: 28,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: MediaQuery(
                              data: media.copyWith(
                                size: Size(formWidth, formHeight),
                                padding: EdgeInsets.zero,
                                viewPadding: EdgeInsets.zero,
                                viewInsets: EdgeInsets.zero,
                              ),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class TabletHeader extends StatelessWidget {
  const TabletHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      children: [
        if (onBack != null) ...[
          IconButton.filledTonal(
            tooltip: 'Назад',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191919),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF777777),
                  ),
                ),
              ],
            ],
          ),
        ),
        ...actions,
      ],
    ),
  );
}

class TabletCard extends StatelessWidget {
  const TabletCard({super.key, required this.child, this.padding = 24});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: Color(0xFFF0F0F0)),
    ),
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}
