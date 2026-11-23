import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';
import '../layout/adaptive_layout.dart';

import 'task_exercise_picker.dart';
import 'task_schedule.dart';
import 'task_store.dart';

export 'task_exercise_picker.dart' show taskExerciseTitle, taskSectionTitle;

const _green = Color(0xFF73C877);
const _ink = Color(0xFF191919);
const _hint = Color(0xFF777777);
const _stroke = Color(0xFFF3F3F3);
const _asset = 'assets/tasks/';
const _shadow = BoxShadow(
  color: Color(0x1A000000),
  blurRadius: 20,
  offset: Offset(0, 2),
);
const _softShadow = BoxShadow(
  color: Color(0x0F000000),
  blurRadius: 20,
  offset: Offset(0, 2),
);

Future<SmileTask?> showCreateTask(BuildContext context) =>
    _showTaskDialog<SmileTask>(context, const _TaskEditor());

Future<SmileTask?> showEditTask(
  BuildContext context,
  SmileTask task, {
  Future<bool> Function()? onDelete,
}) => _showTaskDialog<SmileTask>(
  context,
  _TaskEditor(task: task, onDelete: onDelete),
);

Future<SmileTask?> showDuplicateTask(BuildContext context, SmileTask task) =>
    _showTaskDialog<SmileTask>(
      context,
      _TaskEditor(task: task, duplicate: true),
    );

enum _TaskDetailAction { edit, duplicate, openExercise }

Future<void> showTaskDetails(
  BuildContext context,
  SmileTask task, {
  required VoidCallback onEdit,
  required VoidCallback onDuplicate,
  VoidCallback? onOpenExercise,
}) async {
  final action = await _showTaskDialog<_TaskDetailAction>(
    context,
    _TaskDetail(task: task, canOpenExercise: onOpenExercise != null),
  );
  if (!context.mounted) return;
  switch (action) {
    case _TaskDetailAction.edit:
      onEdit();
    case _TaskDetailAction.duplicate:
      onDuplicate();
    case _TaskDetailAction.openExercise:
      onOpenExercise?.call();
    case null:
      break;
  }
}

Future<T?> _showTaskDialog<T>(BuildContext context, Widget content) =>
    showDialog<T>(
      context: context,
      useSafeArea: false,
      barrierColor: const Color(0x80000000),
      builder: (context) => content,
    );

String _two(int value) => value.toString().padLeft(2, '0');

String _formatDate(DateTime? date) =>
    date == null
        ? 'Выбрать'
        : '${_two(date.day)}.${_two(date.month)}.${_two(date.year % 100)}';

String _formatTime(int? hour, int? minute) =>
    hour == null || minute == null
        ? 'Установить'
        : '${_two(hour)}:${_two(minute)}';

String _formatRepeat(TaskRepeat repeat) {
  const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  final days = repeat.days.difference(repeat.daysOff).toList()..sort();
  if (days.length == 7) return 'Каждый день';
  if (days.isEmpty) return 'Установить дни повтора';
  return days.map((day) => names[day - 1]).join(', ');
}

const _bodyStyle = TextStyle(
  fontFamily: 'SF Pro',
  color: _ink,
  fontSize: 12,
  height: 1.2,
);

class _ModalBody extends StatelessWidget {
  const _ModalBody({required this.child, this.offset = const Offset(0, 0.5)});

