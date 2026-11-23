import 'package:flutter/material.dart';
import '../layout/adaptive_layout.dart';
import 'package:intl/intl.dart';
import '../photo_service.dart';
import '../photo_view.dart';
import '../widget/exercise_picker_sheet.dart';
import 'package:untitled2/widget/tabbar.dart';
import 'main_shell.dart';

enum _Mode { month, week, day }

class PhotoDiaryPage extends StatefulWidget {
  const PhotoDiaryPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<PhotoDiaryPage> createState() => _PhotoDiaryPageState();
}

class _PhotoDiaryPageState extends State<PhotoDiaryPage> {
  // --- Цвета (как в новом дизайне) ---
  static const Color _kBg = Color(0xFFF9F9F9);
  static const Color _kGreen = Color(0xFF81C784);

  // --- Tabbar ---
  int selectedTabIndex = 2;
  final List<String> routes = [
    '/home',
    '/exercise_sections',
    '/photo_diary',
    '/profile_first',
  ];
  List<int> iconStates01 = [0, 0, 1, 0];

  void _onTabSelected(int index) {
    if (widget.embedded) {
      MainShell.maybeOf(context)?.selectTab(index);
      return;
    }
    setState(() => selectedTabIndex = index);
    final current = ModalRoute.of(context)?.settings.name;
    if (current != routes[index])
      Navigator.of(context).pushNamed(routes[index]);
  }

  // --- Exercise filters ---
  String? selectedSection;
  String? selectedExercise;

  bool get _hasFilterSelected =>
      selectedSection != null || selectedExercise != null;

  // --- Time state ---
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _calendarExpanded = false;
  _Mode _mode = _Mode.month;
  int _selectedWeekIndex = 0;
  DateTime? _selectedDay;

  // --- Data ---
  List<Photo> photos = [];
  Map<DateTime, int> _dayCounts = {};
  bool isLoading = false;
  String? errorMessage;

  // --- Preview switcher state ---
  int _previewIndex = 0;

  // --- Assets ---
  static const _icBack = 'assets/newimage/arrow_left.png';
  static const _icMonthLeft = 'assets/newimage/ic_month_left.png';
  static const _icMonthRight = 'assets/newimage/ic_month_right.png';
  static const _icFilter = 'assets/newimage/filter.png';

  static const _icWeekUp = 'assets/newimage/ic_chevron_up.png';
  static const _icWeekDown = 'assets/newimage/ic_chevron_down.png';

  // --- scale (под 375px макет) ---
  double get _k =>
      AppLayout.isTablet(context)
          ? 1.0
          : MediaQuery.sizeOf(context).width / 375.0;
  double s(double v) => v * _k;

  // ===========================================================================
  // НАСТРОЙКИ ДИЗАЙНА (правь тут)
  // ===========================================================================
  static const double kToggleWidth =
      88; // было 78, сделали чуть длиннее чтобы "Раскрыть" влезало
  static const double kCalendarCollapsedHeight = 165; // было 163 (+2px)
  static const double kCalendarExpandedHeight = 321; // было 319 (+2px)
  static const double kHeaderMonthYOffset =
      0; // сдвиг по высоте выбора месяца в хэдере
  static const double kPreviewMaxHeight = 520;
  static const double kPreviewNavBtnSize = 34;

  @override
  void initState() {
    super.initState();
    photoChangeRevision.addListener(_reloadAfterPhotoChange);
    _reloadAll();
  }

  @override
  void dispose() {
    photoChangeRevision.removeListener(_reloadAfterPhotoChange);
    super.dispose();
  }

  void _reloadAfterPhotoChange() {
    if (mounted) _reloadAll();
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _startOfNextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _startOfNextMonth(DateTime d) => DateTime(d.year, d.month + 1, 1);

  Future<void> _reloadAll() async {
    await Future.wait([_loadCounts(), _loadPhotos()]);
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await fetchMonthDayCounts(
        monthAnchor: _month,
        section: selectedSection,
        exercise: selectedExercise,
      );
      if (mounted) setState(() => _dayCounts = counts);
    } catch (_) {
      if (mounted) setState(() => _dayCounts = {});
    }
  }

