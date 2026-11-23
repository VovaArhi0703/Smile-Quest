import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../brow_exercise_logic.dart';
import '../../brow_frame_encoder.dart';
import '../../brow_visual_tracker.dart';
import '../../exercise_socket.dart';
import '../../layout/adaptive_layout.dart';
import '../../tablet_camera_geometry.dart';
import '../exercise_v2_layout.dart';

class Face1Exercises extends StatefulWidget {
  const Face1Exercises({super.key})
    : appInterface = false,
      frown = false,
      eyeClose = false,
      blink = false,
      squint = false,
      wink = false,
      smile = false;
  const Face1Exercises.appInterface({super.key})
    : appInterface = true,
      frown = false,
      eyeClose = false,
      blink = false,
      squint = false,
      wink = false,
      smile = false;
  const Face1Exercises.frown({super.key})
    : appInterface = true,
      frown = true,
      eyeClose = false,
      blink = false,
      squint = false,
      wink = false,
      smile = false;
  const Face1Exercises.eyeClose({super.key})
    : appInterface = true,
      frown = false,
      eyeClose = true,
      blink = false,
      squint = false,
      wink = false,
      smile = false;
  const Face1Exercises.blink({super.key})
    : appInterface = true,
      frown = false,
      eyeClose = false,
      blink = true,
      squint = false,
      wink = false,
      smile = false;
  const Face1Exercises.squint({super.key})
    : appInterface = true,
      frown = false,
      eyeClose = false,
      blink = false,
      squint = true,
      wink = false,
      smile = false;
  const Face1Exercises.wink({super.key})
    : appInterface = true,
      frown = false,
      eyeClose = false,
      blink = false,
      squint = false,
      wink = true,
      smile = false;
  const Face1Exercises.smile({super.key})
    : appInterface = true,
      frown = false,
      eyeClose = false,
      blink = false,
      squint = false,
      wink = false,
      smile = true;

  final bool appInterface;
  final bool frown;
  final bool eyeClose;
  final bool blink;
  final bool squint;
  final bool wink;
  final bool smile;
  bool get usesEyeLandmarks => eyeClose || blink || squint || wink;

  @override
  State<Face1Exercises> createState() => _Face1ExercisesState();
}

class _Face1ExercisesState extends State<Face1Exercises> {
  static const _blue = Color(0xFF00BCEB);
  static const _orange = Color(0xFFFF8A31);

  late final _logic = BrowExerciseLogic(
    softThenStrong: widget.eyeClose,
    blink: widget.blink,
    squint: widget.squint,
    wink: widget.wink,
    smile: widget.smile,
  );
  CameraController? _camera;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _responseTimeout;
  Map<int, Offset> _landmarks = {};
  late final BrowVisualTracker _visualTracker;
  final ValueNotifier<Map<int, Offset>> _displayPoints = ValueNotifier({});
  BrowLumaFrame? _pendingVisualFrame;
  BrowLumaFrame? _latestVisualFrame;
  DateTime? _lastVisualAt;
  bool _socketReady = false;
  bool _awaitingResult = false;
  bool _loggedCameraInfo = false;
  bool _loggedDetection = false;
  bool _mirrorPoints = true;
  bool _showAppCamera = false;
  String? _cameraError;
  String? _connectionError;
  String? _faceMessage;
  DateTime? _lastSentAt;
  ({BrowPhase phase, DateTime at, int revision})? _sentFrame;
  int _exerciseRevision = 0;
  bool _tabletCamera = false;
  bool _orientationConfigured = false;
  (DeviceOrientation, int, int, int)? _tabletGeometry;
  (DeviceOrientation, int, int, int)? _sentTabletGeometry;