  final Widget child;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: SizedBox(
          width: AppLayout.isTablet(context) ? 480 : 343,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.back,
    this.trailing,
    this.category = false,
  });

  final String title;
  final VoidCallback back;
  final Widget? trailing;
  final bool category;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconButton(asset: 'back.svg', label: 'Назад', onTap: back),
        if (category) const SizedBox(width: 13),
        Expanded(
          child: SizedBox(
            height: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: category ? Alignment.centerLeft : Alignment.center,
              child: Text(
                title,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 21 / 18,
                ),
              ),
            ),
          ),
        ),
        if (trailing != null)
          trailing!
        else if (!category)
          const SizedBox(width: 34),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: SizedBox.square(
      dimension: 34,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.364),
          side: const BorderSide(color: _stroke),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10.364),
          onTap: onTap,
          child: Center(child: SvgPicture.asset('$_asset$asset')),
        ),
      ),
    ),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.labelWeight = FontWeight.w600,
  });

  final String title;
  final String icon;
  final VoidCallback onTap;
  final FontWeight labelWeight;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(30);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: const [_shadow],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 134,
              minWidth: double.infinity,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      color: const Color(0xFF070D0D),
                      fontWeight: labelWeight,
                      height: 17 / 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFFECFFDE),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset('$_asset$icon'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({required this.onChoose});

  final ValueChanged<TaskKind> onChoose;

  @override
  Widget build(BuildContext context) => _ModalBody(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(
          title: 'Выбери категорию задачи',
          category: true,
          back: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 301),
          child: Row(
            children: [
              Expanded(
                child: _CategoryCard(
                  title: 'Задача\nна день',
                  icon: 'form_check.svg',
                  labelWeight: FontWeight.w500,
                  onTap: () => onChoose(TaskKind.simple),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CategoryCard(
                  title: 'Задача с\nпериодом',
                  icon: 'form_alarm.svg',
                  onTap: () => onChoose(TaskKind.period),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: _bodyStyle.copyWith(color: _hint, height: 1)),
      ),
    ),
  );
}

class _TaskField extends StatelessWidget {
  const _TaskField({
    required this.label,
    required this.child,
    this.selector = false,
  });

  final String label;
  final Widget child;
  final bool selector;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _FormLabel(label),
      const SizedBox(height: 4),
      Container(
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(selector ? 16 : 100),
          boxShadow: selector ? const [_softShadow] : const [_shadow],
        ),
        child: child,
      ),
    ],
  );
}

class _FieldValue extends StatelessWidget {
  const _FieldValue({
    required this.text,
    this.placeholder = false,
    this.disclosure = false,
    this.maxLines = 2,
    this.onTap,
  });

  final String text;
  final bool placeholder;
  final bool disclosure;
  final int? maxLines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow:
                  maxLines == null
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
              style: _bodyStyle.copyWith(
                color: placeholder ? _hint : _ink,
                fontWeight: placeholder ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          if (disclosure) ...[
            const SizedBox(width: 7),
            SvgPicture.asset('${_asset}form_chevron_right.svg'),
          ],
        ],
      ),
    );
    return onTap == null
        ? row
        : Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: row,
          ),
        );
  }
}

class _TaskTextInput extends StatelessWidget {
  const _TaskTextInput({
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => _TaskField(
    label: label,
    child: Center(
      heightFactor: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: TextField(
          controller: controller,
          style: _bodyStyle,
          minLines: 1,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
          cursorColor: _green,
          decoration: InputDecoration.collapsed(
            hintText: hint,
            hintStyle: _bodyStyle.copyWith(color: _hint),
          ),
        ),
      ),
    ),
  );
}

class _Preference extends StatelessWidget {
  const _Preference({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final labelText = Text(
      label,
      style: _bodyStyle.copyWith(fontWeight: FontWeight.w500),
    );
    return Container(
      height: 67,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: const [_softShadow],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                labelText,
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: _bodyStyle.copyWith(
                          height: 17 / 14,
                          color: _green,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
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
}

Widget _primary(String label, VoidCallback onTap) => SizedBox(
  height: 51,
  width: double.infinity,
  child: FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: _green,
      foregroundColor: Colors.white,
      padding: EdgeInsets.zero,
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
        fontFamily: 'SF Pro',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    onPressed: onTap,
    child: Text(label),
  ),
);

bool _showRepeat(TaskKind kind, TaskRepeat repeat) =>
    kind == TaskKind.period ||
    repeat.days.isNotEmpty ||
    repeat.daysOff.isNotEmpty ||
    repeat.exerciseReminders;

String _selectionLabel(String section, String exercise) {
  final exerciseTitle = taskExerciseTitle(exercise);
  return exerciseTitle.isNotEmpty ? exerciseTitle : taskSectionTitle(section);
}

class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({
    required this.isRange,
    required this.start,
    required this.end,
    required this.hour,
    required this.minute,
    this.onPickTime,
    this.onPickDate,
  });

  final bool isRange;
  final DateTime? start;
  final DateTime? end;
  final int? hour;
  final int? minute;
  final VoidCallback? onPickTime;
  final VoidCallback? onPickDate;

  @override
  Widget build(BuildContext context) {
    final showPeriod =
        isRange && (end == null || !DateUtils.isSameDay(start, end));
    final date =
        showPeriod && start != null && end != null
            ? '${_formatDate(start)} - ${_formatDate(end)}'
            : _formatDate(start);
    return Row(
      children: [
        Expanded(
          child: _Preference(
            label: 'Время',
            value: _formatTime(hour, minute),
            onTap: onPickTime,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _Preference(
            label: showPeriod ? 'Период' : 'Дата',
            value: date,
            onTap: onPickDate,
          ),
        ),
      ],
    );
  }
}

class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.value,
    this.placeholder,
    this.onTap,
  });

