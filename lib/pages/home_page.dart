import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:untitled2/widget/streak_card.dart';
import 'package:untitled2/widget/task_card_initial.dart';
import 'package:untitled2/widget/tabbar.dart';
import 'package:untitled2/widget/daily_gift_block.dart';
import 'package:untitled2/widget/last_task_card.dart';
import 'main_shell.dart';
import '../layout/adaptive_layout.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // === SharedPreferences keys ===
  static const String _kLastSectionTitle = 'last_section_title';
  static const String _kLastSectionRoute = 'last_section_route';

  static const String _kLastExerciseNumber = 'last_exercise_number';
  static const String _kLastExerciseRoute = 'last_exercise_route';

  int selectedTabIndex = 0;
  final List<String> routes = const [
    '/home',
    '/exercise_sections',
    '/photo_diary',
    '/profile_first',
  ];

  List<int> iconStates01 = [1, 0, 0, 0];

  bool streakCompact = false;

  // === То, что будет отображаться на карточке (по умолчанию как раньше) ===
  String lastCardTitle = 'Упражнение №1';
  String lastCardSubtitle = 'Упражнения для мимики';

  // === Route для кнопки "Продолжить?" (конкретное упражнение) ===
  String? lastExerciseRoute;

  // === Route последнего раздела (для выбора острова) ===
  String? lastSectionRoute;

  @override
  void initState() {
    super.initState();
    _loadLastTask();
  }

  Future<void> _loadLastTask() async {
    final prefs = await SharedPreferences.getInstance();

    final int? exNum = prefs.getInt(_kLastExerciseNumber);
    final String? sectionTitle = prefs.getString(_kLastSectionTitle);
    final String? exRoute = prefs.getString(_kLastExerciseRoute);
    final String? sectionRoute = prefs.getString(_kLastSectionRoute);

    if (!mounted) return;

    // Если данных ещё нет — ничего не меняем (останется как раньше).
    if (exNum == null ||
        (sectionTitle == null || sectionTitle.trim().isEmpty)) {
      setState(() {
        lastExerciseRoute = exRoute; // может быть null
        lastSectionRoute = sectionRoute; // может быть null
      });
      return;
    }

    setState(() {
      lastCardTitle = 'Упражнение №$exNum';
      lastCardSubtitle = sectionTitle.trim();
      lastExerciseRoute = exRoute;
      lastSectionRoute = sectionRoute;
    });
  }

  void _onTabSelected(int index) {
    if (widget.embedded) {
      MainShell.maybeOf(context)?.selectTab(index);
      return;
    }
    setState(() => selectedTabIndex = index);

    if (ModalRoute.of(context)?.settings.name != routes[index]) {
      Navigator.of(context).pushNamed(routes[index]);
    }
  }

  void _openTasks() {
    Navigator.of(context).pushNamed('/tasks');
  }

  void _handleTopSwipe(DragEndDetails details) {
    final v = details.primaryVelocity;
    if (v == null) return;

    const double threshold = 250;

    if (v > threshold) {
      if (streakCompact) {
        setState(() => streakCompact = false);
      } else {
        _openTasks();
      }
    } else if (v < -threshold) {
      setState(() => streakCompact = true);
    }
  }

  void _onContinueLastTask() {
    final route = (lastExerciseRoute ?? '').trim();

    if (route.isNotEmpty) {
      Navigator.of(context).pushNamed(route);
    } else {
      // Если route ещё не сохранён — просто ведём в разделы упражнений
      Navigator.of(context).pushNamed('/exercise_sections');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AppLayout.isTablet(context)) return _buildTablet(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenW = constraints.maxWidth;
          const double baseW = 375.0;
          final double scale = (screenW / baseW).clamp(0.85, 1.25);

          final double cardH = 237.0 * scale;

          final double streakExpandedW = 178.0 * scale;
          final double streakCompactW = 74.0 * scale;
          final double taskCardW = 173.0 * scale;

          final double paddingH = 16.0 * scale;
          final double spacing = 8.0 * scale;

          final double streakW =
              streakCompact ? streakCompactW : streakExpandedW;
          final double taskLeft = paddingH + streakW + spacing;

          final cardsBlock = GestureDetector(
            onHorizontalDragEnd: _handleTopSwipe,
            child: Padding(
              padding: EdgeInsets.only(top: 30 * scale),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: cardH,
                    width: screenW,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: paddingH,
                          top: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            width: streakW,
                            height: cardH,
                            child: StreakCard(
                              width: streakW,
                              height: cardH,
                              view:
                                  streakCompact
                                      ? StreakCardView.compact
                                      : StreakCardView.expanded,
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          left: taskLeft,
                          top: 0,
                          width: taskCardW,
                          height: cardH,
                          child: TaskCardInitial(onCreateTask: _openTasks),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Flexible(
                          child: Text(
                            'Свайпни вправо чтобы увидеть ещё задачи',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                              height: 1.0,
                              letterSpacing: 0,
                              color: Color(0xFF777777),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        RotatedBox(
                          quarterTurns: 1,
                          child: SvgPicture.asset(
                            'assets/tasks/swipe_arrow.svg',
                            width: 12,
                            height: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: kBottomNavigationBarHeight + bottomInset + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cardsBlock,
                    SizedBox(height: 8 * scale),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
                      child: const DailyGiftBlock(),
                    ),
                    SizedBox(height: 16 * scale),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
                      child: LastTaskCard(
                        title: lastCardTitle,
                        subtitle: lastCardSubtitle,
                        sectionRoute: lastSectionRoute,
                        onContinue: _onContinueLastTask,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar:
          widget.embedded
              ? null
              : MainTabBar(
                iconStates01: iconStates01,
                selectedIndex: selectedTabIndex,
                onTabSelected: _onTabSelected,
              ),
    );
  }

  Widget _buildTablet(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxContentWidth,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TabletHeader(
                    title: 'Главная',
                    subtitle: 'Твои занятия и достижения',
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final activity = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const StreakCard(width: 196, height: 261),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SizedBox(
                                  height: 261,
                                  child: TabletCard(
                                    padding: 16,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Image.asset(
                                            'assets/tasks/empty_frog.png',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton.icon(
                                          onPressed: _openTasks,
                                          icon: const Icon(Icons.add),
                                          label: const Text('Создать задачу'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          LastTaskCard(
                            title: lastCardTitle,
                            subtitle: lastCardSubtitle,
                            sectionRoute: lastSectionRoute,
                            onContinue: _onContinueLastTask,
                          ),
                        ],
                      );
                      if (constraints.maxWidth >= 850) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: activity),
                            const SizedBox(width: 24),
                            const Expanded(child: DailyGiftBlock()),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          activity,
                          const SizedBox(height: 24),
                          const DailyGiftBlock(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar:
          widget.embedded
              ? null
              : MainTabBar(
                selectedIndex: selectedTabIndex,
                onTabSelected: _onTabSelected,
              ),
    );
  }
}
