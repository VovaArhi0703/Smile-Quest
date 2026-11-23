import 'package:flutter/material.dart';

class TabletNavigation extends StatelessWidget {
  const TabletNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['Главная', 'Упражнения', 'Фото-Дневник', 'Профиль'];
    const icons = ['home', 'exercise', 'diary', 'profile'];
    return Material(
      color: Colors.white,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 112,
          child: Column(
            children: [
              const SizedBox(height: 24),
              Image.asset('assets/newimage/frog1.png', height: 72),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: labels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final selected = selectedIndex == index;
                    return Semantics(
                      selected: selected,
                      button: true,
                      child: InkWell(
                        key: ValueKey('tablet-tab-$index'),
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => onSelected(index),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color:
                                selected
                                    ? const Color(0xFFECFFDE)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/newimage/${icons[index]}${selected ? '_green' : ''}.png',
                                width: 28,
                                height: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                labels[index],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      selected
                                          ? const Color(0xFF427C47)
                                          : const Color(0xFF777777),
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
    );
  }
}