  final String label;
  final String value;
  final String? placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _TaskField(
    label: label,
    selector: true,
    child: _FieldValue(
      text: value.isEmpty ? (placeholder ?? '—') : value,
      placeholder: value.isEmpty,
      disclosure: onTap != null,
      onTap: onTap,
    ),
  );
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({this.task, this.duplicate = false, this.onDelete});

  final SmileTask? task;
  final bool duplicate;
  final Future<bool> Function()? onDelete;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late TaskKind? _kind = widget.task?.kind;
  late final _comment = TextEditingController(text: widget.task?.comment ?? '');
  late String _section = widget.task?.sectionRoute ?? '';
  late String _exercise = widget.task?.exerciseRoute ?? '';
  late DateTime? _start = widget.task?.startDate;
  late DateTime? _end = widget.task?.endDate;
  late TimeOfDay? _time = _taskTime(widget.task);
  late TaskRepeat _repeat = widget.task?.repeat ?? const TaskRepeat();
  bool _scheduleOpen = false;
  bool _selectionError = false;

  bool get _editing => widget.task != null && !widget.duplicate;
  bool get _isRange => _kind == TaskKind.period;

  static TimeOfDay? _taskTime(SmileTask? task) {
    final hour = task?.hour;
    final minute = task?.minute;
    return hour == null || minute == null
        ? null
        : TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _setKind(TaskKind kind) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    _comment.clear();
    setState(() {
      _kind = kind;
      _section = '';
      _exercise = '';
      _start = today;
      _end = null;
      _time = TimeOfDay.fromDateTime(now);
      _repeat = const TaskRepeat();
      _selectionError = false;
    });
  }

  Future<void> _selectExercise() async {
    FocusScope.of(context).unfocus();
    final choice = await showTaskExercisePicker(
      context,
      sectionRoute: _section,
      exerciseRoute: _exercise,
      barrierColor: Colors.transparent,
    );
    if (!mounted || choice == null) return;
    setState(() {
      _section = choice.sectionRoute;
      _exercise = choice.exerciseRoute;
      _selectionError = false;
    });
  }

  Future<void> _schedule<T>(
    Future<T?> Function() open,
    ValueChanged<T> apply,
  ) async {
    FocusScope.of(context).unfocus();
    // Keep the draft alive while the scheduling dialog replaces its surface.
    final result = open();
    setState(() => _scheduleOpen = true);
    final value = await result;
    if (!mounted) return;
    setState(() {
      _scheduleOpen = false;
      if (value != null) apply(value);
    });
  }

  Future<void> _delete() async {
    FocusScope.of(context).unfocus();
    final deletion = widget.onDelete!();
    setState(() => _scheduleOpen = true);
    final deleted = await deletion;
    if (!mounted) return;
    if (deleted) {
      Navigator.of(context).pop();
    } else {
      setState(() => _scheduleOpen = false);
    }
  }