  @override
  void initState() {
    super.initState();
    _visualTracker = BrowVisualTracker(
      eyeMode: widget.usesEyeLandmarks,
      mouthMode: widget.smile,
    );
    unawaited(_initializeCamera());
    unawaited(_connectSocket());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_orientationConfigured) return;
    _orientationConfigured = true;
    // Use the actual view, including for legacy screens in a bounded canvas.
    _tabletCamera = AppLayout.isTabletView(context);
    if (!_tabletCamera) {
      unawaited(
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
      );
    }
  }

  Future<void> _initializeCamera() async {
    if (_cameraError != null) setState(() => _cameraError = null);
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      for (final preset in [ResolutionPreset.high, ResolutionPreset.medium]) {
        final controller = CameraController(front, preset, enableAudio: false);
        try {
          await controller.initialize();
          if (!_tabletCamera) {
            await controller.lockCaptureOrientation(
              DeviceOrientation.portraitUp,
            );
          }
          if (!mounted) {
            await controller.dispose();
            return;
          }
          await controller.startImageStream(_processCameraImage);
          if (!mounted) {
            await controller.dispose();
            return;
          }
          setState(() => _camera = controller);
          return;
        } catch (error) {
          await controller.dispose();
          if (!mounted) return;
          if (preset == ResolutionPreset.medium ||
              (error is CameraException &&
                  error.code.startsWith('CameraAccess'))) {
            rethrow;
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _cameraError =
                  'Не удалось включить переднюю камеру. Проверьте разрешение камеры.',
        );
      }
    }
  }

  Future<void> _connectSocket() async {
    await _socketSubscription?.cancel();
    await _channel?.sink.close();
    if (!mounted) return;
    setState(() {
      _socketReady = false;
      _connectionError = null;
    });
    try {
      final channel = connectExerciseSocket(context);
      _channel = channel;
      _socketSubscription = channel.stream.listen(
        (dynamic message) {
          if (identical(_channel, channel)) _handleServerMessage(message);
        },
        onError: (Object error) {
          if (identical(_channel, channel)) _markDisconnected();
        },
        onDone: () {
          if (identical(_channel, channel)) _markDisconnected();
        },
      );
      final ready = await waitExerciseSocket(channel);
      if (mounted && identical(_channel, channel)) {
        setState(() {
          _socketReady = ready;
          if (!ready) {
            _connectionError = 'Нет соединения с сервером упражнений.';
          }
        });
      }
    } catch (_) {
      _markDisconnected();
    }
  }

  void _markDisconnected() {
    _responseTimeout?.cancel();
    _awaitingResult = false;
    _sentFrame = null;
    if (!mounted) return;
    _visualTracker.reset();
    _displayPoints.value = {};
    _pendingVisualFrame = null;
    if (mounted) {
      setState(() {
        _socketReady = false;
        _connectionError = 'Нет соединения с сервером упражнений.';
        _landmarks = {};
        _logic.faceLost();
      });
    }
  }

  void _processCameraImage(CameraImage frame) async {
    if (!mounted || (widget.appInterface && !_showAppCamera)) return;
    final controller = _camera;
    final rotation =
        _tabletCamera && controller != null
            ? tabletFrameRotation(
              sensorOrientation: controller.description.sensorOrientation,
              orientation: controller.value.deviceOrientation,
              frontFacing:
                  controller.description.lensDirection ==
                  CameraLensDirection.front,
              android: defaultTargetPlatform == TargetPlatform.android,
            )
            : null;
    final geometry =
        _tabletCamera && controller != null
            ? (
              controller.value.deviceOrientation,
              frame.width,
              frame.height,
              rotation!,
            )
            : null;
    if (_tabletCamera && geometry != _tabletGeometry) {
      _tabletGeometry = geometry;
      _exerciseRevision++;
      _logic.faceLost();
      _visualTracker.reset();
      _displayPoints.value = {};
      _landmarks = {};
      _latestVisualFrame = null;
      _pendingVisualFrame = null;
    }
    if (!_loggedCameraInfo && kDebugMode) {
      _loggedCameraInfo = true;
      debugPrint(
        'Brow camera: frame=${frame.width}x${frame.height}, '
        'format=${frame.format.group}, sensor=${_camera?.description.sensorOrientation}, '
        'preview=${_camera?.value.previewSize}',
      );
    }
    final channel = _channel;
    final now = DateTime.now();
    final shouldSend =
        _socketReady &&
        channel != null &&
        !_awaitingResult &&
        (_lastSentAt == null ||
            now.difference(_lastSentAt!) >=
                (_logic.phase == BrowPhase.neutral ||
                        _logic.phase == BrowPhase.maximum
                    ? const Duration(milliseconds: 150)
                    : Duration(
                      milliseconds:
                          widget.blink || widget.wink
                              ? 120
                              : widget.squint || widget.smile || widget.eyeClose
                              ? 180
                              : 300,
                    )));
    if ((_socketReady && channel != null) &&
        (shouldSend ||
            _lastVisualAt == null ||
            now.difference(_lastVisualAt!) >=
                const Duration(milliseconds: 80))) {
      final camera = _camera;
      if (camera != null) {
        final visualFrame = sampleBrowLuma(
          frame,
          sensorOrientation: rotation ?? camera.description.sensorOrientation,
          rotateToPortrait:
              _tabletCamera ||
              (defaultTargetPlatform == TargetPlatform.android &&
                  frame.width > frame.height),
          cropToPortrait: _tabletCamera,
        );
        if (visualFrame != null) {
          _latestVisualFrame = visualFrame;
          _lastVisualAt = now;
          if (_landmarks.isNotEmpty) {
            _displayPoints.value = _visualTracker.track(visualFrame);
          }
        }
      }
    }
    if (!shouldSend) return;
    _lastSentAt = now;
    _awaitingResult = true;
    _sentFrame = (phase: _logic.phase, at: now, revision: _exerciseRevision);
    _sentTabletGeometry = geometry;
    _pendingVisualFrame = _latestVisualFrame;
    try {
      final camera = _camera;
      if (camera == null) {
        _awaitingResult = false;
        return;
      }
      final encoded =
          _tabletCamera
              ? await compute(encodeTabletBrowFrame, (frame, rotation ?? 0))
              : await compute(encodeBrowFrame, (
                frame,
                camera.description.sensorOrientation,
                defaultTargetPlatform == TargetPlatform.android &&
                    frame.width > frame.height,
              ));
      if (encoded == null ||
          !mounted ||
          !identical(channel, _channel) ||
          (_tabletCamera && geometry != _tabletGeometry)) {
        _awaitingResult = false;
        _sentFrame = null;
        _pendingVisualFrame = null;
        return;
      }
      channel.sink.add(
        jsonEncode({
          'mode': 'observe',
          'exercise':
              widget.blink
                  ? 'face_4'
                  : widget.eyeClose
                  ? 'face_3'
                  : widget.squint
                  ? 'face_6'
                  : widget.wink
                  ? 'face_7'
                  : widget.smile
                  ? 'lip_4'
                  : widget.frown
                  ? 'face_2'
                  : 'face_1',
          'image': encoded,
        }),
      );
      _responseTimeout?.cancel();
      _responseTimeout = Timer(const Duration(seconds: 3), () {
        if (!mounted || !identical(channel, _channel)) return;
        _channel = null;
        _markDisconnected();
        unawaited(channel.sink.close().then<void>((_) {}, onError: (_, _) {}));
      });
    } catch (_) {
      _awaitingResult = false;
      _sentFrame = null;
      _pendingVisualFrame = null;
      if (mounted) {
        setState(() => _faceMessage = 'Не удалось обработать кадр камеры.');
      }
    }
  }

  void _handleServerMessage(dynamic raw) {
    if (!mounted) return;
    try {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      if (message['status'] == 'authenticated') return;
      _responseTimeout?.cancel();
      _awaitingResult = false;
      final sentFrame = _sentFrame;
      _sentFrame = null;
      if (_tabletCamera && _sentTabletGeometry != _tabletGeometry) {
        _pendingVisualFrame = null;
        return;
      }
      if (message['error'] != null) {
        if (message['error'] == 'invalid_frame') {
          _visualTracker.reset();
          _displayPoints.value = {};
          _pendingVisualFrame = null;
          final detail = (message['message'] ?? '').toString();
          if (kDebugMode) debugPrint('Brow detection: $detail');
          setState(() {
            _landmarks = {};
            _logic.faceLost();
            _faceMessage =
                detail.contains('Unknown mode')
                    ? 'Сервер запущен со старым кодом. Перезапустите его.'
                    : detail.contains('too far')
                    ? 'Лицо слишком далеко. Подойдите немного ближе.'
                    : detail.contains('outside the frame')
                    ? 'Лицо не помещается в кадр. Отодвиньтесь немного.'
                    : 'Лицо не видно. Посмотрите прямо в камеру.';
          });
        } else {
          showExerciseSocketError(context, message);
        }
        return;
      }
      if (message['status'] != 'observation') return;
      if (!_loggedDetection && kDebugMode) {
        _loggedDetection = true;
        debugPrint('Brow detection: face landmarks received');
      }
      final features = message['features'] as Map<String, dynamic>;
      final rawLandmarks = message['landmarks'] as Map<String, dynamic>;
      final points = <int, Offset>{};
      for (final entry in rawLandmarks.entries) {
        final coordinates = entry.value;
        if (coordinates is List &&
            coordinates.length == 2 &&
            coordinates[0] is num &&
            coordinates[1] is num &&
            (coordinates[0] as num).isFinite &&
            (coordinates[1] as num).isFinite) {
          final index = int.tryParse(entry.key);
          if (index != null) {
            points[index] = Offset(
              (coordinates[0] as num).toDouble(),
              (coordinates[1] as num).toDouble(),
            );
          }
        }
      }
      _visualTracker.setObservation(points, _pendingVisualFrame);
      _pendingVisualFrame = null;
      _displayPoints.value = _visualTracker.track(_latestVisualFrame);
      setState(() {
        _landmarks = points;
        _faceMessage = null;
        if (sentFrame != null &&
            sentFrame.phase == _logic.phase &&
            sentFrame.revision == _exerciseRevision) {
          _observe(features, sentFrame.at);
        }
      });
    } catch (_) {
      setState(() => _faceMessage = 'Не удалось прочитать ответ сервера.');
    }
  }

  void _observe(Map<String, dynamic> features, DateTime at) {
    final blue = features['blue_gap'];
    final orange = features['orange_gap'];
    if (blue is! num || orange is! num) return;
    _logic.add(
      BrowSample.fromGaps(
        blue.toDouble(),
        orange.toDouble(),
        frown: widget.eyeClose || widget.blink || widget.wink,
        blueSqueeze: (features['blue_squeeze'] as num?)?.toDouble(),
        orangeSqueeze: (features['orange_squeeze'] as num?)?.toDouble(),
        blueAperture: (features['blue_aperture'] as num?)?.toDouble(),
        orangeAperture: (features['orange_aperture'] as num?)?.toDouble(),
      ),
      at,
    );
  }

  void _beginNeutralCalibration() {
    setState(() {
      _lastSentAt = null;
      _exerciseRevision++;
      _logic.beginNeutral();
    });
  }

  void _beginMaximumCalibration() {
    setState(() {
      _lastSentAt = null;
      _exerciseRevision++;
      _logic.beginMaximum();
    });
  }

  void _changeTracking(VoidCallback change) {
    setState(() {
      _exerciseRevision++;
      change();
    });
  }

  Widget _cameraView() {
    final camera = _camera;
    if (_cameraError case final error?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    if (camera == null || !camera.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return ExerciseV2CameraPreview(
      controller: camera,
      overlay: ValueListenableBuilder<Map<int, Offset>>(
        valueListenable: _displayPoints,
        builder:
            (context, points, child) => CustomPaint(
              painter: _BrowPointsPainter(
                points,
                mirrorX: _mirrorPoints,
                eyeClose: widget.usesEyeLandmarks,
                strongSqueeze: widget.eyeClose,
                smile: widget.smile,
              ),
              child: child,
            ),
        child: const SizedBox.expand(),
      ),
    );
  }

  String get _eyeCloseTrackingInstruction => switch (_logic.eyeCloseStep) {
    EyeCloseStep.open => 'Откройте оба глаза и немного подержите их открытыми.',
    EyeCloseStep.gentle =>
      'Сомкните оба глаза спокойно, без усилия, и немного удерживайте.',
    EyeCloseStep.strong =>
      'Теперь крепко зажмурьте оба глаза и удерживайте до зачёта.',
    EyeCloseStep.reopen => 'Повтор засчитан. Откройте глаза перед следующим.',
  };

  String get _instruction {
    if (_connectionError != null) return _connectionError!;
    if (_faceMessage != null) return _faceMessage!;
    if (_logic.error != null) return _logic.error!;
    if (widget.smile) {
      return switch (_logic.phase) {
        BrowPhase.idle => 'Смотрите прямо в камеру и расслабьте рот.',
        BrowPhase.neutral => 'Держите рот в обычном положении, без улыбки.',
        BrowPhase.readyForMax =>
          'Улыбнитесь максимально комфортно и удерживайте.',
        BrowPhase.maximum => 'Удерживайте улыбку для калибровки.',
        BrowPhase.ready => 'Калибровка готова. Расслабьте рот и начните.',
        BrowPhase.tracking =>
          'Расслабьте рот, улыбнитесь и удерживайте, затем снова расслабьте.',
        BrowPhase.done => 'Упражнение выполнено!',
      };
    }
    if (widget.wink) {
      return switch (_logic.phase) {
        BrowPhase.idle => 'Смотрите прямо в камеру с открытыми глазами.',
        BrowPhase.neutral => 'Держите оба глаза открытыми.',
        BrowPhase.readyForMax =>
          'Полностью закройте оба глаза и удерживайте для калибровки.',
        BrowPhase.maximum => 'Держите оба глаза закрытыми.',
        BrowPhase.ready => 'Калибровка готова. Откройте оба глаза и начинайте.',
        BrowPhase.tracking =>
          'Закройте только один глаз, откройте оба, затем подмигните другим.',
        BrowPhase.done => 'Упражнение выполнено!',
      };
    }
    if (widget.squint) {
      return switch (_logic.phase) {
        BrowPhase.idle => 'Смотрите прямо в камеру и расслабьте глаза.',
        BrowPhase.neutral => 'Держите оба глаза открытыми в обычном положении.',
        BrowPhase.readyForMax =>
          'Прищурьте оба глаза, подтягивая нижние веки, и удерживайте.',
        BrowPhase.maximum => 'Удерживайте максимальный прищур обоих глаз.',
        BrowPhase.ready =>
          'Калибровка готова. Откройте глаза и начинайте упражнение.',
        BrowPhase.tracking =>
          'Откройте глаза, прищурьтесь и удерживайте, затем снова откройте глаза.',
        BrowPhase.done => 'Упражнение выполнено!',
      };
    }
    if (widget.blink) {
      return switch (_logic.phase) {
        BrowPhase.idle => 'Смотрите прямо в камеру с открытыми глазами.',
        BrowPhase.neutral => 'Держите оба глаза открытыми.',
        BrowPhase.readyForMax =>
          'Теперь полностью закройте оба глаза и удерживайте.',
        BrowPhase.maximum => 'Держите оба глаза закрытыми.',
        BrowPhase.ready => 'Калибровка готова. Откройте глаза и начните.',
        BrowPhase.tracking => 'Моргните обоими глазами и снова откройте их.',
        BrowPhase.done => 'Упражнение выполнено!',
      };
    }
    if (widget.eyeClose) {
      return switch (_logic.phase) {
        BrowPhase.idle => 'Смотрите прямо в камеру с открытыми глазами.',
        BrowPhase.neutral => 'Держите оба глаза открытыми.',
        BrowPhase.readyForMax =>
          'Теперь крепко закройте оба глаза и удерживайте.',
        BrowPhase.maximum => 'Держите оба глаза крепко закрытыми.',
        BrowPhase.ready =>
          'Калибровка готова. Откройте глаза и начните упражнение.',
        BrowPhase.tracking => _eyeCloseTrackingInstruction,
        BrowPhase.done => 'Упражнение выполнено!',
      };
    }
    if (widget.frown) {
      return switch (_logic.phase) {
        BrowPhase.idle => 'Смотрите прямо в камеру и расслабьте брови.',
        BrowPhase.neutral => 'Держите брови в обычном положении.',
        BrowPhase.readyForMax =>
          'Теперь максимально нахмурьте обе брови и удерживайте.',
        BrowPhase.maximum => 'Держите обе брови максимально нахмуренными.',
        BrowPhase.ready =>
          'Калибровка готова. Расслабьте брови и начните упражнение.',
        BrowPhase.tracking =>
          'Расслабьте брови, затем нахмурьте обе и удерживайте.',
        BrowPhase.done => 'Упражнение выполнено!',
      };
    }
    return switch (_logic.phase) {
      BrowPhase.idle => 'Смотрите прямо в камеру и расслабьте брови.',
      BrowPhase.neutral => 'Держите брови в обычном положении.',
      BrowPhase.readyForMax =>
        'Теперь поднимите обе брови максимально и удерживайте.',
      BrowPhase.maximum => 'Держите обе брови максимально поднятыми.',
      BrowPhase.ready =>
        'Калибровка готова. Опустите брови и начните упражнение.',
      BrowPhase.tracking =>
        'Опустите брови, затем поднимите обе и удерживайте.',
      BrowPhase.done => 'Упражнение выполнено!',
    };
  }

  Widget _progressTile(String label, Color color, double progress) => Row(
    children: [
      SizedBox(width: 130, child: Text(label)),
      Expanded(
        child: LinearProgressIndicator(
          value: progress,
          color: color,
          minHeight: 9,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 42, child: Text('${(progress * 100).round()}%')),
    ],
  );

  Widget _buildAppInterface() {
    final phase = _logic.phase;
    final collecting = phase == BrowPhase.neutral || phase == BrowPhase.maximum;
    return ExerciseV2Layout(
      title:
          widget.wink
              ? 'Подмигивание 2.0'
              : widget.smile
              ? 'Улыбка 2.0'
              : widget.squint
              ? 'Прищур 2.0'
              : widget.blink
              ? 'Поморгать 2.0'
              : widget.eyeClose
              ? 'Закрыть глаза 2.0'
              : widget.frown
              ? 'Нахмурить брови 2.0'
              : 'Поднятие бровей 2.0',
      repetitions: _logic.repetitions,
      goal: _logic.goalRepetitions,
      camera: _showAppCamera ? _cameraView() : null,
      onEnableCamera: () => setState(() => _showAppCamera = true),
      onMirror: () => setState(() => _mirrorPoints = !_mirrorPoints),
      actions: [
        ExerciseV2Action(
          'Обычное положение',
          'assets/exercise/ic_calibrate.png',
          _socketReady ? _beginNeutralCalibration : null,
        ),
        ExerciseV2Action(
          widget.wink
              ? 'Полностью закрыть'
              : widget.smile
              ? 'Максимальная улыбка'
              : widget.squint
              ? 'Максимальный прищур'
              : widget.blink
              ? 'Полностью закрыть'
              : widget.eyeClose
              ? 'Крепко закрыть'
              : widget.frown
              ? 'Максимально нахмурить'
              : 'Максимальный подъём',
          'assets/exercise/ic_save_max.png',
          phase == BrowPhase.readyForMax && _socketReady
              ? _beginMaximumCalibration
              : null,
        ),
        ExerciseV2Action(
          'Начать',
          'assets/exercise/ic_play.png',
          (phase == BrowPhase.ready || phase == BrowPhase.done) && _socketReady
              ? () => _changeTracking(_logic.beginTracking)
              : null,
        ),
        ExerciseV2Action(
          'Пауза',
          'assets/exercise/ic_pause.png',
          phase == BrowPhase.tracking
              ? () => _changeTracking(_logic.pause)
              : null,
        ),
      ],
      instruction: Text(_instruction, textAlign: TextAlign.center),
      calibrationProgress:
          collecting
              ? _logic.calibrationProgress /
                  BrowExerciseLogic.samplesPerCalibration
              : null,
      onRetry:
          _showAppCamera && _cameraError != null
              ? () => unawaited(_initializeCamera())
              : _socketReady
              ? null
              : () => unawaited(_connectSocket()),
      retryLabel:
          _showAppCamera && _cameraError != null
              ? 'Повторить запуск камеры'
              : 'Повторить соединение',
      details:
          _showAppCamera
              ? Column(
                children: [
                  _progressTile(
                    widget.smile
                        ? 'Синий уголок'
                        : widget.usesEyeLandmarks
                        ? 'Синий глаз'
                        : 'Синяя бровь',
                    _blue,
                    _logic.blueProgress,
                  ),
                  const SizedBox(height: 12),
                  _progressTile(
                    widget.smile
                        ? 'Оранжевый уголок'
                        : widget.usesEyeLandmarks
                        ? 'Оранжевый глаз'
                        : 'Оранжевая бровь',
                    _orange,
                    _logic.orangeProgress,
                  ),
                  if (widget.eyeClose) ...[
                    const SizedBox(height: 12),
                    _progressTile(
                      'Зажмуривание',
                      ExerciseV2Layout.green,
                      _logic.squeezeProgress,
                    ),
                  ],
                ],
              )
              : null,
      done: phase == BrowPhase.done,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.appInterface) return _buildAppInterface();
    final phase = _logic.phase;
    final collecting = phase == BrowPhase.neutral || phase == BrowPhase.maximum;
    return Scaffold(
      appBar: AppBar(title: const Text('Поднятие бровей')),
      body: SafeArea(
        child: Column(
          children: [
            Flexible(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ColoredBox(
                    color: Colors.black,
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: _cameraView(),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton.filledTonal(
                      tooltip: 'Отразить точки',
                      onPressed:
                          () => setState(() => _mirrorPoints = !_mirrorPoints),
                      icon: const Icon(Icons.flip),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_instruction, textAlign: TextAlign.center),
                  if (collecting) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value:
                          _logic.calibrationProgress /
                          BrowExerciseLogic.samplesPerCalibration,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _progressTile('Синяя бровь', _blue, _logic.blueProgress),
                  const SizedBox(height: 8),
                  _progressTile(
                    'Оранжевая бровь',
                    _orange,
                    _logic.orangeProgress,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_logic.repetitions}/${_logic.goalRepetitions}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed:
                            _socketReady ? _beginNeutralCalibration : null,
                        child: const Text('1. Обычное положение'),
                      ),
                      OutlinedButton(
                        onPressed:
                            phase == BrowPhase.readyForMax && _socketReady
                                ? _beginMaximumCalibration
                                : null,
                        child: Text(
                          widget.wink
                              ? '2. Полностью закрыть'
                              : widget.squint
                              ? '2. Максимальный прищур'
                              : '2. Максимальный подъём',
                        ),
                      ),
                      FilledButton(
                        onPressed:
                            (phase == BrowPhase.ready ||
                                        phase == BrowPhase.done) &&
                                    _socketReady
                                ? () => _changeTracking(_logic.beginTracking)
                                : null,
                        child: const Text('Начать'),
                      ),
                      if (phase == BrowPhase.tracking)
                        TextButton(
                          onPressed: () => _changeTracking(_logic.pause),
                          child: const Text('Пауза'),
                        ),
                      if (!_socketReady)
                        TextButton(
                          onPressed: () => unawaited(_connectSocket()),
                          child: const Text('Повторить соединение'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _responseTimeout?.cancel();
    _displayPoints.dispose();
    unawaited(_socketSubscription?.cancel());
    unawaited(_channel?.sink.close());
    unawaited(_camera?.dispose());
    if (!_tabletCamera) {
      unawaited(
        SystemChrome.setPreferredOrientations(DeviceOrientation.values),
      );
    }
    super.dispose();
  }
}

class _BrowPointsPainter extends CustomPainter {
  const _BrowPointsPainter(
    this.points, {
    required this.mirrorX,
    required this.eyeClose,
    required this.strongSqueeze,
    required this.smile,
  });

  final Map<int, Offset> points;
  final bool mirrorX;
  final bool eyeClose;
  final bool strongSqueeze;
  final bool smile;

  static const _blueBrows = [53, 52, 65];
  static const _blueEyes = [33, 133];
  static const _orangeBrows = [283, 282, 295];
  static const _orangeEyes = [263, 362];

  @override
  void paint(Canvas canvas, Size size) {
    Offset? position(int index) {
      final point = points[index];
      if (point == null ||
          point.dx < 0 ||
          point.dx > 1 ||
          point.dy < 0 ||
          point.dy > 1) {
        return null;
      }
      return Offset(
        (mirrorX ? 1 - point.dx : point.dx) * size.width,
        point.dy * size.height,
      );
    }

    void drawGroup(List<int> brows, List<int> eyes, Color color) {
      final line =
          Paint()
            ..color = color.withValues(alpha: 0.75)
            ..strokeWidth = 2;
      final firstCorner = position(eyes[0]);
      final secondCorner = position(eyes[1]);
      if (firstCorner != null && secondCorner != null) {
        canvas.drawLine(firstCorner, secondCorner, line);
        final eyeCenter = (firstCorner + secondCorner) / 2;
        for (final index in brows) {
          final brow = position(index);
          if (brow != null) canvas.drawLine(brow, eyeCenter, line);
        }
      }
      for (final index in [...brows, ...eyes]) {
        final center = position(index);
        if (center == null) continue;
        final radius = brows.contains(index) ? 5.0 : 3.5;
        canvas.drawCircle(center, radius + 1.5, Paint()..color = Colors.black);
        canvas.drawCircle(center, radius, Paint()..color = color);
      }
    }

    void drawEye(List<int> indices, Color color) {
      final top = position(indices[0]);
      final bottom = position(indices[1]);
      if (top != null && bottom != null) {
        canvas.drawLine(
          top,
          bottom,
          Paint()
            ..color = color.withValues(alpha: 0.75)
            ..strokeWidth = 2,
        );
      }
      for (final index in indices) {
        final center = position(index);
        if (center == null) continue;
        canvas.drawCircle(center, 5, Paint()..color = Colors.black);
        canvas.drawCircle(center, 3.5, Paint()..color = color);
      }
    }

    if (smile) {
      final center = position(13);
      for (final (index, color) in [
        (61, const Color(0xFF00BCEB)),
        (291, const Color(0xFFFF8A31)),
      ]) {
        final corner = position(index);
        if (center != null && corner != null) {
          canvas.drawLine(
            center,
            corner,
            Paint()
              ..color = color.withValues(alpha: 0.75)
              ..strokeWidth = 2,
          );
        }
        if (corner != null) {
          canvas.drawCircle(corner, 6.5, Paint()..color = Colors.black);
          canvas.drawCircle(corner, 5, Paint()..color = color);
        }
      }
      if (center != null) {
        canvas.drawCircle(center, 5, Paint()..color = Colors.black);
        canvas.drawCircle(center, 3.5, Paint()..color = Colors.white);
      }
      for (final (indices, color) in [
        ([33, 133], const Color(0xFF00BCEB)),
        ([263, 362], const Color(0xFFFF8A31)),
      ]) {
        for (final index in indices) {
          final eye = position(index);
          if (eye == null) continue;
          canvas.drawCircle(eye, 4.5, Paint()..color = Colors.black);
          canvas.drawCircle(eye, 3, Paint()..color = color);
        }
      }
      return;
    }

    if (eyeClose) {
      drawEye([
        159,
        145,
        33,
        133,
        if (strongSqueeze) ...[111, 117],
      ], const Color(0xFF00BCEB));
      drawEye([
        386,
        374,
        263,
        362,
        if (strongSqueeze) ...[340, 346],
      ], const Color(0xFFFF8A31));
      return;
    }

    drawGroup(_blueBrows, _blueEyes, const Color(0xFF00BCEB));
    drawGroup(_orangeBrows, _orangeEyes, const Color(0xFFFF8A31));
  }

  @override
  bool shouldRepaint(covariant _BrowPointsPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.mirrorX != mirrorX ||
      oldDelegate.eyeClose != eyeClose ||
      oldDelegate.strongSqueeze != strongSqueeze ||
      oldDelegate.smile != smile;
}
