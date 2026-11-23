import 'package:flutter/material.dart';
import '../game_scripts.dart';

enum StreakCardView { expanded, compact }

const _weekdayNames = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

class StreakCard extends StatelessWidget {
  final double width;
  final double height;

  final int totalDots;
  final String title;

  final String litAsset;
  final String dimAsset;

  final Color activeDotColor;
  final Color inactiveDotColor;
  final Color cardBorderColor;
  final EdgeInsetsGeometry padding;

  final StreakCardView view;

  static const double fireWidth = 78;
  static const double fireHeight = 78;
  static const double fireTopOffset = 18;

  const StreakCard({
    super.key,
    this.width = 178,
    this.height = 237,
    this.totalDots = 7,
    this.title = 'Серия заходов',
    this.litAsset = 'assets/newimage/fire_yellow.png',
    this.dimAsset = 'assets/newimage/fire_grey.png',
    this.activeDotColor = const Color(0xFF81C784),
    this.inactiveDotColor = const Color(0xFFF2F2F2),
    this.cardBorderColor = const Color(0xFF81C784),
    this.padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
    this.view = StreakCardView.expanded,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<LoginActivity?>(
    valueListenable: GamificationService.loginActivity,
    builder:
        (context, activity, _) =>
            activity == null
                ? SizedBox(
                  width: width,
                  height: height,
                  child: const Center(child: CircularProgressIndicator()),
                )
                : _buildActivity(activity),
  );

  Widget _buildActivity(LoginActivity activity) {
    final streak = activity.streak;
    final isLit = LoginActivity.isFireLit(streak);
    final fireImage = isLit ? litAsset : dimAsset;

    if (view == StreakCardView.compact) {
      return _CompactStreakCardCssStrict(
        width: width,
        height: height,
        currentStreak: streak,
        days: activity.weekdays,
        activeDotColor: activeDotColor,
        inactiveDotColor: inactiveDotColor,
        fireCurrentAsset: fireImage,
        recordAsset:
            LoginActivity.isFireLit(activity.best) ? litAsset : dimAsset,
        bestStreak: activity.best,
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        border: isLit ? Border.all(width: 4, color: cardBorderColor) : null,
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.07),
            blurRadius: 9,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF5F5F5),
                        width: 1.32,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    child: Container(
                      width: 90,
                      height: 12,
                      decoration: BoxDecoration(
                        color:
                            isLit
                                ? const Color(0xFFFF8E4D)
                                : const Color(0xFFE4E4E4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -6,
                    child: Container(
                      width: 130,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          streak.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w700,
                            fontSize: 64,
                            height: 1.0,
                            color: Color(0xFF191919),
                            shadows: [
                              Shadow(
                                blurRadius: 1.5,
                                color: Color(0xFFB16742),
                                offset: Offset(0, 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: StreakCard.fireTopOffset,
                    child: Image.asset(
                      fireImage,
                      width: StreakCard.fireWidth,
                      height: StreakCard.fireHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 21 / 18,
                    color: Color(0xFF191919),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalDots.clamp(0, 7), (i) {
                  final visited = activity.weekdays.contains(i + 1);
                  return Semantics(
                    label: _weekdayNames[i],
                    value: visited ? 'Был заход' : 'Без захода',
                    child: Container(
                      key: ValueKey('streak-day-${i + 1}'),
                      margin: EdgeInsets.only(
                        right: i == totalDots - 1 ? 0 : 4,
                      ),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: visited ? activeDotColor : inactiveDotColor,
                        borderRadius: BorderRadius.circular(64),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact state: строго по CSS, который ты прислал.
class _CompactStreakCardCssStrict extends StatelessWidget {
  final double width;
  final double height;

  final int currentStreak;
  final int bestStreak;

  final String fireCurrentAsset;
  final String recordAsset;

  final Color activeDotColor;
  final Color inactiveDotColor;

  final Set<int> days;

  const _CompactStreakCardCssStrict({
    required this.width,
    required this.height,
    required this.currentStreak,
    required this.bestStreak,
    required this.fireCurrentAsset,
    required this.recordAsset,
    required this.activeDotColor,
    required this.inactiveDotColor,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    // CSS база: width 74, height 237
    final s = width / 74.0;

    // Frame 2131330155
    final outerPadding = 4.0 * s; // padding: 4px
    final gap = 8.0 * s; // gap: 8px
    final radiusOuter = 26.0 * s; // border-radius: 26px

    // Child circles
    final circleSize = 66.0 * s;
    final circleBorder = 0.67 * s;
    final circleRadius = 100.0 * s;
    final shadow = BoxShadow(
      color: const Color(0x1A000000),
      blurRadius: 12.0 * s,
      offset: Offset(0, 2.0 * s),
    );

    // gap + space-between (как flex space-between + gap)
    final innerHeight = height - outerPadding * 2;
    final extra = innerHeight - (circleSize * 3) - (gap * 2);
    final between = gap + (extra > 0 ? extra / 2 : 0);
    final recordWidth = bestStreak >= 10 ? 28.0 : 14.0;

    Widget circleCard({required Widget child}) {
      return Container(
        width: circleSize,
        height: circleSize,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFF5F5F5),
            width: circleBorder,
          ),
          boxShadow: [shadow],
          borderRadius: BorderRadius.circular(circleRadius),
        ),
        child: child,
      );
    }

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(outerPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radiusOuter),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // align-items: flex-start
        children: [
          Center(
            child: circleCard(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 11.5 * s,
                    top: 12.75 * s,
                    child: Image.asset(
                      fireCurrentAsset,
                      width: 43.0 * s,
                      height: 48.5 * s,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: between),
          Center(
            child: circleCard(
              child: _CssMiddleCircleStrict(
                s: s,
                number: currentStreak,
                daysOn: days,
                activeDotColor: activeDotColor,
                inactiveDotColor: inactiveDotColor,
              ),
            ),
          ),
          SizedBox(height: between),
          Center(
            child: circleCard(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: (recordWidth + 12) * s,
                    height: 24.0 * s,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          child: SizedBox(
                            width: recordWidth * s,
                            height: 24.0 * s,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                bestStreak.toString(),
                                style: TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 24.0 * s,
                                  height: 1.0,
                                  color: const Color(0xFF191919),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: (recordWidth - 2) * s,
                          top: 4.5 * s,
                          child: Image.asset(
                            recordAsset,
                            width: 16.0 * s,
                            height: 18.0 * s,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 5.0 * s),
                  SizedBox(
                    width: 38.0 * s,
                    height: 14.0 * s,
                    child: const Text(
                      'МАКС.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        height: 14 / 12,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CssMiddleCircleStrict extends StatelessWidget {
  final double s;
  final int number;
  final Set<int> daysOn;
  final Color activeDotColor;
  final Color inactiveDotColor;

  const _CssMiddleCircleStrict({
    required this.s,
    required this.number,
    required this.daysOn,
    required this.activeDotColor,
    required this.inactiveDotColor,
  });

  @override
  Widget build(BuildContext context) {
    // Точки строго по CSS (left/top) внутри 66x66
    const dotPosBase = <Offset>[
      Offset(29, 56), // 34624192
      Offset(38, 54), // 34624193
      Offset(46, 50), // 34624196
      Offset(52, 43), // 34624197
      Offset(6, 43), // 34624198
      Offset(20, 54), // 34624194
      Offset(12, 50), // 34624195
    ];

    // Привязка дней к точкам (чтобы логика работала предсказуемо):
    // day 1..7 раскладываем по дуге слева->вправо (как обычно).
    // В CSS перечисление другое, поэтому даём явное соответствие.
    const dayToDotIndex = <int>[
      4, // day1 -> (6,43)
      6, // day2 -> (12,50)
      5, // day3 -> (20,54)
      0, // day4 -> (29,56)
      1, // day5 -> (38,54)
      2, // day6 -> (46,50)
      3, // day7 -> (52,43)
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: SizedBox(
            width: 28.0 * s,
            height: 40.0 * s,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                number.toString(),
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w700,
                  fontSize: 40.0 * s,
                  height: 1.0,
                  color: const Color(0xFF191919),
                ),
              ),
            ),
          ),
        ),
        for (int day = 1; day <= 7; day++)
          Positioned(
            left: dotPosBase[dayToDotIndex[day - 1]].dx * s,
            top: dotPosBase[dayToDotIndex[day - 1]].dy * s,
            child: Semantics(
              label: _weekdayNames[day - 1],
              value: daysOn.contains(day) ? 'Был заход' : 'Без захода',
              child: Container(
                key: ValueKey('streak-day-$day'),
                width: 8.0 * s,
                height: 8.0 * s,
                decoration: BoxDecoration(
                  color:
                      daysOn.contains(day) ? activeDotColor : inactiveDotColor,
                  borderRadius: BorderRadius.circular(64.0541 * s),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
