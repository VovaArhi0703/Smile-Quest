import 'package:flutter/material.dart';
import '../pages/main_shell.dart';
import 'package:untitled2/widget/tabbar.dart';
import '../layout/adaptive_layout.dart';

class ExerciseTemplate extends StatefulWidget {
  final String categoryTitle;
  final String exerciseTitle;
  final String exerciseGoal;
  final String navigationRoute;
  final String? alternateRoute;
  final String? alternateTitle;

  const ExerciseTemplate({
    super.key,
    required this.categoryTitle,
    required this.exerciseTitle,
    required this.exerciseGoal,
    required this.navigationRoute,
    this.alternateRoute,
    this.alternateTitle,
  });

  @override
  State<ExerciseTemplate> createState() => _ExerciseTemplateState();
}

class _ExerciseTemplateState extends State<ExerciseTemplate> {
  // ===== Figma base =====
  static const double _designW = 375.0;

  // ===== Header sizing EXACTLY like your sample code =====
  static const double _headerH = 88.0;
  static const double _titleTop = 53.0;
  static const double _titleFont = 18.0;
  static const double _titleLineH = 21.0;

  static const double _backLeft = 16.0;
  static const double _backTop = 47.0;
  static const double _backBox = 34.0;
  static const double _backRadius = 10.3636;
  static const double _arrowSize = 18.0;

  // ===== Main layout =====
  static const double _contentW = 343.0;

  // ===== Assets =====
  static const String arrowAsset = 'assets/exercise/arrow_black.png';

  // ===== Colors =====
  static const Color _bg = Color(0xFFF9F9F9);
  static const Color _text = Color(0xFF191919);
  static const Color _sub = Color(0xFFA2A1A1);
  static const Color _green = Color(0xFF81C784);

  // ==== Tabbar (как на островах) ====
  int selectedTabIndex = 1;

  final List<String> routes = const [
    '/home',
    '/exercise_sections',
    '/photo_diary',
    '/profile_first',
  ];

  final List<int> iconStates01 = [0, 1, 0, 0];

  void _onTabSelected(int index) {
    setState(() => selectedTabIndex = index);

    final currentRoute = ModalRoute.of(context)?.settings.name;
    final targetRoute = routes[index];

    if (currentRoute != targetRoute) {
      MainShell.openTab(context, index);
    }
  }

  double _scaleFor(double screenW) => (screenW / _designW).clamp(0.85, 1.35);

