import 'package:flutter/material.dart';
import 'package:kurs/screens/Profile.dart';
import 'package:kurs/screens/ChatsMain.dart';
import 'CoursesScreen.dart';

class HomeScreen extends StatefulWidget {
  final String authToken;
  final String username;

  const HomeScreen({
    super.key,
    required this.authToken,
    required this.username,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _mainPageIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      // 0. Чати
      ChatsMain(
        authToken: widget.authToken,
        currentUsername: widget.username,
      ),
      // 1. Курси
      CoursesScreen(
        authToken: widget.authToken,
        currentUsername: widget.username,
      ),
      // 2. Відео
      const Center(
        child: Text(
          'Сторінка Відео',
          style: TextStyle(fontSize: 24, color: Color(0xFF62567E)),
        ),
      ),
    ];
  }

  Widget _buildNavIcon(IconData icon, bool isSelected) {
    const Color selectedColor = Colors.white;
    const Color unselectedColor = Color(0xFFD2CDE4);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? selectedColor : unselectedColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        color: isSelected ? selectedColor : unselectedColor,
        size: 28,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7C6BA3);
    const Color indicatorColor = Color(0xFF62567E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: _mainPageIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _mainPageIndex = index;
              });
            },
            minWidth: 100,
            backgroundColor: primaryColor,
            groupAlignment: 0.0,
            indicatorColor: indicatorColor,
            indicatorShape: const CircleBorder(),
            destinations: <NavigationRailDestination>[
              NavigationRailDestination(
                icon: _buildNavIcon(Icons.chat_bubble_outline, _mainPageIndex == 0),
                selectedIcon: _buildNavIcon(Icons.chat_bubble, true),
                label: const Text(''),
              ),
              NavigationRailDestination(
                icon: _buildNavIcon(
                    Icons.collections_bookmark_outlined, _mainPageIndex == 1),
                selectedIcon:
                _buildNavIcon(Icons.collections_bookmark_rounded, true),
                label: const Text(''),
              ),
              NavigationRailDestination(
                icon: _buildNavIcon(Icons.video_call_outlined, _mainPageIndex == 2),
                selectedIcon: _buildNavIcon(Icons.video_call, true),
                label: const Text(''),
              ),
            ],
          ),
          // --- 💡 ПОЧАТОК ВИПРАВЛЕННЯ ДИЗАЙНУ ---
          Expanded(
            child: _mainPageIndex == 0
            // Для вкладки "Чати" (індекс 0) просто показуємо екран ChatsMain.
            // Він сам керує своїм AppBar.
                ? _screens[0]
            // Для всіх інших вкладок (1 і 2) використовуємо Stack,
            // щоб показати кнопку профілю поверх.
                : Stack(
              children: [
                _screens[_mainPageIndex], // Курси або Відео
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProfileScreen(authToken: widget.authToken),
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_circle,
                          color: primaryColor, size: 60),
                      tooltip: 'Профіль',
                    ),
                  ),
                ),
              ],
            ),
          ),
          // --- 💡 КІНЕЦЬ ВИПРАВЛЕННЯ ДИЗАЙНУ ---
        ],
      ),
    );
  }
}