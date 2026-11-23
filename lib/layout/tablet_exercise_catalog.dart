import 'package:flutter/material.dart';

import 'adaptive_layout.dart';

typedef TabletExercise = ({int number, String title});

/// The same catalogue and selection callbacks as the phone map, laid out as
/// cards with a persistent selection panel on wide tablets.
class TabletExerciseCatalog extends StatelessWidget {
  const TabletExerciseCatalog({
    super.key,
    required this.title,
    required this.exercises,
    required this.selectedNumber,
    required this.onSelect,
    required this.onStart,
    required this.navigation,
  });

  final String title;
  final List<TabletExercise> exercises;
  final int? selectedNumber;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final Widget navigation;

  Widget _selection(BuildContext context) {
    final selected = exercises.where((e) => e.number == selectedNumber);
    final exercise = selected.firstOrNull;
    return TabletCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset('assets/newimage/frog1.png', height: 120),
          const SizedBox(height: 20),
          Text(
            exercise == null
                ? 'Выбери упражнение'
                : 'Упражнение № ${exercise.number}',
            style: const TextStyle(fontSize: 16, color: Color(0xFF777777)),
          ),
          const SizedBox(height: 10),
          Text(
            exercise?.title ?? 'Нажми на карточку, чтобы открыть инструкцию.',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: exercise == null ? null : onStart,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF81C784),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Начать'),
          ),
        ],
      ),
    );
  }

  Widget _grid() => GridView.builder(
    key: const PageStorageKey('tablet-exercise-grid'),
    padding: const EdgeInsets.only(bottom: 24),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 280,
      mainAxisExtent: 190,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
    ),
    itemCount: exercises.length,
    itemBuilder: (context, index) {
      final exercise = exercises[index];
      final selected = exercise.number == selectedNumber;
      return Semantics(
        selected: selected,
        child: Material(
          color: selected ? const Color(0xFFECFFDE) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color:
                  selected ? const Color(0xFF81C784) : const Color(0xFFF0F0F0),
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            key: ValueKey('tablet-exercise-${exercise.number}'),
            borderRadius: BorderRadius.circular(24),
            onTap: () => onSelect(exercise.number),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset('assets/exercise/exercise_btn.png'),
                        Text(
                          '${exercise.number}',
                          style: const TextStyle(
                            fontSize: 26,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: Text(
                        exercise.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.25),
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
  );

  @override
  Widget build(BuildContext context) => Scaffold(
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
                TabletHeader(
                  title: title,
                  subtitle: '${exercises.length} упражнений',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 850) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _grid()),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: 300,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: _selection(context),
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Expanded(child: _grid()),
                          if (selectedNumber != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: FilledButton(
                                onPressed: onStart,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF81C784),
                                  minimumSize: const Size.fromHeight(52),
                                ),
                                child: Text(
                                  'Начать упражнение № $selectedNumber',
                                ),
                              ),
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
    bottomNavigationBar: navigation,
  );
}