  (DateTime start, DateTime end) _rangeForCurrentSelection() {
    final weeks = _buildWeeks(_month);

    // В СКРЫТОМ календаре показываем ВЕСЬ месяц.
    if (!_calendarExpanded) {
      return (_startOfMonth(_month), _startOfNextMonth(_month));
    }

    if (_mode == _Mode.day && _selectedDay != null) {
      final d = _startOfDay(_selectedDay!);
      return (d, _startOfNextDay(d));
    }

    if (_mode == _Mode.week) {
      final idx = _selectedWeekIndex.clamp(0, weeks.length - 1);
      final w = weeks[idx];
      return (_startOfDay(w.first), _startOfNextDay(w.last));
    }

    return (_startOfMonth(_month), _startOfNextMonth(_month));
  }

  Future<void> _loadPhotos() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final r = _rangeForCurrentSelection();
      final fetched = await fetchPhotosRange(
        startInclusive: r.$1,
        endExclusive: r.$2,
        section: selectedSection,
        exercise: selectedExercise,
      );

      if (!mounted) return;
      setState(() {
        photos = fetched;
        if (photos.isEmpty) {
          _previewIndex = 0;
        } else {
          _previewIndex = _previewIndex.clamp(0, photos.length - 1);
        }
      });
    } catch (e) {
      if (mounted) setState(() => errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- Calendar weeks (Mon-start) ---
  List<List<DateTime>> _buildWeeks(DateTime month) {
    final first = _startOfMonth(month);
    final last = _startOfNextMonth(month).subtract(const Duration(days: 1));

    int mon0(DateTime d) => (d.weekday + 6) % 7; // Mon=0..Sun=6
    final startGrid = first.subtract(Duration(days: mon0(first)));
    final endGrid = last.add(Duration(days: 6 - mon0(last)));

    final days = <DateTime>[];
    for (
      DateTime d = startGrid;
      !d.isAfter(endGrid);
      d = d.add(const Duration(days: 1))
    ) {
      days.add(d);
    }

    final weeks = <List<DateTime>>[];
    for (int i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, i + 7));
    }
    return weeks;
  }

  // --- Actions ---
  void _prevMonth() async {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1, 1);
      _mode = _Mode.month;
      _selectedWeekIndex = 0;
      _selectedDay = null;
    });
    await _reloadAll();
  }

  void _nextMonth() async {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1, 1);
      _mode = _Mode.month;
      _selectedWeekIndex = 0;
      _selectedDay = null;
    });
    await _reloadAll();
  }

  void _toggleCalendar() async {
    setState(() => _calendarExpanded = !_calendarExpanded);
    await _loadPhotos();
  }

  void _selectWeek(int idx) async {
    setState(() {
      _mode = _Mode.week;
      _selectedWeekIndex = idx;
      _selectedDay = null;
    });
    await _loadPhotos();
  }

  // Повторный тап по выбранному дню: снимаем выбор и показываем месяц.
  void _selectDay(DateTime d) async {
    final tapped = _startOfDay(d);
    final alreadySelected =
        _mode == _Mode.day &&
        _selectedDay != null &&
        _startOfDay(_selectedDay!) == tapped;

    if (alreadySelected) {
      setState(() {
        _mode = _Mode.month;
        _selectedDay = null;
      });
      await _loadPhotos();
      return;
    }

    setState(() {
      _mode = _Mode.day;
      _selectedDay = tapped;
    });
    await _loadPhotos();
  }

  // без await
  void _weekUp() {
    if (!_calendarExpanded) return;
    final weeks = _buildWeeks(_month);
    final next = (_selectedWeekIndex - 1).clamp(0, weeks.length - 1);
    _selectWeek(next);
  }

  void _weekDown() {
    if (!_calendarExpanded) return;
    final weeks = _buildWeeks(_month);
    final next = (_selectedWeekIndex + 1).clamp(0, weeks.length - 1);
    _selectWeek(next);
  }

  // --- Preview switcher ---
  void _previewPrev() {
    if (photos.isEmpty) return;
    setState(
      () => _previewIndex = (_previewIndex - 1 + photos.length) % photos.length,
    );
  }

  void _previewNext() {
    if (photos.isEmpty) return;
    setState(() => _previewIndex = (_previewIndex + 1) % photos.length);
  }

  String _monthTitle() {
    final m = DateFormat('LLLL', 'ru').format(_month);
    final cap = '${m[0].toUpperCase()}${m.substring(1)}';
    return '$cap ${_month.year}';
  }

  String _centerTitleText() {
    if (!_calendarExpanded) return 'Месяц';
    if (_mode == _Mode.day) return 'Выбран день';
    if (_mode == _Mode.week) return 'Период';
    return 'Месяц';
  }

  String _centerValueText() {
    final weeks = _buildWeeks(_month);

    if (!_calendarExpanded) return _monthTitle();

    if (_mode == _Mode.day && _selectedDay != null) {
      final d = _selectedDay!;
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    }

    if (_mode == _Mode.week) {
      final w = weeks[_selectedWeekIndex.clamp(0, weeks.length - 1)];
      return '${w.first.day.toString().padLeft(2, '0')} - ${w.last.day.toString().padLeft(2, '0')}';
    }

    return _monthTitle();
  }

  // --- Данные фильтра ---
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

  // --- Новый BottomSheet ---
  Future<void> _showSectionBottomSheet() async {
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
    _reloadAll();
  }

  // --- UI helpers ---
  Widget _squareIconBtn({
    required String asset,
    required VoidCallback onTap,
    double size = 34,
    double iconSize = 18,
    bool enabled = true,
    bool withShadow = true,
    Color? backgroundColor,
    Color? iconTint,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(s(10.36)),
        child: Container(
          width: s(size),
          height: s(size),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            borderRadius: BorderRadius.circular(s(10.36)),
            boxShadow:
                withShadow
                    ? const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.08),
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Center(
            child: Image.asset(
              asset,
              width: s(iconSize),
              height: s(iconSize),
              color: iconTint,
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleNavBtn({
    required String asset,
    required VoidCallback onTap,
    bool enabled = true,
    double size = kPreviewNavBtnSize,
    double iconSize = 16,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: s(size),
          height: s(size),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.08),
                blurRadius: 12,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Image.asset(asset, width: s(iconSize), height: s(iconSize)),
          ),
        ),
      ),
    );
  }

  Widget _calendarToggle() {
    final label = _calendarExpanded ? 'Скрыть' : 'Раскрыть';

    return InkWell(
      onTap: _toggleCalendar,
      borderRadius: BorderRadius.circular(s(2112)),
      child: Container(
        width: s(kToggleWidth),
        height: s(23),
        padding: EdgeInsets.symmetric(horizontal: s(6), vertical: s(3)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(s(2112)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.08),
              blurRadius: 12,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: s(14),
              color: const Color(0xFF191919),
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  // --- Calendar UI ---
  Widget _weekdayRow() {
    const labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return SizedBox(
      height: s(34),
      child: Padding(
        padding: EdgeInsets.all(s(2)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:
              labels.map((t) {
                return SizedBox(
                  width: s(32),
                  height: s(30),
                  child: Center(
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: s(12),
                        color: const Color(0xFF777777),
                        height: 1.2,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _daysRow(List<DateTime> week, {required bool highlightWeek}) {
    final bg =
        highlightWeek
            ? const Color.fromRGBO(129, 199, 132, 0.15)
            : Colors.transparent;
    final br = highlightWeek ? const Color(0xFFA7D8A9) : Colors.transparent;

    return SizedBox(
      height: s(34),
      child: Container(
        padding: EdgeInsets.all(s(2)),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(s(10)),
          border: Border.all(color: br, width: highlightWeek ? s(2) : 0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: week.map(_dayCell).toList(),
        ),
      ),
    );
  }

  Widget _dayCell(DateTime d) {
    final inMonth = d.month == _month.month;
    final today = _startOfDay(DateTime.now());
    final isToday = _startOfDay(d) == today;

    final isSelectedDay =
        _mode == _Mode.day &&
        _selectedDay != null &&
        _startOfDay(_selectedDay!) == _startOfDay(d);

    final count = _dayCounts[_startOfDay(d)] ?? 0;

    Color textColor;
    if (!inMonth) {
      textColor = const Color(0xFF777777);
    } else if (isSelectedDay) {
      textColor = Colors.white;
    } else if (isToday) {
      textColor = const Color(0xFFFF8E4D);
    } else {
      textColor = const Color(0xFF191919);
    }

    final cellBg =
        isSelectedDay
            ? const Color(0xFF81C784)
            : (inMonth ? const Color(0xFFF2F2F2) : Colors.white);

    return InkWell(
      onTap: inMonth ? () => _selectDay(d) : null,
      borderRadius: BorderRadius.circular(s(8)),
      child: SizedBox(
        width: s(32),
        height: s(30),
        child: Container(
          decoration: BoxDecoration(
            color: cellBg,
            borderRadius: BorderRadius.circular(s(8)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Text(
                  '${d.day}',
                  style: TextStyle(
                    fontSize: s(12),
                    color: textColor,
                    height: 1.2,
                  ),
                ),
              ),
              if (count > 0 && inMonth)
                Positioned(
                  left: s(21.5),
                  top: s(-2),
                  child: Container(
                    width: s(13),
                    height: s(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6F1C),
                      borderRadius: BorderRadius.circular(s(100)),
                    ),
                    child: Center(
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: TextStyle(
                          fontSize: s(8),
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _calendarBody() {
    final weeks = _buildWeeks(_month);

    if (!_calendarExpanded) {
      final firstWeek = weeks.first;
      return SizedBox(
        height: s(74),
        child: Column(
          children: [
            _weekdayRow(),
            SizedBox(height: s(6)),
            _daysRow(firstWeek, highlightWeek: false),
          ],
        ),
      );
    }

    return SizedBox(
      height: s(234),
      child: Column(
        children: [
          _weekdayRow(),
          SizedBox(height: s(6)),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: weeks.length,
              itemBuilder: (context, i) {
                final isSelectedWeek =
                    _mode == _Mode.week && _selectedWeekIndex == i;
                return Padding(
                  padding: EdgeInsets.only(bottom: s(6)),
                  child: InkWell(
                    onTap: () => _selectWeek(i),
                    child: _daysRow(weeks[i], highlightWeek: isSelectedWeek),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Preview ---
  Widget _photoPreviewSwitcher() {
    final hasPhotos = photos.isNotEmpty;
    final canNav = hasPhotos && photos.length > 1;
    final Photo? current =
        hasPhotos ? photos[_previewIndex.clamp(0, photos.length - 1)] : null;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(s(16), s(12), s(16), s(0)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: s(kPreviewMaxHeight)),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(s(22)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFF5F5F5),
                      width: s(1),
                    ),
                  ),
                  child:
                      current == null
                          ? (isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : const Center(
                                child: Text(
                                  'Фото не найдены',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ))
                          : Image.network(
                            current.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              final expected =
                                  loadingProgress.expectedTotalBytes;
                              final loaded =
                                  loadingProgress.cumulativeBytesLoaded;
                              final value =
                                  (expected == null) ? null : loaded / expected;
                              return Center(
                                child: CircularProgressIndicator(value: value),
                              );
                            },
                            errorBuilder:
                                (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image),
                                ),
                          ),
                ),
                Positioned(
                  left: s(10),
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _circleNavBtn(
                      asset: _icMonthLeft,
                      onTap: _previewPrev,
                      enabled: canNav,
                      size: kPreviewNavBtnSize,
                      iconSize: 16,
                    ),
                  ),
                ),
                Positioned(
                  right: s(10),
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _circleNavBtn(
                      asset: _icMonthRight,
                      onTap: _previewNext,
                      enabled: canNav,
                      size: kPreviewNavBtnSize,
                      iconSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Header ---
  Widget _topBar() {
    return SizedBox(
      height: s(101),
      child: Padding(
        padding: EdgeInsets.fromLTRB(s(16), s(19), s(16), s(19)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _squareIconBtn(
              asset: _icBack,
              onTap: () {
                final shell = MainShell.maybeOf(context);
                if (shell != null) {
                  shell.selectTab(0);
                } else {
                  Navigator.maybePop(context);
                }
              },
              iconSize: 18,
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  height: s(34),
                  child: Transform.translate(
                    offset: Offset(0, s(kHeaderMonthYOffset)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _prevMonth,
                          child: Image.asset(
                            _icMonthLeft,
                            width: s(16),
                            height: s(16),
                          ),
                        ),
                        SizedBox(width: s(12)),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: s(240)),
                          child: Text(
                            _monthTitle(),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: s(16),
                              color: const Color(0xFF191919),
                              height: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(width: s(12)),
                        GestureDetector(
                          onTap: _nextMonth,
                          child: Image.asset(
                            _icMonthRight,
                            width: s(16),
                            height: s(16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _squareIconBtn(
              asset: _icFilter,
              onTap: _showSectionBottomSheet,
              iconSize: 18,
              backgroundColor: _hasFilterSelected ? _kGreen : Colors.white,
              iconTint: _hasFilterSelected ? Colors.white : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePickerCard() {
    final extraTextHeight =
        AppLayout.isTablet(context)
            ? (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(
                  0.0,
                  32.0,
                ) *
                2
            : 0.0;
    final cardHeight =
        (_calendarExpanded
            ? kCalendarExpandedHeight
            : kCalendarCollapsedHeight) +
        extraTextHeight;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: s(16)),
      child: SizedBox(
        height: s(cardHeight),
        child: Container(
          padding: EdgeInsets.all(s(16)),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFF5F5F5), width: s(1)),
            borderRadius: BorderRadius.circular(s(22)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: s((_calendarExpanded ? 37 : 41) + extraTextHeight),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: s(78),
                      height: s(34),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _squareIconBtn(
                            asset: _icWeekUp,
                            onTap: _weekUp,
                            iconSize: 16,
                            enabled: _calendarExpanded,
                          ),
                          SizedBox(width: s(4)),
                          _squareIconBtn(
                            asset: _icWeekDown,
                            onTap: _weekDown,
                            iconSize: 16,
                            enabled: _calendarExpanded,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _centerTitleText(),
                            style: TextStyle(
                              fontSize: s(12),
                              color: const Color(0xFFA3A3A3),
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: s(2)),
                          Text(
                            _centerValueText(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: s(16),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF191919),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: s(kToggleWidth),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _calendarToggle(),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: s(16)),
              _calendarBody(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Slivers ---
  Widget _photosSliver() {
    if (isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'Ошибка загрузки фото:\n$errorMessage',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (photos.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text('Фото не найдены', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final p = photos[index];
          final dd = p.dateTaken.day.toString().padLeft(2, '0');
          final mm = p.dateTaken.month.toString().padLeft(2, '0');

          return InkWell(
            onTap: () => setState(() => _previewIndex = index),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dd.$mm.${p.dateTaken.year}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Image.network(
                        p.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }, childCount: photos.length),
        gridDelegate:
            AppLayout.isTablet(context)
                ? const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 3 / 5,
                )
                : const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3 / 5,
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppLayout.isTablet(context)) return _buildTablet(context);
    return Scaffold(
      extendBody: true,
      backgroundColor: _kBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _topBar(),
                  _datePickerCard(),
                  _photoPreviewSwitcher(),
                ],
              ),
            ),
            _photosSliver(),
            SliverToBoxAdapter(child: SizedBox(height: s(90))),
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

  Widget _buildTablet(BuildContext context) {
    final calendar = Column(
      children: [_topBar(), _datePickerCard(), _photoPreviewSwitcher()],
    );
    return Scaffold(
      backgroundColor: _kBg,
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
                  TabletHeader(
                    title: 'Фото-Дневник',
                    actions: [
                      IconButton.filledTonal(
                        tooltip: 'Сделать фото',
                        onPressed:
                            () => Navigator.of(context).pushNamed('/photo'),
                        icon: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ],
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 850) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 375,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: calendar,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: CustomScrollView(
                                  slivers: [_photosSliver()],
                                ),
                              ),
                            ],
                          );
                        }
                        return CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Center(
                                child: SizedBox(width: 420, child: calendar),
                              ),
                            ),
                            _photosSliver(),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 24),
                            ),
                          ],
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
}
