import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../layout/adaptive_layout.dart';

typedef ExercisePickerSelection = ({String? section, String? exercise});

/// Shows the same exercise selector for photos and personal tasks.
/// Returns null on dismissal, or a pair of null fields after saving a reset.
Future<ExercisePickerSelection?> showExercisePicker(
  BuildContext context, {
  required Map<String, List<String>> sectionExercises,
  String? initialSection,
  String? initialExercise,
  Color? barrierColor,
  bool useTaskDesign = false,
}) => showModalBottomSheet<ExercisePickerSelection>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: barrierColor,
  constraints:
      AppLayout.isTablet(context) ? const BoxConstraints(maxWidth: 560) : null,
  builder:
      (context) => _ExerciseFilterSheet(
        sectionExercises: sectionExercises,
        initialSection: initialSection,
        initialExercise: initialExercise,
        useTaskDesign: useTaskDesign,
      ),
);

class _ExerciseFilterSheet extends StatefulWidget {
  const _ExerciseFilterSheet({
    required this.sectionExercises,
    required this.initialSection,
    required this.initialExercise,
    required this.useTaskDesign,
  });

  final Map<String, List<String>> sectionExercises;
  final String? initialSection;
  final String? initialExercise;
  final bool useTaskDesign;

  @override
  State<_ExerciseFilterSheet> createState() => _ExerciseFilterSheetState();
}

class _ExerciseFilterSheetState extends State<_ExerciseFilterSheet> {
  static const _kGreen = Color(0xFF81C784);
  static const _taskGreen = Color(0xFF73C877);
  static const _kText = Color(0xFF191919);

  static const String _kArrowPng = 'assets/newimage/arrow_down.png';
  static const String _kCheckOnPng = 'assets/newimage/check_on.png';
  static const String _kCheckOffPng = 'assets/newimage/check_off.png';

