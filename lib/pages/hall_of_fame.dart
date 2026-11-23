import 'package:flutter/material.dart';
import '../achievement_service.dart';
import '../layout/adaptive_layout.dart';

class HallOfFamePage extends StatefulWidget {
  const HallOfFamePage({Key? key}) : super(key: key);

  @override
  State<HallOfFamePage> createState() => _HallOfFamePageState();
}

class _HallOfFamePageState extends State<HallOfFamePage> {
  final AchievementService _achievementService = AchievementService();
  List<String> _unlockedAchievements = [];

  // Список всех достижений с их id, заголовками и путями к картинкам
  final List<Map<String, dynamic>> _allAchievements = [
    {
      'id': 'novice',
      'title': 'Новичок',
      'imagePath': 'assets/image/novice.png',
      'multiline': false,
    },
    {
      'id': 'photographer',
      'title': 'Фотограф',
      'imagePath': 'assets/image/photographer.png',
      'multiline': false,
    },
    {
      'id': 'champion',
      'title': 'Серийный\nчемпион',
      'imagePath': 'assets/image/champion_gray.png',
      'multiline': true,
    },
    {
      'id': 'flame',
      'title': 'Жжёшь!',
      'imagePath': 'assets/image/flame_gray.png',
      'multiline': false,
    },
    {
      'id': 'master',
      'title': 'Мастер',
      'imagePath': 'assets/image/master_gray.png',
      'multiline': false,
    },
    {
      'id': 'zoo',
      'title': 'Повелитель\nзверей',
      'imagePath': 'assets/image/zoo_gray.png',
      'multiline': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUnlockedAchievements();
  }

  Future<void> _loadUnlockedAchievements() async {
    final unlocked = await _achievementService.getUnlockedAchievements();
    setState(() {
      _unlockedAchievements = unlocked;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (AppLayout.isTablet(context)) return _buildTablet();
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/image/fon7.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Image.asset('assets/image/zal_slavi.png', width: 300),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        _allAchievements
                            .sublist(0, 3)
                            .map(
                              (achievement) => AchievementCard(
                                title: achievement['title'],
                                imagePath: achievement['imagePath'],
                                isUnlocked: _unlockedAchievements.contains(
                                  achievement['id'],
                                ),
                                multiline: achievement['multiline'] ?? false,
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 25),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        _allAchievements
                            .sublist(3)
                            .map(
                              (achievement) => AchievementCard(
                                title: achievement['title'],
                                imagePath: achievement['imagePath'],
                                isUnlocked: _unlockedAchievements.contains(
                                  achievement['id'],
                                ),
                                multiline: achievement['multiline'] ?? false,
                              ),
                            )
                            .toList(),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Colors.amber, width: 3),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                      child: const Text(
                        'ВЫЙТИ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildTablet() => Scaffold(
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
                  title: 'Зал славы',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 320,
                          mainAxisExtent: 220,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                    itemCount: _allAchievements.length,
                    itemBuilder: (context, index) {
                      final achievement = _allAchievements[index];
                      return TabletCard(
                        child: Center(
                          child: AchievementCard(
                            title: achievement['title'],
                            imagePath: achievement['imagePath'],
                            isUnlocked: _unlockedAchievements.contains(
                              achievement['id'],
                            ),
                            multiline: achievement['multiline'] ?? false,
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
      ),
    ),
  );
}

class AchievementCard extends StatelessWidget {
  final String title;
  final String imagePath;
  final bool isUnlocked;
  final bool multiline;

  const AchievementCard({
    Key? key,
    required this.title,
    required this.imagePath,
    required this.isUnlocked,
    this.multiline = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.4,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.amber, width: 2),
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(imagePath),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isUnlocked ? Colors.orange : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