  /// Header теперь часть скролла (без blur/цвета), но layout как в примере
  Widget _buildHeaderInScroll(BuildContext context, double screenW) {
    final scale = _scaleFor(screenW);
    final safeTop = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: safeTop + (_headerH * scale),
      child: Stack(
        children: [
          Positioned(
            left: _backLeft * scale,
            top: safeTop + (_backTop * scale),
            width: _backBox * scale,
            height: _backBox * scale,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFF5F5F5), width: 1),
                  borderRadius: BorderRadius.circular(_backRadius * scale),
                ),
                child: Image.asset(
                  arrowAsset,
                  width: _arrowSize * scale,
                  height: _arrowSize * scale,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: safeTop + (_titleTop * scale),
            height: _titleLineH * scale,
            child: Center(
              child: Text(
                'Инструкция',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                  fontSize: _titleFont * scale,
                  height: _titleLineH / _titleFont,
                  color: _text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContentBelowHeader(BuildContext context, double screenW) {
    final scale = _scaleFor(screenW);

    return Center(
      child: SizedBox(
        width: _contentW * scale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ВАЖНО: отступ от верхнего лэйаута до основного = 12
            SizedBox(height: 12 * scale),

            // ===== Card: теперь высота НЕ фиксированная =====
            Container(
              width: _contentW * scale,
              padding: EdgeInsets.all(16 * scale),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(34 * scale),
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // чтобы контейнер рос по контенту
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== Title&Subtitle: высота НЕ фиксированная =====
                  SizedBox(
                    width: 311 * scale,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Название упражнения: может быть много строк
                        Text(
                          widget.exerciseTitle,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 26 * scale,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                            color: _text,
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        Text(
                          widget.categoryTitle,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 18 * scale,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                            color: _sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8 * scale),

                  // Buttons row (311x67, gap 8) — как было
                  SizedBox(
                    width: 311 * scale,
                    height: 67 * scale,
                    child: Row(
                      children: [
                        Expanded(
                          child: _MetricBlock(
                            scale: scale,
                            leftIcon: Container(
                              width: 32 * scale,
                              height: 32 * scale,
                              decoration: BoxDecoration(
                                color: _green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(48 * scale),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/exercise/timer.png',
                                  width: 18 * scale,
                                  height: 18 * scale,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            badgeText: '5 мин.',
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        Expanded(
                          child: _MetricBlock(
                            scale: scale,
                            leftIcon: Image.asset(
                              'assets/newimage/coin_20.png',
                              width: 32 * scale,
                              height: 32 * scale,
                              fit: BoxFit.contain,
                            ),
                            badgeText: '+25',
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8 * scale),

                  // Video placeholder (311x276) + inner frame (291x142) — как было
                  Container(
                    width: 311 * scale,
                    height: 276 * scale,
                    padding: EdgeInsets.all(10 * scale),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _green, width: 1),
                      borderRadius: BorderRadius.circular(24 * scale),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 291 * scale,
                        height: 142 * scale,
                        child: Column(
                          children: [
                            SizedBox(height: 26 * scale),
                            SizedBox(
                              width: 230 * scale,
                              height: 16 * scale,
                              child: Text(
                                'Обучающего видео пока нет',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.w500,
                                  height: 1.0,
                                  color: _sub,
                                ),
                              ),
                            ),
                            SizedBox(height: 20 * scale),
                            Image.asset(
                              'assets/exercise/sad_face.png',
                              width: 80 * scale,
                              height: 80 * scale,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12 * scale),

            // Start button (343x55) — как было
            Container(
              width: _contentW * scale,
              height: 55 * scale,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF84DF88), Color(0xFF81C784)],
                  stops: [0.1054, 0.8957],
                ),
                borderRadius: BorderRadius.circular(85 * scale),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(85 * scale),
                  onTap:
                      () =>
                          Navigator.pushNamed(context, widget.navigationRoute),
                  child: Padding(
                    padding: EdgeInsets.all(5 * scale),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 177 * scale,
                          height: 21 * scale,
                          child: Text(
                            'Начать упражнение',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 18 * scale,
                              fontWeight: FontWeight.w700,
                              height: 21 / 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        SizedBox(
                          width: 24 * scale,
                          height: 24 * scale,
                          child: Center(
                            child: Image.asset(
                              'assets/exercise/play_icon.png',
                              width: 16 * scale,
                              height: 18 * scale,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (widget.alternateRoute != null) ...[
              SizedBox(height: 12 * scale),
              SizedBox(
                width: _contentW * scale,
                height: 55 * scale,
                child: OutlinedButton(
                  onPressed:
                      () =>
                          Navigator.pushNamed(context, widget.alternateRoute!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    widget.alternateTitle ?? 'Другая версия упражнения',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            SizedBox(height: 12 * scale),

            // Goal block (343x108) — как было
            Container(
              width: _contentW * scale,
              padding: EdgeInsets.all(16 * scale),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26 * scale),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 311 * scale,
                    height: 32 * scale,
                    child: Row(
                      children: [
                        Container(
                          width: 32 * scale,
                          height: 32 * scale,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF8E4D,
                            ).withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(48 * scale),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/exercise/target.png',
                              width: 19.5 * scale,
                              height: 19.5 * scale,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(width: 12 * scale),
                        Expanded(
                          child: Text(
                            'Цель упражнения',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                              color: _text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10 * scale),
                  SizedBox(
                    width: 311 * scale,
                    child: Text(
                      widget.exerciseGoal,
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w500,
                        height: 17 / 14,
                        color: const Color(0xFF777777),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // чтобы низ не прятался под таббаром
            SizedBox(height: 110 * scale),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppLayout.isTablet(context)) return _buildTablet(context);
    return Scaffold(
      extendBody: true,
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeaderInScroll(context, screenW),
                  _buildMainContentBelowHeader(context, screenW),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: MainTabBar(
        iconStates01: iconStates01,
        selectedIndex: selectedTabIndex,
        onTabSelected: _onTabSelected,
      ),
    );
  }

  Widget _buildTablet(BuildContext context) => Scaffold(
    backgroundColor: _bg,
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
                TabletHeader(
                  title: 'Инструкция',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final introduction = TabletCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.categoryTitle,
                            style: const TextStyle(fontSize: 16, color: _sub),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.exerciseTitle,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Wrap(
                            spacing: 20,
                            runSpacing: 12,
                            children: [
                              Text('3 минуты'),
                              Text('+25 XP'),
                              Text('+20 монет'),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Цель упражнения',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.exerciseGoal,
                            style: const TextStyle(fontSize: 17, height: 1.5),
                          ),
                          const SizedBox(height: 28),
                          FilledButton(
                            onPressed:
                                () => Navigator.pushNamed(
                                  context,
                                  widget.navigationRoute,
                                ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _green,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: const Text('Начать упражнение'),
                          ),
                          if (widget.alternateRoute != null) ...[
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed:
                                  () => Navigator.pushNamed(
                                    context,
                                    widget.alternateRoute!,
                                  ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                              ),
                              child: Text(
                                widget.alternateTitle ?? 'Версия 2.0',
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                    final preview = TabletCard(
                      child: SizedBox(
                        height: 280,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/exercise/sad_face.png',
                              height: 100,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Обучающего видео пока нет',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, color: _sub),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (constraints.maxWidth >= 850) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: introduction),
                          const SizedBox(width: 24),
                          Expanded(child: preview),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        introduction,
                        const SizedBox(height: 24),
                        preview,
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
    bottomNavigationBar: MainTabBar(
      selectedIndex: selectedTabIndex,
      onTabSelected: _onTabSelected,
    ),
  );
}

class _MetricBlock extends StatelessWidget {
  final double scale;
  final Widget leftIcon;
  final String badgeText;

  const _MetricBlock({
    required this.scale,
    required this.leftIcon,
    required this.badgeText,
  });

  static const Color _green = Color(0xFF81C784);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 67 * scale,
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26 * scale),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32 * scale,
            height: 32 * scale,
            child: Center(child: leftIcon),
          ),
          SizedBox(width: 8 * scale),
          Container(
            width: 91.5 * scale,
            height: 36 * scale,
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(30 * scale),
            ),
            child: Center(
              child: Text(
                badgeText,
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
