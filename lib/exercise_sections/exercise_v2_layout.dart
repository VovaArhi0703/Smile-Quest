import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../layout/adaptive_layout.dart';
import '../layout/tablet_camera_workspace.dart';

class ExerciseV2Layout extends StatelessWidget {
  const ExerciseV2Layout({
    super.key,
    required this.title,
    required this.repetitions,
    required this.goal,
    required this.instruction,
    required this.onEnableCamera,
    required this.actions,
    this.camera,
    this.onMirror,
    this.calibrationProgress,
    this.onRetry,
    this.retryLabel = 'Повторить соединение',
    this.details,
    this.done = false,
  });

  static const green = Color(0xFF81C784);
  static const _background = Color(0xFFF9F9F9);
  static const _progressBackground = Color(0xFFF2F2F2);
  static const _ink = Color(0xFF191919);

  final String title;
  final int repetitions;
  final int goal;
  final Widget instruction;
  final VoidCallback onEnableCamera;
  final List<ExerciseV2Action> actions;
  final Widget? camera;
  final VoidCallback? onMirror;
  final double? calibrationProgress;
  final VoidCallback? onRetry;
  final String retryLabel;
  final Widget? details;
  final bool done;

  Widget _header(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 94),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 34,
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFF5F5F5)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Center(
                        child: Image.asset(
                          'assets/exercise/arrow_left.png',
                          width: 18,
                          height: 18,
                          semanticLabel: 'Назад',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: SizedBox(
                      height: 34,
                      child: Stack(
                        children: [
                          const ColoredBox(
                            color: _progressBackground,
                            child: SizedBox.expand(),
                          ),
                          FractionallySizedBox(
                            widthFactor: (repetitions / goal).clamp(0.0, 1.0),
                            child: const ColoredBox(
                              color: green,
                              child: SizedBox.expand(),
                            ),
                          ),
                          Center(
                            child: Text(
                              '$repetitions/$goal',
                              style: const TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 50),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraArea() => AspectRatio(
    aspectRatio: 3 / 4,
    child:
        camera == null
            ? ColoredBox(
              color: _background,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Твоя очередь, включишь камеру?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Image.asset(
                      'assets/newimage/frog1.png',
                      width: 200,
                      height: 262,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            )
            : Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.black, child: camera),
                if (onMirror != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      tooltip: 'Отразить точки',
                      onPressed: onMirror,
                      icon: const Icon(Icons.flip),
                    ),
                  ),
              ],
            ),
  );

  Widget _controls() {
    if (camera == null) {
      return Center(
        child: ElevatedButton(
          onPressed: onEnableCamera,
          style: ElevatedButton.styleFrom(
            backgroundColor: green,
            foregroundColor: Colors.white,
            minimumSize: const Size(247, 42),
            shape: const StadiumBorder(),
          ),
          child: const Text('Включить камеру'),
        ),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 8,
      children: actions,
    );
  }

  Widget _card(Widget child, {double padding = 16}) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppLayout.isTablet(context)) {
      return TabletCameraWorkspace(
        header: _header(context),
        preview: _cameraArea(),
        panel: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(_controls()),
            const SizedBox(height: 16),
            _card(
              Column(
                children: [
                  instruction,
                  if (calibrationProgress != null) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: calibrationProgress,
                      color: green,
                      backgroundColor: _progressBackground,
                    ),
                  ],
                  if (onRetry != null) ...[
                    const SizedBox(height: 12),
                    TextButton(onPressed: onRetry, child: Text(retryLabel)),
                  ],
                ],
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: 16),
              _card(details!),
            ],
            if (done) ...[
              const SizedBox(height: 16),
              _card(
                Column(
                  children: [
                    Image.asset('assets/newimage/happy.png', height: 140),
                    const SizedBox(height: 12),
                    const Text('Поздравляем! Упражнение выполнено.'),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _cameraArea(),
                    const SizedBox(height: 12),
                    _controls(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _card(
                            Column(
                              children: [
                                instruction,
                                if (calibrationProgress != null) ...[
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(
                                    value: calibrationProgress,
                                    color: green,
                                    backgroundColor: _progressBackground,
                                  ),
                                ],
                                if (onRetry != null) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: onRetry,
                                    child: Text(retryLabel),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (details case final details?) ...[
                            const SizedBox(height: 12),
                            _card(details),
                          ],
                          if (done) ...[
                            const SizedBox(height: 12),
                            _card(
                              Column(
                                children: [
                                  Image.asset(
                                    'assets/newimage/happy.png',
                                    height: 140,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Поздравляем! Упражнение выполнено.',
                                  ),
                                ],
                              ),
                              padding: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExerciseV2Action extends StatelessWidget {
  const ExerciseV2Action(this.label, this.asset, this.onTap, {super.key});

  final String label;
  final String asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const green = ExerciseV2Layout.green;
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          SizedBox.square(
            dimension: 66,
            child: Semantics(
              label: label,
              button: true,
              enabled: onTap != null,
              child: Material(
                color: onTap == null ? green.withValues(alpha: 0.35) : green,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Center(
                    child: Image.asset(asset, width: 34, height: 34),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'SF Pro', fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Fills the exercise viewport while preserving the native camera proportions.
class ExerciseV2CameraPreview extends StatelessWidget {
  const ExerciseV2CameraPreview({
    super.key,
    required this.controller,
    required this.overlay,
  });

  final CameraController controller;
  final Widget overlay;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize!;
    if (AppLayout.isTabletView(context)) {
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: ValueListenableBuilder<CameraValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final orientation =
                      value.previewPauseOrientation ??
                      value.lockedCaptureOrientation ??
                      value.deviceOrientation;
                  final landscape =
                      orientation == DeviceOrientation.landscapeLeft ||
                      orientation == DeviceOrientation.landscapeRight;
                  return FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: landscape ? size.width : size.height,
                      height: landscape ? size.height : size.width,
                      child: CameraPreview(controller),
                    ),
                  );
                },
              ),
            ),
            IgnorePointer(child: overlay),
          ],
        ),
      );
    }
    return RepaintBoundary(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.height,
            height: size.width,
            child: CameraPreview(
              controller,
              child: IgnorePointer(child: overlay),
            ),
          ),
        ),
      ),
    );
  }
}
