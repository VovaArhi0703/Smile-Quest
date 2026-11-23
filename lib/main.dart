import 'layout/adaptive_layout.dart';
import 'pages/welcome_page.dart';
import 'pages/auth_signin_widget.dart';
import 'pages/auth_signup_widget.dart';
import 'pages/terms_of_service_page.dart';
import 'pages/privacy_policy_page.dart';
import 'pages/email_verification_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/password_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/profile_page.dart';
import 'pages/Photo.dart';
import 'pages/hall_of_fame.dart';
import 'pages/settings_page.dart';
import 'pages/avatar_settings_page.dart';
import 'pages/main_shell.dart';
import 'tasks/task_page.dart';
import 'exercise_sections/tongue_exercises.dart';
import 'exercise_sections/lips_exercises.dart';
import 'exercise_sections/lips_exercises/lips_1.dart';
import 'exercise_sections/lips_exercises/lips_2.dart';
import 'exercise_sections/lips_exercises/lips_3.dart';
import 'exercise_sections/lips_exercises/lips_4.dart';
import 'exercise_sections/lips_exercises/lips_5.dart';
import 'exercise_sections/lips_exercises/lips_6.dart';
import 'exercise_sections/lips_exercises/lips_7.dart';
import 'exercise_sections/tongue_exercises/tongue_1.dart';
import 'exercise_sections/tongue_exercises/tongue_2.dart';
import 'exercise_sections/tongue_exercises/tongue_3.dart';
import 'exercise_sections/tongue_exercises/tongue_4.dart';
import 'exercise_sections/tongue_exercises/tongue_5.dart';
import 'exercise_sections/tongue_exercises/tongue_6.dart';
import 'exercise_sections/tongue_exercises/tongue_7.dart';
import 'exercise_sections/jaw_exercises.dart';
import 'exercise_sections/jaw_exercises/jaw_1.dart';
import 'exercise_sections/jaw_exercises/jaw_2.dart';
import 'exercise_sections/jaw_exercises/jaw_3.dart';
import 'exercise_sections/face_exercises.dart';
import 'exercise_sections/face_exercises/face_1.dart';
import 'exercise_sections/face_exercises/face_2.dart';
import 'exercise_sections/face_exercises/face_3.dart';
import 'exercise_sections/face_exercises/face_4.dart';
import 'exercise_sections/face_exercises/face_5.dart';
import 'exercise_sections/face_exercises/face_6.dart';
import 'exercise_sections/face_exercises/face_7.dart';
import 'exercise_sections/face_exercises/face_8.dart';
import 'exercise_sections/face_exercises/face_9.dart';
import 'exercise_sections/face_exercises/face_10.dart';
import 'exercise_sections/face_exercises/face_11.dart';
import 'exercise_sections/face_exercises/face_12.dart';
import 'exercise_sections/face_exercises/face_13.dart';
import 'exercise_sections/face_exercises/face_14.dart';
import 'exercise_sections/face_exercises/face_15.dart';
import 'exercise_sections/cheeks_exercises.dart';
import 'exercise_sections/cheeks_exercises/cheeks_1.dart';
import 'exercise_sections/cheeks_exercises/cheeks_2.dart';
import 'exercise_sections/cheeks_exercises/cheeks_3.dart';
import 'exercise_sections/cheeks_exercises/cheeks_4.dart';
import 'exercise_sections/cheeks_exercises/cheeks_5.dart';
import 'exercise_sections/additional_exercises.dart';
import 'exercise_sections/additional_exercises/additional_1.dart';
import 'exercise_sections/additional_exercises/additional_2.dart';
import 'exercise_sections/additional_exercises/additional_3.dart';
import 'exercise_sections/additional_exercises/additional_4.dart';

