import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../layout/adaptive_layout.dart';

import 'task_api.dart';
import 'task_form.dart';
import 'task_store.dart';

const _green = Color(0xFF73C877);
const _dark = Color(0xFF191919);
const _muted = Color(0xFF777777);
const _red = Color(0xFFFF4D4D);
const _cardShadow = BoxShadow(
  color: Color(0x12000000),
  offset: Offset(0, 3.66),
  blurRadius: 8.97,
);

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, required this.accountId});

  final String? accountId;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late final TaskStore _store = TaskStore(
    accountId: widget.accountId,
    remote: AppTaskSyncApi.forAccount(widget.accountId),
  );
  List<SmileTask>? _tasks;
  bool _loadFailed = false;
  bool _completed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await _store.load();
      if (mounted) {
        setState(() {
          _loadFailed = false;
          _tasks = tasks;
        });
      }
      unawaited(_sync());
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _sync() async {
    if (!_store.canSync) return;
    try {
      await _store.sync();
      final tasks = await _store.load();
      if (mounted) setState(() => _tasks = tasks);
    } catch (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Не удалось синхронизировать задачи'),
            action: SnackBarAction(label: 'Повторить', onPressed: _sync),
          ),
        );
      }
    }
  }

  Future<bool> _save(
    Future<List<SmileTask>> Function() change, {
    bool? completedTab,
  }) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      final tasks = await change();
      unawaited(_sync());
      if (!mounted) return true;
      setState(() {
        _tasks = tasks;
        if (completedTab != null) _completed = completedTab;
      });
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить задачу')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _create({SmileTask? from}) async {
    if (_saving) return;
    final task =
        await (from == null
            ? showCreateTask(context)
            : showDuplicateTask(context, from));
    if (task == null || !mounted) return;
    await _save(() => _store.upsert(task), completedTab: false);
  }

  Future<void> _edit(SmileTask task) async {
    final updated = await showEditTask(
      context,
      task,
      onDelete: () => _confirmDelete(task),
    );
    if (updated == null || !mounted) return;
    await _save(() => _store.upsert(updated));
  }

  Future<void> _toggle(SmileTask task) async {
    await _save(() => _store.upsert(task.withCompleted(!task.completed)));
  }

  Future<void> _showActions(SmileTask task) async {
    final shouldToggle = await showModalBottomSheet<bool>(
      context: context,
      constraints:
          AppLayout.isTablet(context)
              ? const BoxConstraints(maxWidth: 560)
              : null,
      builder:
          (context) => SafeArea(
            child: ListTile(
              title: Text(_completionLabel(task)),
              onTap: () => Navigator.pop(context, true),
            ),
          ),
    );
    if (shouldToggle == true && mounted) await _toggle(task);
  }

  Future<bool> _confirmDelete(SmileTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => const _DeleteTaskDialog(),
    );
    if (confirmed != true || !mounted) return false;
    return _save(() => _store.delete(task.id));
  }

  void _details(SmileTask task) {
    final exerciseDestination =
        task.exerciseRoute.isNotEmpty ? task.exerciseRoute : task.sectionRoute;
    showTaskDetails(
      context,
      task,
      onEdit: () => _edit(task),
      onDuplicate: () => _create(from: task),
      onOpenExercise:
          exerciseDestination.isEmpty
              ? null
              : () => Navigator.of(context).pushNamed(exerciseDestination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    final hasTasks = tasks?.isNotEmpty ?? false;
    final visibleTasks = tasks?.where((task) => task.completed == _completed);
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppLayout.isTablet(context) ? 1100 : 500,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 30, 16, 0),
                  child: _TaskHeader(showClose: hasTasks && !_completed),
                ),
                if (hasTasks) ...[
                  const SizedBox(height: 16),
                  _TaskTabs(
                    completed: _completed,
                    onChanged: (value) => setState(() => _completed = value),
                  ),
                ],
                Expanded(
                  child: switch (tasks) {
                    null when _loadFailed => Center(
                      child: TextButton(
                        onPressed: _load,
                        child: const Text('Повторить загрузку'),
                      ),
                    ),
                    null => const Center(
                      child: CircularProgressIndicator(color: _green),
                    ),
                    [] => const _EmptyTasks(),
                    _ when AppLayout.isTablet(context) => _tabletTaskList(
                      visibleTasks!.toList(),
                    ),
                    _ => ListView(
                      padding: const EdgeInsets.fromLTRB(13, 16, 19, 16),
                      children: [
                        for (final task in visibleTasks!)
                          Padding(
                            key: ValueKey(task.id),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TaskCard(
                              task: task,
                              onTap: _saving ? null : () => _details(task),
                              onToggle: _saving ? null : () => _toggle(task),
                              onLongPress:
                                  _saving ? null : () => _showActions(task),
                            ),
                          ),
                      ],
                    ),
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: tasks == null || _saving ? null : _create,
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(51),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(64),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          height: 19 / 16,
                          letterSpacing: 0,
                        ),
                      ),
                      child: const Text('Создать задачу'),
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

  Widget _tabletTaskList(List<SmileTask> tasks) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 850 ? 2 : 1;
      final width = (constraints.maxWidth - 48 - (columns - 1) * 20) / columns;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            for (final task in tasks)
              SizedBox(
                key: ValueKey(task.id),
                width: width,
                child: _TaskCard(
                  task: task,
                  onTap: _saving ? null : () => _details(task),
                  onToggle: _saving ? null : () => _toggle(task),
                  onLongPress: _saving ? null : () => _showActions(task),
                ),
              ),
          ],
        ),
      );
    },
  );
}

