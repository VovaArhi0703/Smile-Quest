import 'package:flutter/material.dart';

import '../game_scripts.dart';
import '../layout/adaptive_layout.dart';
import '../layout/tablet_navigation.dart';
import '../widget/tabbar.dart';
import 'exercise_sections.dart';
import 'home_page.dart';
import 'photo_diary_page.dart';
import 'profile_first.dart';

/// Keeps the main navigation bar mounted while switching between the four tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  static MainShellState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();

  static MainShellState? _active;

  static void openTab(BuildContext context, int index) {
    final shell = _active;
    final shellRoute = shell == null ? null : ModalRoute.of(shell.context);
    if (shell != null && shell.mounted && shellRoute != null) {
      Navigator.of(context).popUntil((route) => route == shellRoute);
      shell.selectTab(index);
      return;
    }
    const routes = [
      '/home',
      '/exercise_sections',
      '/photo_diary',
      '/profile_first',
    ];
    Navigator.of(context).pushNamedAndRemoveUntil(routes[index], (_) => false);
  }

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int _selectedIndex;
  final List<bool> _visited = [false, false, false, false];
  late final AppLifecycleListener _appLifecycle;

  void _registerVisit() => GamificationService().refreshLoginActivity();

  @override
  void initState() {
    super.initState();
    MainShell._active = this;
    _selectedIndex = widget.initialIndex.clamp(0, 3);
    _visited[_selectedIndex] = true;
    _appLifecycle = AppLifecycleListener(onResume: _registerVisit);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _registerVisit();
    });
  }

  @override
  void dispose() {
    _appLifecycle.dispose();
    if (identical(MainShell._active, this)) MainShell._active = null;
    super.dispose();
  }

  void selectTab(int index) {
    if (index < 0 || index >= _visited.length || index == _selectedIndex) {
      return;
    }
    setState(() {
      _selectedIndex = index;
      _visited[index] = true;
    });
    if (index == 0) _registerVisit();
  }

  @override
  Widget build(BuildContext context) {
    final content = IndexedStack(
      index: _selectedIndex,
      children: [
        if (_visited[0])
          const HomePage(embedded: true)
        else
          const SizedBox.shrink(),
        if (_visited[1])
          const ExerciseSectionsPage(embedded: true)
        else
          const SizedBox.shrink(),
        if (_visited[2])
          const PhotoDiaryPage(embedded: true)
        else
          const SizedBox.shrink(),
        if (_visited[3])
          const ProfileFirst(embedded: true)
        else
          const SizedBox.shrink(),
      ],
    );
    if (AppLayout.isTablet(context)) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        body: Row(
          children: [
            TabletNavigation(
              selectedIndex: _selectedIndex,
              onSelected: selectTab,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }
    return Scaffold(
      body: content,
      bottomNavigationBar: MainTabBar(
        selectedIndex: _selectedIndex,
        onTabSelected: selectTab,
      ),
    );
  }
}