import 'exercise_sections/face_exercises/face_1_exercises.dart';
import 'exercise_sections/face_exercises/face_2_exercises.dart';
import 'exercise_sections/face_exercises/face_3_exercises.dart';
import 'exercise_sections/face_exercises/face_4_exercises.dart';
import 'exercise_sections/face_exercises/face_5_exercises.dart';
import 'exercise_sections/face_exercises/face_6_exercises.dart';
import 'exercise_sections/face_exercises/face_7_exercises.dart';
import 'exercise_sections/face_exercises/face_8_exercises.dart';
import 'exercise_sections/face_exercises/face_9_exercises.dart';
import 'exercise_sections/face_exercises/face_10_exercises.dart';
import 'exercise_sections/face_exercises/face_11_exercises.dart';
import 'exercise_sections/face_exercises/face_12_exercises.dart';
import 'exercise_sections/face_exercises/face_13_exercises.dart';
import 'exercise_sections/face_exercises/face_14_exercises.dart';
import 'exercise_sections/face_exercises/face_15_exercises.dart';
import 'exercise_sections/jaw_exercises/jaw_1_exercises.dart';
import 'exercise_sections/jaw_exercises/jaw_2_exercises.dart';
import 'exercise_sections/jaw_exercises/jaw_3_exercises.dart';
import 'exercise_sections/additional_exercises/additional_1_exercises.dart';
import 'exercise_sections/additional_exercises/additional_2_exercises.dart';
import 'exercise_sections/additional_exercises/additional_3_exercises.dart';
import 'exercise_sections/additional_exercises/additional_4_exercises.dart';
import 'exercise_sections/cheeks_exercises/cheeks_1_exercises.dart';
import 'exercise_sections/cheeks_exercises/cheeks_2_exercises.dart';
import 'exercise_sections/cheeks_exercises/cheeks_3_exercises.dart';
import 'exercise_sections/cheeks_exercises/cheeks_4_exercises.dart';
import 'exercise_sections/cheeks_exercises/cheeks_5_exercises.dart';
import 'exercise_sections/lips_exercises/lips_1_exercises.dart';
import 'exercise_sections/lips_exercises/lips_2_exercises.dart';
import 'exercise_sections/lips_exercises/lips_3_exercises.dart';
import 'exercise_sections/lips_exercises/lips_4_exercises.dart';
import 'exercise_sections/lips_exercises/lips_5_exercises.dart';
import 'exercise_sections/lips_exercises/lips_6_exercises.dart';
import 'exercise_sections/lips_exercises/lips_7_exercises.dart';
import 'exercise_sections/tongue_exercises/tongue_1_exercises.dart';
import 'exercise_sections/tongue_exercises/tongue_2_exercises.dart';
import 'exercise_sections/tongue_exercises/tongue_3_exercises.dart';
import 'exercise_sections/tongue_exercises/tongue_4_exercises.dart';
import 'exercise_sections/tongue_exercises/tongue_5_exercises.dart';
import 'exercise_sections/tongue_exercises/tongue_6_exercises.dart';
import 'exercise_sections/tongue_exercises/tongue_7_exercises.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'user_progress_service.dart';
import 'exercise_socket.dart';
import 'local_exercise_test_app.dart';
import 'package:intl/date_symbol_data_local.dart'; // Для локализации календаря

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// контрольная точка 1
void main() async {
  // подключение базы данных
  WidgetsFlutterBinding.ensureInitialized();
  if (localExerciseTestMode) {
    runApp(const LocalExerciseTestApp());
    return;
  }
  final exerciseUri = Uri.tryParse(exerciseWebSocketUrl);
  final exerciseUrlInvalid =
      kReleaseMode &&
      (exerciseUri?.scheme != 'wss' || (exerciseUri?.host.isEmpty ?? true));
  if (exerciseUrlInvalid) {
    final message =
        'Сервер упражнений не настроен. Укажите защищённый EXERCISE_WS_URL при сборке приложения.';
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text(message)))));
    return;
  }
  await AppApi.instance.restore();
  if (AppApi.instance.isSignedIn) {
    try {
      await UserProgressService.restoreFromServer();
    } catch (_) {}
  }
  await initializeDateFormatting(
    'ru_RU',
    null,
  ); // Инициализация локализации для календаря

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smile Quest',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      builder: (context, child) {
        if (!AppLayout.isTablet(context)) return child!;
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: const Color(0xFF66BB6A),
              onPrimary: Colors.white,
              primaryContainer: const Color(0xFFECFFDE),
              onPrimaryContainer: const Color(0xFF315E36),
              secondaryContainer: const Color(0xFFECFFDE),
              onSecondaryContainer: const Color(0xFF315E36),
            ),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoPageTransitionsBuilder(),
            TargetPlatform.iOS: NoPageTransitionsBuilder(),
            TargetPlatform.windows: NoPageTransitionsBuilder(),
          },
        ),
      ),
      // Build exactly one initial route so Android Back never reveals sign-in
      // behind an already authenticated home screen.
      initialRoute: AppApi.instance.isSignedIn ? '/home' : '/welcome',
      onGenerateInitialRoutes:
          (initialRouteName) => [
            MaterialPageRoute<dynamic>(
              settings: RouteSettings(name: initialRouteName),
              builder:
                  (_) =>
                      AppApi.instance.isSignedIn
                          ? const MainShell()
                          : const TabletFormSurface(child: WelcomePage()),
            ),
          ],
      routes: {
        '/welcome': (context) => TabletFormSurface(child: const WelcomePage()),
        '/profile_first': (context) => const MainShell(initialIndex: 3),
        '/': (context) => TabletFormSurface(child: AuthSignInWidget()),
        '/signup': (context) => TabletFormSurface(child: AuthSignUpWidget()),
        '/terms': (context) => TabletFormSurface(child: TermsOfServicePage()),
        '/privacy': (context) => TabletFormSurface(child: PrivacyPolicyPage()),
        '/email-verification':
            (context) => TabletFormSurface(child: EmailVerificationPage()),
        '/forgot-password':
            (context) => TabletFormSurface(child: ForgotPasswordPage()),
        '/password-page':
            (context) => TabletFormSurface(child: ChangePasswordPage()),
        '/reset-password':
            (context) => TabletFormSurface(child: ResetPasswordPage()),
        '/home': (context) => const MainShell(),
        '/tasks':
            (context) => TasksPage(accountId: AppApi.instance.currentUser?.id),
        '/exercise_sections': (context) => const MainShell(initialIndex: 1),
        '/profile': (context) => TabletFormSurface(child: ProfilePage()),
        '/avatar': (context) => AvatarSettingsPage(),
        '/hall': (context) => HallOfFamePage(),
        '/photo': (context) => CameraExerciseScreen(),
        '/photo_diary': (context) => const MainShell(initialIndex: 2),
        '/settings': (context) => TabletFormSurface(child: SettingsPage()),
        '/tongue_1': (context) => Tongue1(),
        '/tongue_2': (context) => Tongue2(),
        '/tongue_3': (context) => Tongue3(),
        '/tongue_4': (context) => Tongue4(),
        '/tongue_5': (context) => Tongue5(),
        '/tongue_6': (context) => Tongue6(),
        '/tongue_7': (context) => Tongue7(),
        '/tongue_exercises': (context) => TongueExercisesPage(),
        '/lips_exercises': (context) => LipsExercisesPage(),
        '/lips_1': (context) => Lips1(),
        '/lips_2': (context) => Lips2(),
        '/lips_3': (context) => Lips3(),
        '/lips_4': (context) => Lips4(),
        '/lips_5': (context) => Lips5(),
        '/lips_6': (context) => Lips6(),
        '/lips_7': (context) => Lips7(),
        // Saved tasks and the Home shortcut may still refer to removed cards.
        for (var number = 8; number <= 12; number++)
          '/lips_$number': (context) => LipsExercisesPage(),
        '/jaw_exercises': (context) => JawExercisesPage(),
        '/jaw_1': (context) => Jaw1(),
        '/jaw_2': (context) => Jaw2(),
        '/jaw_3': (context) => Jaw3(),
        '/face_exercises': (context) => FaceExercisesPage(),
        '/face_1': (context) => Face1(),
        '/face_2': (context) => Face2(),
        '/face_3': (context) => Face3(),
        '/face_4': (context) => Face4(),
        '/face_5': (context) => Face5(),
        '/face_6': (context) => Face6(),
        '/face_7': (context) => Face7(),
        '/face_8': (context) => Face8(),
        '/face_9': (context) => Face9(),
        '/face_10': (context) => Face10(),
        '/face_11': (context) => Face11(),
        '/face_12': (context) => Face12(),
        '/face_13': (context) => Face13(),
        '/face_14': (context) => Face14(),
        '/face_15': (context) => Face15(),
        '/cheeks_exercises': (context) => CheeksExercisesPage(),
        '/cheeks_1': (context) => Cheeks1(),
        '/cheeks_2': (context) => Cheeks2(),
        '/cheeks_3': (context) => Cheeks3(),
        '/cheeks_4': (context) => Cheeks4(),
        '/cheeks_5': (context) => Cheeks5(),
        '/additional_exercises': (context) => AdditionalExercisesPage(),
        '/additional_1': (context) => Additional1(),
        '/additional_2': (context) => Additional2(),
        '/additional_3': (context) => Additional3(),
        '/additional_4': (context) => Additional4(),
        '/face_1_exercises':
            (context) => TabletFormSurface(child: Face1Exercises()),
        '/face_1_v2_exercises':
            (context) => const Face1Exercises.appInterface(),
        '/face_2_exercises':
            (context) => TabletFormSurface(child: Face2Exercises()),
        '/face_2_v2_exercises': (context) => const Face1Exercises.frown(),
        '/face_3_exercises':
            (context) => TabletFormSurface(child: Face3Exercises()),
        '/face_3_v2_exercises': (context) => const Face1Exercises.eyeClose(),
        '/face_4_exercises':
            (context) => TabletFormSurface(child: Face4Exercises()),
        '/face_4_v2_exercises': (context) => const Face1Exercises.blink(),
        '/face_5_exercises':
            (context) => TabletFormSurface(child: Face5Exercises()),
        '/face_6_exercises':
            (context) => TabletFormSurface(child: Face6Exercises()),
        '/face_6_v2_exercises': (context) => const Face1Exercises.squint(),
        '/face_7_exercises':
            (context) => TabletFormSurface(child: Face7Exercises()),
        '/face_7_v2_exercises': (context) => const Face1Exercises.wink(),
        '/face_8_exercises':
            (context) => TabletFormSurface(child: Face8Exercises()),
        '/face_9_exercises':
            (context) => TabletFormSurface(child: Face9Exercises()),
        '/face_10_exercises':
            (context) => TabletFormSurface(child: Face10Exercises()),
        '/face_11_exercises':
            (context) => TabletFormSurface(child: Face11Exercises()),
        '/face_12_exercises':
            (context) => TabletFormSurface(child: Face12Exercises()),
        '/face_13_exercises':
            (context) => TabletFormSurface(child: Face13Exercises()),
        '/face_14_exercises':
            (context) => TabletFormSurface(child: Face14Exercises()),
        '/face_15_exercises':
            (context) => TabletFormSurface(child: Face15Exercises()),
        '/jaw_1_exercises':
            (context) => TabletFormSurface(child: Jaw1Exercises()),
        '/jaw_2_exercises':
            (context) => TabletFormSurface(child: Jaw2Exercises()),
        '/jaw_3_exercises':
            (context) => TabletFormSurface(child: Jaw3Exercises()),
        '/additional_1_exercises':
            (context) => TabletFormSurface(child: Additional1Exercises()),
        '/additional_2_exercises':
            (context) => TabletFormSurface(child: Additional2Exercises()),
        '/additional_3_exercises':
            (context) => TabletFormSurface(child: Additional3Exercises()),
        '/additional_4_exercises':
            (context) => TabletFormSurface(child: Additional4Exercises()),
        '/cheeks_1_exercises':
            (context) => TabletFormSurface(child: Cheeks1Exercises()),
        '/cheeks_2_exercises':
            (context) => TabletFormSurface(child: Cheeks2Exercises()),
        '/cheeks_3_exercises':
            (context) => TabletFormSurface(child: Cheeks3Exercises()),
        '/cheeks_4_exercises':
            (context) => TabletFormSurface(child: Cheeks4Exercises()),
        '/cheeks_5_exercises':
            (context) => TabletFormSurface(child: Cheeks5Exercises()),
        '/lips_1_exercises':
            (context) => TabletFormSurface(child: Lips1Exercises()),
        '/lips_2_exercises':
            (context) => TabletFormSurface(child: Lips2Exercises()),
        '/lips_3_exercises':
            (context) => TabletFormSurface(child: Lips3Exercises()),
        '/lips_4_exercises':
            (context) => TabletFormSurface(child: Lips4Exercises()),
        '/lips_4_v2_exercises': (context) => const Face1Exercises.smile(),
        '/lips_5_exercises':
            (context) => TabletFormSurface(child: Lips5Exercises()),
        '/lips_6_exercises':
            (context) => TabletFormSurface(child: Lips6Exercises()),
        '/lips_7_exercises':
            (context) => TabletFormSurface(child: Lips7Exercises()),
        '/tongue_1_exercises':
            (context) => TabletFormSurface(child: Tongue1Exercises()),
        '/tongue_2_exercises':
            (context) => TabletFormSurface(child: Tongue2Exercises()),
        '/tongue_3_exercises':
            (context) => TabletFormSurface(child: Tongue3Exercises()),
        '/tongue_4_exercises':
            (context) => TabletFormSurface(child: Tongue4Exercises()),
        '/tongue_5_exercises':
            (context) => TabletFormSurface(child: Tongue5Exercises()),
        '/tongue_6_exercises':
            (context) => TabletFormSurface(child: Tongue6Exercises()),
        '/tongue_7_exercises':
            (context) => TabletFormSurface(child: Tongue7Exercises()),
      },
    );
  }
}

class NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