String _completionLabel(SmileTask task) =>
    task.completed ? 'Вернуть в активные' : 'Отметить выполненной';

class _DeleteTaskDialog extends StatelessWidget {
  const _DeleteTaskDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: SizedBox(
        width: 343,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _HeaderButton(
                    asset: 'back.svg',
                    label: 'Назад',
                    onTap: () => Navigator.pop(context, false),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Text(
                      'Удалить задачу?',
                      style: TextStyle(
                        color: _dark,
                        fontFamily: 'SF Pro Display',
                        fontSize: 18,
                        height: 21 / 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 301),
                child: Row(
                  children: [
                    Expanded(child: _button(context, confirm: false)),
                    const SizedBox(width: 8),
                    Expanded(child: _button(context, confirm: true)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(BuildContext context, {required bool confirm}) => FilledButton(
    onPressed: () => Navigator.pop(context, confirm),
    style: FilledButton.styleFrom(
      backgroundColor: confirm ? _red : const Color(0xFFC9C9C9),
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(43),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(
        fontFamily: 'SF Pro',
        fontSize: 16,
        height: 19 / 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    ),
    child: Text(confirm ? 'Удалить' : 'Отмена', textAlign: TextAlign.center),
  );
}

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({required this.showClose});

  final bool showClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderButton(asset: 'back.svg', label: 'Назад'),
        const Expanded(
          child: Text(
            'Ваши задачи',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _dark,
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w500,
              fontSize: 18,
              height: 21 / 18,
            ),
          ),
        ),
        if (showClose)
          _HeaderButton(asset: 'close.svg', label: 'Закрыть')
        else
          const SizedBox(width: 34),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.asset, required this.label, this.onTap});

  final String asset;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.364),
      side: const BorderSide(color: Color(0xFFF3F3F3)),
    );
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap ?? () => Navigator.maybePop(context),
          child: SizedBox.square(
            dimension: 34,
            child: Center(child: _TaskSvg(asset, width: 18, height: 18)),
          ),
        ),
      ),
    );
  }
}

class _TaskTabs extends StatelessWidget {
  const _TaskTabs({required this.completed, required this.onChanged});

  final bool completed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 205,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFFFD),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          for (final value in [false, true])
            Expanded(
              child: Semantics(
                button: true,
                selected: completed == value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: completed == value ? Colors.white : null,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow:
                        completed == value
                            ? const [
                              BoxShadow(
                                color: Color(0x14000000),
                                offset: Offset(0, 2),
                                blurRadius: 5.7,
                              ),
                            ]
                            : null,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onChanged(value),
                      child: Center(
                        child: Text(
                          value ? 'Выполненные' : 'Активные',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            height: 1.5,
                            letterSpacing: -0.08,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final top = (constraints.maxHeight - 444).clamp(0.0, 84.0);
          return Padding(
            padding: EdgeInsets.only(top: top),
            child: const Align(
              alignment: Alignment.topCenter,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 343,
                  height: 444,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -6 + (170.42 - 132.091) / 2 - 30,
                        top: 134 + (204.024 - 177.815) / 2 - 22,
                        width: 192.091,
                        height: 237.815,
                        child: _EmptyPaper(),
                      ),
                      Positioned(
                        left: 108,
                        top: 74,
                        width: 188,
                        height: 282,
                        child: _EmptyFrog(),
                      ),
                      Positioned(left: 79, top: 0, child: _EmptyMessage()),
                      Positioned(
                        top: 423,
                        left: 0,
                        right: 0,
                        child: Text(
                          'У Вас пока нет задач!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            fontFamily: 'SF Pro Display',
                            fontWeight: FontWeight.w500,
                            fontSize: 18,
                            height: 21 / 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyPaper extends StatelessWidget {
  const _EmptyPaper();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      alignment: const Alignment(0, -16 / 237.815),
      angle: -0.238935,
      child: Stack(
        children: [
          Positioned(
            left: 30,
            top: 22,
            width: 132.091,
            height: 177.815,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFE),
                borderRadius: BorderRadius.circular(7.97661),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    offset: Offset(0, 8),
                    blurRadius: 30,
                  ),
                ],
              ),
            ),
          ),
          const Positioned.fill(child: _TaskSvg('empty_paper.svg')),
        ],
      ),
    );
  }
}

