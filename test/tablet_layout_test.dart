import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera/camera.dart' as camera;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled2/exercise_sections/exercise_v2_layout.dart';
import 'package:untitled2/exercise_sections/face_exercises/face_1_exercises.dart';
import 'package:untitled2/layout/adaptive_layout.dart';
import 'package:untitled2/layout/tablet_navigation.dart';
import 'package:untitled2/main.dart';
import 'package:untitled2/pages/main_shell.dart';
import 'package:untitled2/tasks/task_page.dart';
import 'package:untitled2/tasks/task_store.dart';

import 'support/ui_fonts.dart';

class _UnavailableCamera extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async => [];

  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.black);
}

void tabletSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

Future<void> capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['TABLET_SCREENSHOT_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('tablet-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  late CameraPlatform previousCamera;
  setUp(() {
    previousCamera = CameraPlatform.instance;
    CameraPlatform.instance = _UnavailableCamera();
  });
  setUpAll(() async {
    await initializeDateFormatting('ru_RU');
    await loadUiTestFonts();
  });
  tearDown(() {
    CameraPlatform.instance = previousCamera;
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  const routes = {
    'welcome': '/welcome',
    'sign_in': '/',
    'sign_up': '/signup',
    'home': '/home',
    'sections': '/exercise_sections',
    'profile': '/profile_first',
    'photos': '/photo_diary',
    'tasks': '/tasks',
    'settings': '/settings',
    'hall': '/hall',
    'avatar': '/avatar',
    'photo_camera': '/photo',
    'email_verification': '/email-verification',
    'legacy_profile': '/profile',
    'forgot_password': '/forgot-password',
    'change_password': '/password-page',
    'reset_password': '/reset-password',
    'privacy': '/privacy',
    'terms': '/terms',
    'face_catalog': '/face_exercises',
    'lips_catalog': '/lips_exercises',
    'cheeks_catalog': '/cheeks_exercises',
    'jaw_catalog': '/jaw_exercises',
    'tongue_catalog': '/tongue_exercises',
    'additional_catalog': '/additional_exercises',
    'instruction': '/face_2',
    'exercise': '/face_2_v2_exercises',
  };
  for (final size in [
    const Size(600, 960),
    const Size(768, 1024),
    const Size(1280, 800),
  ]) {
    for (final route in routes.entries) {
      testWidgets('${route.key} fits ${size.width} x ${size.height}', (
        tester,
      ) async {
        tabletSize(tester, size);
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          const RepaintBoundary(
            key: ValueKey('tablet-capture'),
            child: MyApp(),
          ),
        );
        navigatorKey.currentState!.pushNamed(route.value);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, '${route.key}_${size.width.toInt()}');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }

  testWidgets(
    'all exercise instructions, placeholders and retained 2.0 screens fit both tablet orientations',
    (tester) async {
      const legacyCameraRoutes = {
        '/face_1_exercises',
        '/face_2_exercises',
        '/face_3_exercises',
        '/face_4_exercises',
        '/face_6_exercises',
        '/face_7_exercises',
        '/lips_4_exercises',
      };
      SharedPreferences.setMockInitialValues({});
      tabletSize(tester, const Size(768, 1024));
      await tester.pumpWidget(const MyApp());
      final routes =
          tester
              .widget<MaterialApp>(find.byType(MaterialApp))
              .routes!
              .keys
              .where(
                (route) =>
                    RegExp(
                      r'^/(face|lips|cheeks|tongue|jaw|additional)_\d+(_v2)?(_exercises)?$',
                    ).hasMatch(route) &&
                    !legacyCameraRoutes.contains(route),
              )
              .toList();
      for (final size in [const Size(768, 1024), const Size(1280, 800)]) {
        tabletSize(tester, size);
        for (final route in routes) {
          navigatorKey.currentState!.pushNamed(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$route at $size');
          navigatorKey.currentState!.pop();
          await tester.pumpAndSettle();
        }
      }
    },
  );

  testWidgets(
    'tablet exercise rotation keeps its state and does not request portrait lock',
    (tester) async {
      final orientationCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientationCalls.add(call);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      tabletSize(tester, const Size(768, 1024));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      navigatorKey.currentState!.pushNamed('/face_2_v2_exercises');
      await tester.pumpAndSettle();
      final exercise = tester.element(find.byType(Face1Exercises));
      tabletSize(tester, const Size(1280, 800));
      await tester.pumpAndSettle();
      expect(
        identical(exercise, tester.element(find.byType(Face1Exercises))),
        isTrue,
      );
      expect(orientationCalls, isEmpty);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(orientationCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'landmark overlay stays on the portrait viewport while the native camera rotates',
    (tester) async {
      tabletSize(tester, const Size(1280, 800));
      final controller = camera.CameraController(
        const CameraDescription(
          name: 'front',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 270,
        ),
        camera.ResolutionPreset.high,
      );
      controller.value = controller.value.copyWith(
        isInitialized: true,
        previewSize: const Size(640, 480),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: ExerciseV2CameraPreview(
                controller: controller,
                overlay: const SizedBox.expand(
                  key: ValueKey('visible-landmarks'),
                ),
              ),
            ),
          ),
        ),
      );
      for (final orientation in DeviceOrientation.values) {
        controller.value = controller.value.copyWith(
          deviceOrientation: orientation,
        );
        await tester.pump();
        expect(
          tester.getSize(find.byKey(const ValueKey('visible-landmarks'))),
          const Size(300, 400),
        );
        expect(
          tester.getSize(find.byType(camera.CameraPreview)),
          orientation == DeviceOrientation.landscapeLeft ||
                  orientation == DeviceOrientation.landscapeRight
              ? const Size(640, 480)
              : const Size(480, 640),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      // The test controller has no native camera to dispose.
      controller.value = controller.value.copyWith(isInitialized: false);
    },
  );

  testWidgets(
    'tablet navigation stays mounted and preserves the selected tab on rotation',
    (tester) async {
      tabletSize(tester, const Size(768, 1024));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: MainShell()));
      await tester.pumpAndSettle();
      final navigation = tester.element(find.byType(TabletNavigation));
      await tester.tap(find.byKey(const ValueKey('tablet-tab-3')));
      await tester.pumpAndSettle();
      expect(find.text('Настройки профиля').hitTestable(), findsOneWidget);
      tabletSize(tester, const Size(1024, 768));
      await tester.pumpAndSettle();
      expect(
        identical(navigation, tester.element(find.byType(TabletNavigation))),
        isTrue,
      );
      expect(find.text('Настройки профиля').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'camera viewport remains 3:4 and exercise controls work in both orientations',
    (tester) async {
      for (final size in [const Size(768, 1024), const Size(1280, 800)]) {
        tabletSize(tester, size);
        var neutralCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: ExerciseV2Layout(
              title: 'Нахмурить брови 2.0',
              repetitions: 3,
              goal: 10,
              instruction: const Text(
                'Удерживай брови в максимальном положении',
              ),
              onEnableCamera: () {},
              camera: const ColoredBox(color: Colors.black),
              actions: [
                ExerciseV2Action(
                  'Обычное положение',
                  'assets/exercise/ic_calibrate.png',
                  () => neutralCalls++,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cameraSize = tester.getSize(
          find.byKey(const ValueKey('tablet-camera-viewport')),
        );
        expect(cameraSize.width / cameraSize.height, closeTo(3 / 4, 0.001));
        final control = find.byType(ExerciseV2Action);
        await tester.ensureVisible(control);
        await tester.tap(
          find.descendant(of: control, matching: find.byType(InkWell)),
        );
        await tester.pump();
        expect(neutralCalls, 1);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('task cards, editor and exercise picker fit a landscape tablet', (
    tester,
  ) async {
    tabletSize(tester, const Size(1280, 800));
    SharedPreferences.setMockInitialValues({});
    final store = TaskStore(accountId: null);
    await store.save([
      const SmileTask(
        id: 'one',
        kind: TaskKind.simple,
        title: 'Поднять брови',
        sectionRoute: '/face_exercises',
        exerciseRoute: '/face_1',
      ),
      const SmileTask(
        id: 'two',
        kind: TaskKind.simple,
        title: 'Улыбнуться',
        sectionRoute: '/lips_exercises',
        exerciseRoute: '/lips_4',
      ),
    ]);
    await tester.pumpWidget(
      const MaterialApp(home: TasksPage(accountId: null)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('one'))).dy,
      tester.getTopLeft(find.byKey(const ValueKey('two'))).dy,
    );
    await tester.tap(find.text('Создать задачу'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(RegExp(r'Задача\s+на день')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать упражнение'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('exercise-picker-content')))
          .width,
      lessThanOrEqualTo(560),
    );
    await tester.tap(find.text('Сбросить'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone landscape uses the phone branch', (tester) async {
    tabletSize(tester, const Size(852, 393));
    late bool isTablet;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            isTablet = AppLayout.isTablet(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(isTablet, isFalse);
  });

  testWidgets(
    'form text survives rotation and remains reachable above the keyboard',
    (tester) async {
      tabletSize(tester, const Size(768, 1024));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      navigatorKey.currentState!.pushNamed('/signup');
      await tester.pumpAndSettle();
      final field = find.byType(TextField).first;
      await tester.enterText(field, 'Тестовый пациент');
      tabletSize(tester, const Size(1280, 800));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.text('Тестовый пациент'), findsOneWidget);
      await tester.ensureVisible(find.text('Создать аккаунт').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final route in [
    '/home',
    '/exercise_sections',
    '/profile_first',
    '/photo_diary',
    '/face_2_v2_exercises',
    '/tasks',
    '/signup',
  ]) {
    testWidgets('larger text fits tablet $route', (tester) async {
      tabletSize(tester, const Size(1024, 768));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      navigatorKey.currentState!.pushNamed(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
