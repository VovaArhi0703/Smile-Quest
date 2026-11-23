import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../user_progress_service.dart';

import '../profile_service.dart';
import 'package:untitled2/widget/tabbar.dart';
import 'package:untitled2/widget/exercise_top_bar.dart';
import 'main_shell.dart';
import '../layout/adaptive_layout.dart';

class _Island {
  final String title;
  final String asset;
  final String route;

  // Figma/CSS координаты внутри контейнера 375x1380
  final double x;
  final double y;
  final double w;
  final double h;

  const _Island({
    required this.title,
    required this.asset,
    required this.route,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}

class ExerciseSectionsPage extends StatefulWidget {
  const ExerciseSectionsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ExerciseSectionsPage> createState() => _ExerciseSectionsPageState();
}

class _ExerciseSectionsPageState extends State<ExerciseSectionsPage> {
  // Родительский контейнер из Figma: width=375 height=1380
  static const double _designW = 375.0;
  static const double _designH = 1380.0;

  // === РЕГУЛИРОВКА ВЕРХА КАРТЫ ===
  // Отрицательное значение поднимает карту вверх.
  static const double _mapYOffset = -120.0;

  // === РЕГУЛИРОВКА "ОБРЕЗКИ" СНИЗУ ===
  static const double _bottomCrop = 220.0;

  // Ассет фона дороги
  final String mapRoadAsset = 'assets/exercise/map_road.png';

  // Фон-карта внутри контейнера 375:
  // width=522 height=1353 left=-52 top=68
  static const double _mapX = -52.0;
  static const double _mapY = 68.0;
  static const double _mapW = 522.0;
  static const double _mapH = 1353.0;

  // --- Keys for "last opened section"
  static const String _kLastSectionTitle = 'last_section_title';
  static const String _kLastSectionRoute = 'last_section_route';

  // Острова из CSS (внутри контейнера 375)
  final List<_Island> islands = const [
    _Island(
      title: 'Упражнения для губ',
      asset: 'assets/exercise/island_lips.png',
      route: '/lips_exercises',
      x: 170,
      y: 156.01,
      w: 249,
      h: 254.5,
    ),
    _Island(
      title: 'Упражнения для мимики',
      asset: 'assets/exercise/island_face.png',
      route: '/face_exercises',
      x: 32,
      y: 327,
      w: 244,
      h: 216,
    ),
    _Island(
      title: 'Упражнения для челюсти',
      asset: 'assets/exercise/island_jaw.png',
      route: '/jaw_exercises',
      x: 73,
      y: 539.97,
      w: 260,
      h: 224,
    ),
    _Island(
      title: 'Упражнения для щек',
      asset: 'assets/exercise/island_cheeks.png',
      route: '/cheeks_exercises',
      x: 17,
      y: 749.27,
      w: 274.5,
      h: 255.5,
    ),
    _Island(
      title: 'Упражнения для языка',
      asset: 'assets/exercise/island_tongue.png',
      route: '/tongue_exercises',
      x: 170,
      y: 908,
      w: 253.5,
      h: 267.5,
    ),
    _Island(
      title: 'дополнительные упражнения',
      asset: 'assets/exercise/island_additional.png',
      route: '/additional_exercises',
      x: -36,
      y: 1022,
      w: 241,
      h: 235.5,
    ),
  ];

  int userCoins = 0;
  int userXp = 0;
  int userLevel = 0;

  int selectedTabIndex = 1;

  final List<String> routes = const [
    '/home',
    '/exercise_sections',
    '/photo_diary',
    '/profile_first',
  ];

  final List<int> iconStates01 = [0, 1, 0, 0];

  @override
  void initState() {
    super.initState();
    ProfileService.balance.addListener(_onBalanceChanged);
    _loadStates();
  }

  @override
  void dispose() {
    ProfileService.balance.removeListener(_onBalanceChanged);
    super.dispose();
  }

  void _onBalanceChanged() {
    final value = ProfileService.balance.value;
    if (!mounted || value == null) return;
    setState(() {
      userCoins = value.coins;
      userXp = value.xp;
      userLevel = value.level;
    });
  }

  Future<void> _loadStates() async {
    final List? states = await ProfileService().getStates();
    if (!mounted) return;

    setState(() {
      userCoins = (states?[0] ?? 0) as int;
      userXp = (states?[1] ?? 0) as int;
      userLevel = (states?[2] ?? 0) as int;
    });
  }

  Future<void> _saveOpenedSection(String sectionTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final openedSections = prefs.getStringList('opened_sections') ?? [];
    if (!openedSections.contains(sectionTitle)) {
      openedSections.add(sectionTitle);
      await prefs.setStringList('opened_sections', openedSections);
      await UserProgressService.syncToServer();
    }
  }

  Future<void> _saveLastSection({
    required String title,
    required String route,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastSectionTitle, title);
    await prefs.setString(_kLastSectionRoute, route);
    await UserProgressService.syncToServer();
  }

  void _onTabSelected(int index) {
    if (widget.embedded) {
      MainShell.maybeOf(context)?.selectTab(index);
      return;
    }
    setState(() => selectedTabIndex = index);

    final currentRoute = ModalRoute.of(context)?.settings.name;
    final targetRoute = routes[index];

    if (currentRoute != targetRoute) {
      Navigator.of(context).pushNamed(targetRoute);
    }
  }

  Widget _buildScrollableMap(double screenW) {
    final double scale = (screenW / _designW).clamp(0.85, 1.35);

    // уменьшаем высоту холста на _bottomCrop (в дизайн-пикселях)
    final double canvasH =
        (_designH - _bottomCrop).clamp(0.0, double.infinity) * scale;

    return SizedBox(
      width: screenW,
      height: canvasH,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: _mapX * scale,
              top: (_mapY + _mapYOffset) * scale,
              width: _mapW * scale,
              height: _mapH * scale,
              child: Image.asset(
                mapRoadAsset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
            for (final island in islands)
              Positioned(
                left: island.x * scale,
                top: (island.y + _mapYOffset) * scale,
                width: island.w * scale,
                height: island.h * scale,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () async {
                    // 1) отметили как открытый (твой текущий функционал)
                    await _saveOpenedSection(island.title);

                    // 2) сохранили "последний открытый раздел"
                    await _saveLastSection(
                      title: island.title,
                      route: island.route,
                    );

                    if (!mounted) return;
                    Navigator.pushNamed(context, island.route);
                  },
                  child: Image.asset(
                    island.asset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppLayout.isTablet(context)) return _buildTablet(context);
    const int nextXp = 100;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 0),
            ExerciseTopBar(coins: userCoins, currentXp: userXp, nextXp: nextXp),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: [
                        _buildScrollableMap(constraints.maxWidth),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildTablet(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9F9F9),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxContentWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const TabletHeader(
                  title: 'Упражнения',
                  subtitle: 'Выбери раздел для занятия',
                ),
                Expanded(
                  child: GridView.builder(
                    key: const PageStorageKey('tablet-sections-grid'),
                    padding: const EdgeInsets.only(bottom: 24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 360,
                          mainAxisExtent: 260,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                    itemCount: islands.length,
                    itemBuilder: (context, index) {
                      final island = islands[index];
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        child: InkWell(
                          key: ValueKey('tablet-section-${island.route}'),
                          borderRadius: BorderRadius.circular(28),
                          onTap: () async {
                            await _saveOpenedSection(island.title);
                            await _saveLastSection(
                              title: island.title,
                              route: island.route,
                            );
                            if (!mounted) return;
                            Navigator.of(this.context).pushNamed(island.route);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Image.asset(
                                    island.asset,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  island.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