class _EmptyFrog extends StatelessWidget {
  const _EmptyFrog();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -15.34,
            top: -23.63,
            width: 219.04,
            height: 328.70,
            child: Image.asset('assets/tasks/empty_frog.png', fit: BoxFit.fill),
          ),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 232,
      height: 80,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x176D6D6D),
                  blurRadius: 23.3,
                  offset: Offset(0, 9),
                ),
              ],
            ),
            child: const Text(
              'Давай скорее\nсоздадим задачу',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _dark,
                fontFamily: 'SF Pro Rounded',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                height: 21 / 18,
              ),
            ),
          ),
          const Positioned(
            top: 64,
            child: RotatedBox(
              quarterTurns: 2,
              child: _TaskSvg('bubble_tail.svg', width: 17.8624, height: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onLongPress,
  });

  final SmileTask task;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;

  String _date(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final section = taskSectionTitle(task.sectionRoute);
    final exercise = taskExerciseTitle(task.exerciseRoute);
    final start = task.startDate;
    final end = task.endDate;
    final activeDay = !task.completed && task.kind != TaskKind.period;
    final date =
        start == null
            ? ''
            : end == null || DateUtils.isSameDay(start, end)
            ? _date(start)
            : '${_date(start)}-${_date(end)}';
    final radius = BorderRadius.circular(26);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [_cardShadow],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          color: task.completed ? _dark : _green,
                          fontFamily: 'SF Pro Display',
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          height: 19 / 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _TaskStatus(task: task, date: date, onTap: onToggle),
                  ],
                ),
                if (section.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    section,
                    style: const TextStyle(
                      color: _dark,
                      fontFamily: 'SF Pro Display',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 17 / 14,
                    ),
                  ),
                ],
                if (exercise.isNotEmpty && exercise != task.title) ...[
                  const SizedBox(height: 4),
                  Text(
                    exercise,
                    style: TextStyle(
                      color: activeDay ? _dark : _muted,
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                ],
                if (task.comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  if (activeDay)
                    const SizedBox(
                      height: 1,
                      child: ColoredBox(color: Color(0x14000000)),
                    )
                  else
                    const _TaskSvg(
                      'card_divider.svg',
                      height: 1,
                      fit: BoxFit.fill,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    task.comment,
                    style: TextStyle(
                      color: activeDay ? _muted : const Color(0xFFC9C9C9),
                      fontFamily: 'SF Pro',
                      fontSize: 12,
                      height: 14 / 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskStatus extends StatelessWidget {
  const _TaskStatus({
    required this.task,
    required this.date,
    required this.onTap,
  });

  final SmileTask task;
  final String date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final button = Tooltip(
      message: _completionLabel(task),
      child: Semantics(
        button: true,
        checked: task.completed,
        child: InkResponse(
          key: ValueKey('task-complete-${task.id}'),
          radius: 20,
          onTap: onTap,
          child: SizedBox.square(
            dimension: 24,
            child:
                task.completed
                    ? const OverflowBox(
                      maxWidth: 29.82,
                      maxHeight: 29.82,
                      child: _TaskSvg('done.svg', width: 29.82, height: 29.82),
                    )
                    : const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x3373C877),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _TaskSvg(
                          'list_alarm.svg',
                          width: 16,
                          height: 16,
                        ),
                      ),
                    ),
          ),
        ),
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 124),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (date.isNotEmpty) ...[
            Flexible(
              child: Text(
                date,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 17 / 14,
                  color: task.completed ? _dark : _green,
                ),
              ),
            ),
            const SizedBox(width: 1),
          ],
          button,
        ],
      ),
    );
  }
}

class _TaskSvg extends StatelessWidget {
  const _TaskSvg(
    this.file, {
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String file;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/tasks/$file',
      width: width,
      height: height,
      fit: fit,
      excludeFromSemantics: true,
    );
  }
}