  late String? _tempSection;
  late String? _tempExercise;

  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    _tempSection = widget.initialSection;
    _tempExercise = widget.initialExercise;
    if (_tempSection != null) _expanded.add(_tempSection!);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _tempSection = null;
      _tempExercise = null;
      _searchCtrl.clear();
      _expanded.clear();
    });
  }

  void _apply() {
    Navigator.pop(context, (section: _tempSection, exercise: _tempExercise));
  }

  void _toggleExpand(String section) {
    setState(() {
      if (_expanded.contains(section)) {
        _expanded.remove(section);
      } else {
        _expanded.add(section);
      }
    });
  }

  bool _sectionChecked(String section) => _tempSection == section;

  Widget _checkIcon(bool checked) {
    if (widget.useTaskDesign) {
      return SizedBox.square(
        dimension: 24,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 18.182,
              height: 18.182,
              decoration: BoxDecoration(
                color: checked ? _taskGreen : Colors.white,
                border: Border.all(color: _taskGreen, width: 1.455),
                borderRadius: BorderRadius.circular(3.636),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 2.909),
                ],
              ),
            ),
            if (checked)
              Positioned(
                width: 29.8182,
                height: 29.8182,
                child: SvgPicture.asset('assets/tasks/done.svg'),
              ),
          ],
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 5.8)],
      ),
      child: Image.asset(
        checked ? _kCheckOnPng : _kCheckOffPng,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _arrowIcon({required bool expanded}) {
    if (widget.useTaskDesign) {
      return RotatedBox(
        quarterTurns: expanded ? 3 : 1,
        child: SvgPicture.asset('assets/tasks/form_dropdown.svg'),
      );
    }
    return Transform.rotate(
      angle: expanded ? 3.1415926535 : 0,
      child: Image.asset(
        _kArrowPng,
        width: 16,
        height: 16,
        fit: BoxFit.contain,
      ),
    );
  }

  Map<String, List<String>> _filteredMap(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return widget.sectionExercises;

    final Map<String, List<String>> out = {};
    widget.sectionExercises.forEach((section, exercises) {
      final secMatch = section.toLowerCase().contains(query);
      final matchedExercises =
          exercises.where((e) => e.toLowerCase().contains(query)).toList();

      if (secMatch) {
        out[section] = exercises;
      } else if (matchedExercises.isNotEmpty) {
        out[section] = matchedExercises;
      }
    });

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final q = _searchCtrl.text;
    final filtered = _filteredMap(q);
    final autoExpand = q.trim().isNotEmpty;
    final useTaskDesign = widget.useTaskDesign;
    final actionColor = useTaskDesign ? _taskGreen : _kGreen;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        key: const ValueKey('exercise-picker-content'),
        height:
            AppLayout.isTablet(context)
                ? (MediaQuery.sizeOf(context).height - bottomInset - 40).clamp(
                  280.0,
                  720.0,
                )
                : 542,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 5,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCCCCC),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: useTaskDesign ? 0 : 16, bottom: 50),
              child: Column(
                children: [
                  SizedBox(
                    height: 47,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 0, 10),
                          child: TextButton(
                            onPressed: _reset,
                            style: TextButton.styleFrom(
                              foregroundColor: actionColor,
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Сбросить',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w400,
                                fontSize: 16,
                                height: 21 / 16,
                                letterSpacing: -0.401119,
                                color: actionColor,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 16, 16, 10),
                          child: TextButton(
                            onPressed: _apply,
                            style: TextButton.styleFrom(
                              foregroundColor: actionColor,
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Сохранить',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                height: 21 / 16,
                                letterSpacing: -0.401119,
                                color: actionColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 37,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x1F787880),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 20,
                            color: Color(0x993C3C43),
                          ),
                          SizedBox(width: useTaskDesign ? 3.32 : 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: 'Введите текст',
                                hintStyle: TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 15.8582,
                                  height: 21 / 15.8582,
                                  letterSpacing: -0.401119,
                                  color: Color(0x993C3C43),
                                ),
                              ),
                              style: const TextStyle(
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w400,
                                fontSize: 15.8582,
                                height: 21 / 15.8582,
                                letterSpacing: -0.401119,
                                color: _kText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: useTaskDesign ? double.infinity : 343,
                        child: SingleChildScrollView(
                          padding:
                              useTaskDesign
                                  ? const EdgeInsets.symmetric(horizontal: 16)
                                  : EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                filtered.entries.map((entry) {
                                  final section = entry.key;
                                  final exercises = entry.value;

                                  final expanded =
                                      autoExpand
                                          ? true
                                          : _expanded.contains(section);
                                  final sectionChecked = _sectionChecked(
                                    section,
                                  );

                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          useTaskDesign &&
                                                  section == filtered.keys.last
                                              ? 0
                                              : 16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 24,
                                          child: Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    if (sectionChecked) {
                                                      _tempSection = null;
                                                      _tempExercise = null;
                                                    } else {
                                                      _tempSection = section;
                                                      _tempExercise = null;
                                                      _expanded.add(section);
                                                    }
                                                  });
                                                },
                                                child: _checkIcon(
                                                  sectionChecked,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: GestureDetector(
                                                  behavior:
                                                      HitTestBehavior
                                                          .translucent,
                                                  onTap:
                                                      () => _toggleExpand(
                                                        section,
                                                      ),
                                                  child: Text(
                                                    section,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontFamily: 'SF Pro',
                                                      fontWeight:
                                                          useTaskDesign
                                                              ? FontWeight.w500
                                                              : FontWeight.w600,
                                                      fontSize: 16,
                                                      height: 19 / 16,
                                                      color: _kText,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap:
                                                    () =>
                                                        _toggleExpand(section),
                                                child: _arrowIcon(
                                                  expanded: expanded,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (expanded) ...[
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            child: Column(
                                              children:
                                                  exercises.map((ex) {
                                                    final exChecked =
                                                        _tempSection ==
                                                            section &&
                                                        _tempExercise == ex;

                                                    return Padding(
                                                      padding: EdgeInsets.only(
                                                        bottom:
                                                            useTaskDesign &&
                                                                    ex ==
                                                                        exercises
                                                                            .last
                                                                ? 0
                                                                : 8,
                                                      ),
                                                      child: SizedBox(
                                                        height: 24,
                                                        child: Row(
                                                          children: [
                                                            GestureDetector(
                                                              onTap: () {
                                                                setState(() {
                                                                  if (exChecked) {
                                                                    _tempSection =
                                                                        null;
                                                                    _tempExercise =
                                                                        null;
                                                                  } else {
                                                                    _tempSection =
                                                                        section;
                                                                    _tempExercise =
                                                                        ex;
                                                                  }
                                                                });
                                                              },
                                                              child: _checkIcon(
                                                                exChecked,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: GestureDetector(
                                                                behavior:
                                                                    HitTestBehavior
                                                                        .translucent,
                                                                onTap: () {
                                                                  setState(() {
                                                                    if (exChecked) {
                                                                      _tempSection =
                                                                          null;
                                                                      _tempExercise =
                                                                          null;
                                                                    } else {
                                                                      _tempSection =
                                                                          section;
                                                                      _tempExercise =
                                                                          ex;
                                                                    }
                                                                  });
                                                                },
                                                                child: Text(
                                                                  ex,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: const TextStyle(
                                                                    fontFamily:
                                                                        'SF Pro Display',
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w400,
                                                                    fontSize:
                                                                        16,
                                                                    height: 1.2,
                                                                    color:
                                                                        _kText,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