  void _submit() {
    final previous = widget.task;
    final keepTitle =
        previous != null &&
        previous.sectionRoute == _section &&
        previous.exerciseRoute == _exercise;
    final title =
        keepTitle ? previous.title : _selectionLabel(_section, _exercise);
    if (title.isEmpty) {
      setState(() => _selectionError = true);
      return;
    }
    Navigator.of(context).pop(
      SmileTask(
        id: _editing ? previous!.id : const Uuid().v4(),
        kind: _kind!,
        title: title,
        sectionRoute: _section,
        exerciseRoute: _exercise,
        comment: _comment.text.trim(),
        startDate: _start,
        endDate: _isRange ? _end ?? _start : null,
        hour: _time?.hour,
        minute: _time?.minute,
        repeat: _repeat,
        completed: _editing && previous!.completed,
      ),
    );
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (widget.task != null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _kind = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_scheduleOpen) return const SizedBox.shrink();
    final kind = _kind;
    if (kind == null) return _CategoryChoice(onChoose: _setKind);
    final repeat = _repeat.days.isEmpty ? '' : _formatRepeat(_repeat);
    return _ModalBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: _editing ? 'Редактировать задачу' : 'Создать задачу',
            back: _back,
            trailing:
                widget.onDelete == null
                    ? null
                    : _IconButton(
                      asset: 'form_delete.svg',
                      label: 'Удалить задачу',
                      onTap: _delete,
                    ),
          ),
          const SizedBox(height: 16),
          _SelectorField(
            label: 'Раздел и упражнения',
            value: _selectionLabel(_section, _exercise),
            placeholder: 'Выбрать упражнение',
            onTap: _selectExercise,
          ),
          if (_selectionError) ...[
            const SizedBox(height: 9),
            Text(
              'Выбери раздел или упражнение',
              textAlign: TextAlign.center,
              style: _bodyStyle.copyWith(color: const Color(0xFFAC3939)),
            ),
          ],
          if (_showRepeat(kind, _repeat)) ...[
            const SizedBox(height: 9),
            _SelectorField(
              label: 'Повтор',
              value: repeat,
              placeholder: 'Установить дни повтора',
              onTap:
                  () => _schedule<TaskRepeat>(
                    () => showTaskRepeat(
                      context,
                      initialRepeat: _repeat,
                      barrierColor: Colors.transparent,
                    ),
                    (value) => _repeat = value,
                  ),
            ),
          ],
          const SizedBox(height: 9),
          _TaskTextInput(
            label: 'Комментарий',
            hint: 'Добавьте комментарий к задаче',
            controller: _comment,
          ),
          const SizedBox(height: 9),
          _ScheduleSummary(
            isRange: _isRange,
            start: _start,
            end: _end,
            hour: _time?.hour,
            minute: _time?.minute,
            onPickTime:
                () => _schedule<TimeOfDay>(
                  () => showTaskTime(
                    context,
                    initialTime: _time,
                    barrierColor: Colors.transparent,
                  ),
                  (value) => _time = value,
                ),
            onPickDate:
                () => _schedule<DateTimeRange>(
                  () => showTaskCalendar(
                    context,
                    isRange: _isRange,
                    startDate: _start,
                    endDate: _end,
                    barrierColor: Colors.transparent,
                  ),
                  (value) {
                    _start = value.start;
                    _end = _isRange ? value.end : null;
                  },
                ),
          ),
          const SizedBox(height: 16),
          _primary('Добавить', _submit),
        ],
      ),
    );
  }
}

class _TaskDetail extends StatelessWidget {
  const _TaskDetail({required this.task, required this.canOpenExercise});

  final SmileTask task;
  final bool canOpenExercise;

  @override
  Widget build(BuildContext context) {
    final selection = _selectionLabel(task.sectionRoute, task.exerciseRoute);
    void openExercise() =>
        Navigator.of(context).pop(_TaskDetailAction.openExercise);
    return _ModalBody(
      offset: const Offset(-3, -0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: 'Создать задачу',
            back: () => Navigator.of(context).pop(),
            trailing: _IconButton(
              asset: 'edit.svg',
              label: 'Редактировать задачу',
              onTap: () => Navigator.of(context).pop(_TaskDetailAction.edit),
            ),
          ),
          const SizedBox(height: 16),
          _SelectorField(
            label: 'Раздел и упражнения',
            value: selection.isEmpty ? task.title : selection,
            onTap: canOpenExercise ? openExercise : null,
          ),
          if (_showRepeat(task.kind, task.repeat)) ...[
            const SizedBox(height: 9),
            _SelectorField(label: 'Повтор', value: _formatRepeat(task.repeat)),
          ],
          const SizedBox(height: 9),
          _TaskField(
            label: 'Комментарий',
            child: _FieldValue(
              text: task.comment.isEmpty ? '—' : task.comment,
              maxLines: null,
            ),
          ),
          const SizedBox(height: 9),
          _ScheduleSummary(
            isRange: task.kind == TaskKind.period,
            start: task.startDate,
            end: task.endDate,
            hour: task.hour,
            minute: task.minute,
          ),
          const SizedBox(height: 16),
          _primary(
            'Добавить',
            () => Navigator.of(context).pop(_TaskDetailAction.duplicate),
          ),
        ],
      ),
    );
  }
}
