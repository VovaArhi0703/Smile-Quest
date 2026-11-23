import 'package:flutter/material.dart';
import '../layout/adaptive_layout.dart';

class AvatarSettingsPage extends StatefulWidget {
  @override
  _AvatarSettingsPageState createState() => _AvatarSettingsPageState();
}

class _AvatarSettingsPageState extends State<AvatarSettingsPage> {
  final List<String> avatarImages = [
    'assets/image/cat.png',
    'assets/image/dog.png',
    'assets/image/hamster.png',
    'assets/image/rabbit.png',
    'assets/image/giraffe.png',
    'assets/image/bear.png',
    'assets/image/penguin.png',
    'assets/image/capybara.png',
    'assets/image/raccoon.png',
  ];

  int selectedAvatarIndex = 0;

  List<bool> avatarUnlocked = [
    true, // cat.png
    false, // dog.png
    false, // hamster.png
    false, // rabbit.png
    true, // giraffe.png
    false, // bear.png
    false, // penguin.png
    true, // capybara.png
    false, // raccoon.png
  ];

  @override
  Widget build(BuildContext context) {
    if (AppLayout.isTablet(context)) return _buildTablet();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Настройки аватара',
                    style: TextStyle(
                      fontSize: 20, // уменьшен размер
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          avatarImages[selectedAvatarIndex],
                        );
                      },
                      child: Text(
                        'Сохранить',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(),

            // Большая карточка аватара
            Container(
              margin: const EdgeInsets.all(16.0),
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.amberAccent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  alignment: Alignment.topCenter,
                  child: Image.asset(
                    avatarImages[selectedAvatarIndex],
                    fit: BoxFit.contain,
                    height: 200,
                  ),
                ),
              ),
            ),

            Divider(),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Открой больше персонажей за монеты!',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.lightBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemCount: avatarImages.length,
                itemBuilder: (context, index) {
                  bool isUnlocked = avatarUnlocked[index];
                  bool isSelected = selectedAvatarIndex == index;

                  return GestureDetector(
                    onTap: () {
                      if (isUnlocked) {
                        setState(() {
                          selectedAvatarIndex = index;
                        });
                      }
                    },
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  isSelected
                                      ? Border.all(
                                        color: Colors.green,
                                        width: 3,
                                      )
                                      : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Opacity(
                                    opacity: isUnlocked ? 1.0 : 0.4,
                                    child: Image.asset(
                                      avatarImages[index],
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  if (!isUnlocked)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Icon(
                                        Icons.lock,
                                        color: Colors.grey,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '150',
                              style: TextStyle(
                                color: Colors.yellow[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Image.asset(
                              'assets/image/fish.png',
                              width: 16,
                              height: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/settings');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.orange, width: 2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      'ВЫЙТИ',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
                  title: 'Настройки аватара',
                  onBack: () => Navigator.of(context).maybePop(),
                  actions: [
                    FilledButton(
                      onPressed:
                          () => Navigator.pop(
                            context,
                            avatarImages[selectedAvatarIndex],
                          ),
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final preview = TabletCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              avatarImages[selectedAvatarIndex],
                              height: constraints.maxWidth >= 850 ? 240 : 180,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Открой больше персонажей за монеты!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      );
                      final grid = GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              mainAxisExtent: 210,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                            ),
                        itemCount: avatarImages.length,
                        itemBuilder:
                            (context, index) => Semantics(
                              label: 'Персонаж ${index + 1}',
                              selected: selectedAvatarIndex == index,
                              button: true,
                              enabled: avatarUnlocked[index],
                              child: Material(
                                color:
                                    selectedAvatarIndex == index
                                        ? const Color(0xFFECFFDE)
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap:
                                      avatarUnlocked[index]
                                          ? () => setState(
                                            () => selectedAvatarIndex = index,
                                          )
                                          : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Opacity(
                                            opacity:
                                                avatarUnlocked[index] ? 1 : 0.4,
                                            child: Image.asset(
                                              avatarImages[index],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (!avatarUnlocked[index]) ...[
                                              const Icon(
                                                Icons.lock_outline,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            const Text(
                                              '150',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            const SizedBox(width: 6),
                                            Image.asset(
                                              'assets/image/fish.png',
                                              width: 20,
                                              height: 20,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      );
                      if (constraints.maxWidth >= 850) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 320,
                              child: SingleChildScrollView(child: preview),
                            ),
                            const SizedBox(width: 24),
                            Expanded(child: grid),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          preview,
                          const SizedBox(height: 20),
                          Expanded(child: grid),
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
  );
}
