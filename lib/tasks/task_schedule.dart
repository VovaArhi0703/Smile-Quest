import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'task_store.dart';

const _green = Color(0xFF73C877);
const _wheelGreen = Color(0xFF81C784);
const _ink = Color(0xFF191919);
const _muted = Color(0xFF777777);
const _light = Color(0xFFF9F9F9);
const _stroke = Color(0xFFF3F3F3);
const _dim = Color(0x80000000);
const _calendarShadow = BoxShadow(
  color: Color(0x14000000),
  blurRadius: 12,
  offset: Offset(0, 2),
);
const _cardShadow = BoxShadow(
  color: Color(0x0F000000),
  blurRadius: 20,
  offset: Offset(0, 2),
);
const _switchShadow = BoxShadow(
  color: Color(0x1A000000),
  blurRadius: 20,
  offset: Offset(0, 2),
);
const _timeShadow = BoxShadow(
  color: Color(0x1A000000),
  blurRadius: 60,
  offset: Offset(0, 10),
);
const _iconRadius = BorderRadius.all(Radius.circular(10.36));
const _chipRadius = BorderRadius.all(Radius.circular(6.09375));
const _days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _months = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

Future<DateTimeRange?> showTaskCalendar(
  BuildContext context, {
  required bool isRange,
  DateTime? startDate,
  DateTime? endDate,
  Color barrierColor = _dim,
}) => _showSchedule<DateTimeRange>(
  context,
  barrierColor: barrierColor,
  radius: 22,
  border: const BorderSide(color: _stroke),
  offset: const Offset(0, 0.5),
  child: _TaskCalendar(
    isRange: isRange,
    startDate: startDate,
    endDate: endDate,
  ),
);

Future<TimeOfDay?> showTaskTime(
  BuildContext context, {
  TimeOfDay? initialTime,
  Color barrierColor = _dim,
}) => _showSchedule<TimeOfDay>(
  context,
  width: 256,
  barrierColor: barrierColor,
  offset: const Offset(0.5, -6),
  shadows: const [_timeShadow],
  child: _TaskTime(
    initialTime: initialTime ?? const TimeOfDay(hour: 8, minute: 0),
  ),
);

Future<TaskRepeat?> showTaskRepeat(
  BuildContext context, {
  TaskRepeat initialRepeat = const TaskRepeat(),
  Color barrierColor = _dim,
}) => _showSchedule<TaskRepeat>(
  context,
  barrierColor: barrierColor,
  offset: Offset(0, initialRepeat.exerciseReminders ? -0.25 : 0.25),
  child: _TaskRepeatDialog(initial: initialRepeat),
);

Future<T?> _showSchedule<T>(
  BuildContext context, {
  required Widget child,
  required Color barrierColor,
  double width = 343,
  double radius = 30,
  BorderSide border = BorderSide.none,
  Offset offset = Offset.zero,
  List<BoxShadow> shadows = const [],
}) => showGeneralDialog<T>(
  context: context,
  barrierLabel: 'Закрыть',
  barrierDismissible: true,
  barrierColor: barrierColor,
  transitionDuration: const Duration(milliseconds: 160),
  transitionBuilder:
      (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
  pageBuilder:
      (context, _, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Transform.translate(
            offset: offset,
            child: SizedBox(
              width: width,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: shadows,
                ),
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                    side: border,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
);

TextStyle _style(
  double size, {
  Color color = _ink,
  FontWeight weight = FontWeight.w500,
  double? lineHeight,
  String fontFamily = 'SF Pro',
}) => TextStyle(
  fontFamily: fontFamily,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: lineHeight == null ? 1 : lineHeight / size,
);

Widget _fitLabel(
  String text, {
  required TextStyle style,
  Alignment alignment = Alignment.center,
}) => FittedBox(
  fit: BoxFit.scaleDown,
  alignment: alignment,
  child: Text(text, style: style, maxLines: 1),
);

class _ScheduleButton extends StatelessWidget {
  const _ScheduleButton(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 51,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(64)),
        ),
      ),
      child: _fitLabel(
        label,
        style: _style(
          16,
          weight: FontWeight.w600,
          color: Colors.white,
          lineHeight: 19,
        ),
      ),
    ),
  );
}

