import 'package:flutter/material.dart';
import 'package:kurs/screens/Profile.dart';
import 'package:kurs/screens/ChatsMain.dart';

class HomeScreen extends StatefulWidget {
  final String authToken;
  const HomeScreen({super.key, required this.authToken});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _mainPageIndex = 0;
  int? _selectedChatIndex;
  late final List<Widget> _screens;
  void _handleChatSelected(int? index) {
    setState(() {
      _selectedChatIndex = index;
    });
  }
  @override
  void initState() {
    super.initState();
    _screens = [
      ChatsMain(authToken: widget.authToken, onChatSelected: _handleChatSelected),
      _buildQuotePage(),
      const Center(
          child: Text('Сторінка Відео',
              style: TextStyle(fontSize: 24, color: Color(0xFF62567E)))),
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

  Widget _buildQuotePage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: FittedBox(
          fit: BoxFit.contain,
          child: RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                color: Color(0xFF62567E),
                fontFamily: 'InstrumentSans',
                height: 3,
              ),
              children: <TextSpan>[
                TextSpan(text: '"Людина не може нічого іншого навчитися,\nокрім як переходячи від відомого до невідомого."\n\n'),
                TextSpan(text: 'Клод Бернар', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7C6BA3);
    const Color backgroundColor = Colors.white;
    const Color indicatorColor = Color(0xFF62567E);
    if (_selectedChatIndex != null) {
      return _buildChatConversationView();
    }
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
                icon: _buildNavIcon(Icons.collections_bookmark_outlined, _mainPageIndex == 1),
                selectedIcon: _buildNavIcon(Icons.collections_bookmark_rounded, true),
                label: const Text(''),
              ),
              NavigationRailDestination(
                icon: _buildNavIcon(Icons.video_call_outlined, _mainPageIndex == 2),
                selectedIcon: _buildNavIcon(Icons.video_call, true),
                label: const Text(''),
              ),
            ],
          ),
          Expanded(
            child: Stack(
              children: [
                _screens[_mainPageIndex],
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(authToken: widget.authToken),
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_circle, color: primaryColor, size: 60),
                      tooltip: 'Профіль',
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
  Widget _buildChatConversationView() {
    const Color primaryColor = Color(0xFF62567E);
    const Color bottomNavBarColor = Color(0xFF7C6BA3);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => _handleChatSelected(null),
        ),
        title: Text(
          'Юзер ${_selectedChatIndex! + 1}',
          style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: const Center(
        child: Text('Тут будуть повідомлення чату', style: TextStyle(fontSize: 18, color: Colors.grey)),
      ),
      bottomNavigationBar: Container(
        height: 60,
        color: bottomNavBarColor,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.chat_bubble_outline, color: Colors.white), onPressed: () {}),
                IconButton(icon: const Icon(Icons.bookmark_border, color: Colors.white), onPressed: () {}),
                IconButton(icon: const Icon(Icons.add_box_outlined, color: Colors.white), onPressed: () {}),
              ],
            ),
            IconButton(icon: const Icon(Icons.person_outline, color: Colors.white), onPressed: () {}),
          ],
        ),
      ),
    );
  }
}

