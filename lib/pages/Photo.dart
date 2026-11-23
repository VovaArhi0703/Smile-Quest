import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../layout/adaptive_layout.dart';
import '../layout/tablet_camera_workspace.dart';
import '../exercise_sections/exercise_v2_layout.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../photo_upload_service.dart';
import '../widget/exercise_picker_sheet.dart';

class CameraExerciseScreen extends StatefulWidget {
  const CameraExerciseScreen({super.key});

  @override
  State<CameraExerciseScreen> createState() => _CameraExerciseScreenState();
}

class _CameraExerciseScreenState extends State<CameraExerciseScreen> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey();
  // TODO: замени пути на свои PNG
  static const String _kBackPng = 'assets/newimage/arrow_left.png';
  static const String _kFilterPng = 'assets/newimage/filter.png';

  static const Color _kBg = Color(0xFFF9F9F9);
  static const Color _kWhite = Colors.white;
  static const Color _kGreen = Color(0xFF81C784);
  static const Color _kBlack = Color(0xFF000000);

  CameraController? _controller;
  List<CameraDescription>? _cameras;

  XFile? _capturedImage;
  Uint8List? _correctedImageBytes;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isSaving = false;
  String? _cameraError;

  String? selectedSection;
  String? selectedExercise;

  final Map<String, List<String>> sectionExercises = {
    'Упражнения для мимических мышц': [
      'Поднять брови вверх, удержать',
      'Нахмурить брови, удержать',
      'Закрыть глаза (крепко-слабо)',
      'Поморгать',
      'Двигать глазным яблоком, закрыв глаза',
      'Прищуриваться, подтягивая нижнее веко',
      'Поочередно закрывать правый и левый глаз',
      'Сморщить нос',
      'Раздувать ноздри, шевелить носом. Втягивать ноздри',
      'Звук "М"',
      'Звук "О"',
      'Плевать',
      'Звуки "У", "А"',
      'Рот открыт, звуки "О", "А"',
      'Произносить "Т", "П", "Р", "У"',
    ],
    'Упражнения для щек': [
      'Надуть обе щеки',
      'Втянуть обе щеки',
      'Надуть правую щеку, затем левую',
      'Чередовать 1 и 2 задание',
      'Имитировать полоскание',
    ],
    'Упражнения для нижней челюсти': [
      'Рот приоткрыть, широко открыть, плотно закрыть',
      'Движения нижней челюстью вперед, назад, вправо, влево, круговые движения',
      'Имитация жевания с открытым/ закрытым ртом',
    ],
    'Упражнения для губ': [
      'Вытянуть губы вперед - трубочкой',
      'Движения "трубочкой"',
      'Трубочка-улыбочка поочередно',
      'Улыбка',
      'Длинное задание',
      'Захватывать зубами верхние и нижние губы',
      'Оскалиться',
    ],
    'Упражнения для языка': [
      'Открыть рот, язык поднять, опустить',
      'Рот открыт, язык вверх-вниз',
      'Рот открыть, язык к правому уху, к левому',
      'Облизать нижнюю, затем верхнюю губу',
      'Облизать губы по кругу',
      'Языком погладить твердое небо',
      'Длинное задание',
    ],
    'Дополнительные упражнения': [
      'Поцокать, как лошадка',
      'Брать с ладони мелкие куски яблока',
      'Вибрация губ (фыркать)',
      'Длинное задание',
    ],
  };

  bool get _hasExerciseSelected =>
      selectedSection != null && selectedExercise != null;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) setState(() => _cameraError = 'Камера не найдена');
        return;
      }

      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();

      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (_) {
      if (mounted) setState(() => _cameraError = 'Не удалось открыть камеру');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_isCapturing ||
        _isSaving ||
        _controller == null ||
        !_controller!.value.isInitialized)
      return;
    _isCapturing = true;
    final normalizeOrientation = AppLayout.isTablet(context);
    try {
      final image = await _controller!.takePicture();
      final correctedBytes = await _flipImageHorizontally(
        File(image.path),
        normalizeOrientation: normalizeOrientation,
      );

      if (!mounted) return;
      setState(() {
        _capturedImage = image;
        _correctedImageBytes = correctedBytes;
      });
    } catch (_) {
      _showMessage('Не удалось сделать фото. Попробуйте ещё раз.');
    } finally {
      _isCapturing = false;
    }
  }

  Future<Uint8List> _flipImageHorizontally(
    File file, {
    bool normalizeOrientation = false,
  }) async {
    final bytes = await file.readAsBytes();
    final originalImage = img.decodeImage(bytes);
    if (originalImage == null)
      throw const FormatException('Invalid camera image');
    final flippedImage = img.flipHorizontal(
      normalizeOrientation ? img.bakeOrientation(originalImage) : originalImage,
    );
    return Uint8List.fromList(img.encodeJpg(flippedImage));
  }

  void _resetPhoto({bool force = false}) {
    if (_isSaving && !force) return;
    setState(() {
      _capturedImage = null;
      _correctedImageBytes = null;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _savePhoto() async {
    if (_isSaving) return;
    if (_correctedImageBytes == null) {
      _showMessage('Сначала сделайте фото');
      return;
    }
    if (!_hasExerciseSelected) {
      _showMessage('Выберите раздел и упражнение в фильтре');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await PhotoUploadService.uploadPhoto(
        context,
        _correctedImageBytes!,
        selectedSection!,
        selectedExercise!,
      );

      if (!mounted) return;
      _showMessage('Фото сохранено. Начислено 15 XP и 10 монет');
      _resetPhoto(force: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Не удалось сохранить фото. Попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> showSectionBottomSheet() async {
    final selection = await showExercisePicker(
      context,
      sectionExercises: sectionExercises,
      initialSection: selectedSection,
      initialExercise: selectedExercise,
    );
    if (!mounted || selection == null) return;
    setState(() {
      selectedSection = selection.section;
      selectedExercise = selection.exercise;
    });
  }

  Widget _headerButton({
    required String asset,
    required VoidCallback onTap,
    required Color backgroundColor,
    Color? iconTint,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10.36),
        ),
        child: Image.asset(
          asset,
          width: 18,
          height: 18,
          fit: BoxFit.contain,
          color: iconTint,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 130,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
        child: Row(
          children: [
            _headerButton(
              asset: _kBackPng,
              onTap: () => Navigator.maybePop(context),
              backgroundColor: _kWhite,
              iconTint: null,
            ),
            const Spacer(),
            const Text(
              'Выбери упражнение',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                height: 21 / 18,
                color: _kBlack,
              ),
            ),
            const Spacer(),
            _headerButton(
              asset: _kFilterPng,
              onTap: showSectionBottomSheet,
              backgroundColor: _hasExerciseSelected ? _kGreen : _kWhite,
              iconTint: _hasExerciseSelected ? Colors.white : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreviewCropped() {
    if (_cameraError != null) {
      return Center(
        child: Text(_cameraError!, style: const TextStyle(color: Colors.white)),
      );
    }
    if (!_isInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final controller = _controller!;
    if (AppLayout.isTablet(context)) {
      return ExerciseV2CameraPreview(
        controller: controller,
        overlay: const SizedBox.expand(),
      );
    }
    final previewSize = controller.value.previewSize;

    final child =
        (previewSize == null)
            ? CameraPreview(controller)
            : SizedBox(
              width: previewSize.height,
              height: previewSize.width,
              child: CameraPreview(controller),
            );

    return ClipRect(child: FittedBox(fit: BoxFit.cover, child: child));
  }

  Widget _buildCameraArea() {
    return SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          color: Colors.black,
          child:
              _capturedImage != null
                  ? (_correctedImageBytes != null
                      ? Image.memory(_correctedImageBytes!, fit: BoxFit.cover)
                      : const Center(child: CircularProgressIndicator()))
                  : _buildCameraPreviewCropped(),
        ),
      ),
    );
  }

  Widget _pillButton({
    required String text,
    required double width,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      height: 37,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kGreen,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            height: 21 / 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    if (AppLayout.isTablet(context)) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children:
            _capturedImage == null
                ? [
                  FilledButton.icon(
                    onPressed: _takePicture,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Сделать фото'),
                  ),
                ]
                : [
                  OutlinedButton(
                    onPressed: () => _resetPhoto(),
                    child: const Text('Сбросить'),
                  ),
                  FilledButton(
                    onPressed: _savePhoto,
                    child: const Text('Сохранить'),
                  ),
                ],
      );
    }
    return SizedBox(
      height: 62,
      width: double.infinity,
      child: Center(
        child:
            _capturedImage == null
                ? _pillButton(
                  text: 'Сделать фото',
                  width: 150,
                  onTap: _takePicture,
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pillButton(
                      text: 'Сбросить',
                      width: 123,
                      onTap: () => _resetPhoto(),
                    ),
                    const SizedBox(width: 47),
                    _pillButton(
                      text: 'Сохранить',
                      width: 123,
                      onTap: _savePhoto,
                    ),
                  ],
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppLayout.isTablet(context)) {
      return ScaffoldMessenger(
        key: _messengerKey,
        child: TabletCameraWorkspace(
          header: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabletHeader(
              title: 'Сделать фото',
              onBack: () => Navigator.maybePop(context),
              actions: [
                IconButton.filledTonal(
                  tooltip: 'Выбрать упражнение',
                  onPressed: showSectionBottomSheet,
                  icon: const Icon(Icons.filter_list),
                ),
              ],
            ),
          ),
          preview: _buildCameraArea(),
          panel: TabletCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Фото для дневника',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Выбери раздел и упражнение, затем сделай снимок. Перед сохранением его можно переснять.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: showSectionBottomSheet,
                  icon: const Icon(Icons.filter_list),
                  label: Text(
                    _hasExerciseSelected
                        ? 'Изменить упражнение'
                        : 'Выбрать упражнение',
                  ),
                ),
                const SizedBox(height: 16),
                _buildBottomControls(),
              ],
            ),
          ),
        ),
      );
    }
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Column(
          children: [
            _buildHeader(),
            _buildCameraArea(),
            const SizedBox(height: 20),
            _buildBottomControls(),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }
}