class _ScheduleIconButton extends StatelessWidget {
  const _ScheduleIconButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.size = 34,
    this.surface = true,
    this.raised = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final double size;
  final bool surface;
  final bool raised;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _iconRadius,
        border: surface && !raised ? Border.all(color: _stroke) : null,
        color: surface ? Colors.white : null,
        boxShadow: raised ? const [_calendarShadow] : null,
      ),
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        borderRadius: _iconRadius,
        child: SizedBox.square(dimension: size, child: Center(child: icon)),
      ),
    ),
  );
}

Widget _calendarChevron({
  String asset = 'form_dropdown',
  int turns = 0,
  bool flipX = false,
  bool flipY = false,
}) => RotatedBox(
  quarterTurns: turns,
  child: Transform.flip(
    flipX: flipX,
    flipY: flipY,
    child: SvgPicture.asset('assets/tasks/$asset.svg'),
  ),
);

class _TaskRepeatDialog extends StatefulWidget {
  const _TaskRepeatDialog({required this.initial});

  final TaskRepeat initial;

  @override
  State<_TaskRepeatDialog> createState() => _TaskRepeatDialogState();
}

class _TaskRepeatDialogState extends State<_TaskRepeatDialog> {
  late final Set<int> _daysOn = widget.initial.days.difference(
    widget.initial.daysOff,
  );
  late final Set<int> _daysOff = {...widget.initial.daysOff};
  late bool _exerciseReminders = widget.initial.exerciseReminders;
  late int _interval = widget.initial.intervalHours;
  late int _sets = widget.initial.sets;

  void _toggleDay(int day) => setState(() {
    if (!_daysOn.remove(day)) {
      _daysOn.add(day);
      _daysOff.remove(day);
    }
  });

  String _hours(int value) =>
      '$value ${switch (value) {
        1 || 21 => 'час',
        2 || 3 || 4 || 22 || 23 || 24 => 'часа',
        _ => 'часов',
      }}';

  String _times(int value) =>
      '$value ${switch (value) {
        2 || 3 || 4 || 22 || 23 || 24 => 'раза',
        _ => 'раз',
      }}';

  Future<void> _pickValue({required bool isInterval}) async {
    final value = await _showSchedule<int>(
      context,
      width: 256,
      barrierColor: _dim,
      child: _ScheduledNumber(
        title: isInterval ? 'Интервал' : 'Подходов',
        value: isInterval ? _interval : _sets,
        label: isInterval ? _hours : _times,
      ),
    );
    if (!mounted || value == null) return;
    setState(() {
      if (isInterval) {
        _interval = value;
      } else {
        _sets = value;
      }
    });
  }

  void _save() => Navigator.of(context).pop(
    TaskRepeat(
      days: Set<int>.unmodifiable(_daysOn),
      daysOff: Set<int>.unmodifiable(_daysOff),
      exerciseReminders: _exerciseReminders,
      intervalHours: _interval,
      sets: _sets,
    ),
  );

  Widget _dayRow() => LayoutBuilder(
    builder: (context, constraints) {
      final chipWidth = math.min(39.0, (constraints.maxWidth - 18) / 7);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var index = 0; index < _days.length; index++)
            SizedBox(width: chipWidth, child: _dayChip(index)),
        ],
      );
    },
  );

  Widget _dayChip(int index) {
    final selected = _daysOn.contains(index + 1);
    return Semantics(
      button: true,
      selected: selected,
      label: 'День повтора ${_days[index]}',
      onTap: () => _toggleDay(index + 1),
      excludeSemantics: true,
      child: Material(
        color: selected ? _green : _light,
        borderRadius: _chipRadius,
        child: InkWell(
          excludeFromSemantics: true,
          borderRadius: _chipRadius,
          onTap: () => _toggleDay(index + 1),
          child: SizedBox(
            height: 46.25,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _fitLabel(
                _days[index],
                style: _style(
                  14.625,
                  color: selected ? Colors.white : _muted,
                  weight: FontWeight.w400,
                  lineHeight: 17,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _valueCard(String label, String value, VoidCallback onTap) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [_cardShadow],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 14,
                  child: _fitLabel(
                    label,
                    alignment: Alignment.centerLeft,
                    style: _style(12, lineHeight: 14),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 33,
                  child: _fitLabel(
                    value,
                    style: _style(
                      14,
                      color: _green,
                      weight: FontWeight.w600,
                      lineHeight: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                left: 42,
                right: 42,
                child: _fitLabel(
                  'Повтор',
                  style: _style(
                    18,
                    lineHeight: 21,
                    fontFamily: 'SF Pro Display',
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _ScheduleIconButton(
                  label: 'Назад',
                  icon: SvgPicture.asset('assets/tasks/back.svg'),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _exerciseReminders ? 16 : 24),
        SizedBox(
          width: double.infinity,
          height: 12,
          child: _fitLabel(
            'Выбрать дни',
            alignment: Alignment.centerLeft,
            style: _style(12, color: _muted, weight: FontWeight.w400),
          ),
        ),
        const SizedBox(height: 16),
        _dayRow(),
        SizedBox(height: _exerciseReminders ? 16 : 24),
        SizedBox(
          height: 30,
          child: Row(
            children: [
              Expanded(
                child: _fitLabel(
                  'Повторение упражнения',
                  alignment: Alignment.centerLeft,
                  style: _style(
                    12,
                    color: _exerciseReminders ? _ink : _muted,
                    weight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _RepeatSwitch(
                value: _exerciseReminders,
                onTap:
                    () => setState(
                      () => _exerciseReminders = !_exerciseReminders,
                    ),
              ),
            ],
          ),
        ),
        if (_exerciseReminders) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _valueCard(
                  'Интервал',
                  _hours(_interval),
                  () => _pickValue(isInterval: true),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _valueCard(
                  'Подходов',
                  _times(_sets),
                  () => _pickValue(isInterval: false),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: _exerciseReminders ? 16 : 24),
        _ScheduleButton(_exerciseReminders ? 'Применить' : 'Добавить', _save),
      ],
    ),
  );
}

class _RepeatSwitch extends StatelessWidget {
  const _RepeatSwitch({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Повторение упражнения',
    toggled: value,
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 51,
        height: 30,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? _green : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [_switchShadow],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 120),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: value ? Colors.white : _green,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 26),
          ),
        ),
      ),
    ),
  );
}

class _TaskCalendar extends StatefulWidget {
  const _TaskCalendar({required this.isRange, this.startDate, this.endDate});

  final bool isRange;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  State<_TaskCalendar> createState() => _TaskCalendarState();
}

class _TaskCalendarState extends State<_TaskCalendar> {
  final _today = DateUtils.dateOnly(DateTime.now());
  late DateTime _month = DateUtils.dateOnly(widget.startDate ?? _today);
  late DateTime _start = DateUtils.dateOnly(widget.startDate ?? _today);
  late DateTime? _end =
      widget.isRange && widget.endDate != null
          ? DateUtils.dateOnly(widget.endDate!)
          : null;
  bool _choosingEnd = false;
  bool _selectionChanged = false;

  void _changeMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
  });

  void _shiftSelection(int direction) => setState(() {
    final by = direction * (widget.isRange ? 7 : 1);
    _start = DateUtils.addDaysToDate(_start, by);
    if (_end case final end?) {
      _end = DateUtils.addDaysToDate(end, by);
    }
    _month = _start;
    _selectionChanged = true;
  });

  void _choose(DateTime date) => setState(() {
    _selectionChanged = true;
    _month = date;
    if (!widget.isRange) {
      _start = date;
      _end = date;
      return;
    }
    if (!_choosingEnd) {
      _start = date;
      _end = null;
      _choosingEnd = true;
    } else {
      if (date.isBefore(_start)) {
        _end = _start;
        _start = date;
      } else {
        _end = date;
      }
      _choosingEnd = false;
    }
  });

  void _closeOrSave() {
    if (!_selectionChanged) {
      Navigator.of(context).pop();
      return;
    }
    final end = _end;
    Navigator.of(context).pop(
      DateTimeRange(
        start: _start,
        end: end != null && !end.isBefore(_start) ? end : _start,
      ),
    );
  }

  bool _contains(DateTime day) {
    return _selectionChanged &&
        !day.isBefore(_start) &&
        !day.isAfter(_end ?? _start);
  }

  String _selectedText() {
    final start = _start;
    final end = _end;
    if (end == null || !widget.isRange) return '${start.day}';
    if (start.month == end.month && start.year == end.year) {
      return '${start.day} - ${end.day}';
    }
    return '${start.day}.${_twoDigits(start.month)} - ${end.day}.${_twoDigits(end.month)}';
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month);
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final offset = first.weekday - 1;
    final weeks = (daysInMonth + offset + 6) ~/ 7;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 19,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ScheduleIconButton(
                  label: 'Предыдущий месяц',
                  icon: _calendarChevron(flipX: true),
                  size: 16,
                  surface: false,
                  onTap: () => _changeMonth(-1),
                ),
                Flexible(
                  child: SizedBox(
                    width: 129,
                    child: _fitLabel(
                      '${_months[_month.month - 1]} ${_month.year}',
                      style: _style(
                        16,
                        weight: FontWeight.w400,
                        lineHeight: 19,
                      ),
                    ),
                  ),
                ),
                _ScheduleIconButton(
                  label: 'Следующий месяц',
                  icon: _calendarChevron(),
                  size: 16,
                  surface: false,
                  onTap: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 37,
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ScheduleIconButton(
                        label: 'Назад по датам',
                        icon: _calendarChevron(
                          asset: 'schedule_period',
                          turns: -1,
                          flipY: true,
                        ),
                        raised: true,
                        onTap: () => _shiftSelection(-1),
                      ),
                      const SizedBox(width: 4),
                      _ScheduleIconButton(
                        label: 'Вперёд по датам',
                        icon: _calendarChevron(
                          asset: 'schedule_period',
                          turns: 1,
                        ),
                        raised: true,
                        onTap: () => _shiftSelection(1),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 18,
                        child: _fitLabel(
                          widget.isRange ? 'Выбран период' : 'Выбрана дата',
                          style: _style(
                            12,
                            color: const Color(0xFFA3A3A3),
                            weight: FontWeight.w400,
                            lineHeight: 14,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 19,
                        child: _fitLabel(
                          _selectedText(),
                          style: _style(
                            16,
                            weight: FontWeight.w600,
                            lineHeight: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 78,
                  height: 23,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [_calendarShadow],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _closeOrSave,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        child: _fitLabel(
                          _selectionChanged ? 'Выбрать' : 'Скрыть',
                          style: _style(
                            14,
                            weight: FontWeight.w400,
                            lineHeight: 17,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder:
                (context, constraints) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final day in _days)
                      SizedBox(
                        width: math.min(36.0, constraints.maxWidth / 7),
                        height: 34,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: _fitLabel(
                            day,
                            style: _style(
                              12,
                              color: _muted,
                              weight: FontWeight.w400,
                              lineHeight: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
          ),
          for (var week = 0; week < weeks; week++) ...[
            const SizedBox(height: 6),
            _week([
              for (var weekday = 0; weekday < 7; weekday++)
                DateTime(
                  first.year,
                  first.month,
                  1 - offset + week * 7 + weekday,
                ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _week(List<DateTime> week) => LayoutBuilder(
    builder: (context, constraints) {
      final first = week.indexWhere(_contains);
      final last = week.lastIndexWhere(_contains);
      final cellWidth = math.min(36.0, constraints.maxWidth / 7);
      final columnWidth = (constraints.maxWidth - cellWidth) / 6;
      return SizedBox(
        height: 34,
        child: Stack(
          children: [
            if (widget.isRange && first >= 0 && _start != _end && _end != null)
              Positioned(
                left: first * columnWidth,
                width: (last - first) * columnWidth + cellWidth,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x2681C784),
                    border: Border.all(
                      color: const Color(0xFFA7D8A9),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final date in week) _day(date, cellWidth)],
            ),
          ],
        ),
      );
    },
  );

  Widget _day(DateTime date, double cellWidth) {
    final edge =
        _selectionChanged &&
        (DateUtils.isSameDay(date, _start) || DateUtils.isSameDay(date, _end));
    final inMonth = date.month == _month.month;
    final current = DateUtils.isSameDay(date, _today);
    final textColor =
        edge
            ? Colors.white
            : current
            ? const Color(0xFFFF8E4D)
            : inMonth
            ? _ink
            : _muted;
    return Semantics(
      button: true,
      selected: _contains(date),
      label: '${date.day}.${_twoDigits(date.month)}.${date.year}',
      onTap: () => _choose(date),
      excludeSemantics: true,
      child: SizedBox(
        width: cellWidth,
        height: 34,
        child: Center(
          child: Material(
            color:
                edge
                    ? _green
                    : _contains(date)
                    ? Colors.white
                    : inMonth
                    ? const Color(0xFFF8F8F8)
                    : Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(8),
              onTap: () => _choose(date),
              child: SizedBox(
                width: math.min(32.0, cellWidth),
                height: 30,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: _fitLabel(
                    '${date.day}',
                    style: _style(
                      12,
                      color: textColor,
                      weight: FontWeight.w400,
                      lineHeight: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _TaskTime extends StatefulWidget {
  const _TaskTime({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_TaskTime> createState() => _TaskTimeState();
}

class _TaskTimeState extends State<_TaskTime> {
  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;
  late final _hoursController = FixedExtentScrollController(initialItem: _hour);
  late final _minutesController = FixedExtentScrollController(
    initialItem: _minute,
  );

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 300,
    child: Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 28,
          child: Transform.translate(
            offset: const Offset(-0.5, 0),
            child: _WheelBackdrop(
              child: Row(
                children: [
                  Expanded(
                    child: _wheel(
                      controller: _hoursController,
                      number: 24,
                      value: _hour,
                      onChanged: (index) => setState(() => _hour = index),
                      text: (index) => '$index',
                    ),
                  ),
                  Expanded(
                    child: _wheel(
                      controller: _minutesController,
                      number: 60,
                      value: _minute,
                      onChanged: (index) => setState(() => _minute = index),
                      text: _twoDigits,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 20,
          right: 20,
          child: _ScheduleButton(
            'Сохранить',
            () => Navigator.of(
              context,
            ).pop(TimeOfDay(hour: _hour, minute: _minute)),
          ),
        ),
      ],
    ),
  );
}

class _ScheduledNumber extends StatefulWidget {
  const _ScheduledNumber({
    required this.title,
    required this.value,
    required this.label,
  });

  final String title;
  final int value;
  final String Function(int) label;

  @override
  State<_ScheduledNumber> createState() => _ScheduledNumberState();
}

class _ScheduledNumberState extends State<_ScheduledNumber> {
  late int _value = widget.value.clamp(1, 24);
  late final _controller = FixedExtentScrollController(initialItem: _value - 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 24, child: _fitLabel(widget.title, style: _style(18))),
        const SizedBox(height: 10),
        _WheelBackdrop(
          child: _wheel(
            controller: _controller,
            number: 24,
            value: _value - 1,
            onChanged: (index) => setState(() => _value = index + 1),
            text: (index) => widget.label(index + 1),
          ),
        ),
        const SizedBox(height: 10),
        _ScheduleButton('Сохранить', () => Navigator.of(context).pop(_value)),
      ],
    ),
  );
}

class _WheelBackdrop extends StatelessWidget {
  const _WheelBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 109,
    height: 178,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 72,
          height: 35,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _wheelGreen,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
        child,
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xB3FFFFFF),
                  Color(0x00FFFFFF),
                  Color(0x00FFFFFF),
                  Color(0xB3FFFFFF),
                ],
                stops: [0, 0.405, 0.595, 1],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _wheel({
  required FixedExtentScrollController controller,
  required int number,
  required int value,
  required ValueChanged<int> onChanged,
  required String Function(int) text,
}) => ListWheelScrollView.useDelegate(
  controller: controller,
  itemExtent: 35,
  physics: const FixedExtentScrollPhysics(),
  diameterRatio: 1.4,
  onSelectedItemChanged: onChanged,
  childDelegate: ListWheelChildLoopingListDelegate(
    children: [
      for (var index = 0; index < number; index++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: _fitLabel(
            text(index),
            style: _style(
              index == value ? 23 : 20,
              color: index == value ? Colors.white : const Color(0xFFB2B2B2),
            ),
          ),
        ),
    ],
  ),
);
