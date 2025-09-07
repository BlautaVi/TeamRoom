import 'package:flutter/material.dart';
import 'package:kurs/screens/Profile.dart';

class HomeScreen extends StatefulWidget {
  final String authToken;
  const HomeScreen({super.key, required this.authToken});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

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
    const Color backgroundColor = Colors.white;
    const Color indicatorColor = Color(0xFF62567E);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            minWidth: 100,
            backgroundColor: primaryColor,
            groupAlignment: 0.0,
            indicatorColor: indicatorColor,
            indicatorShape: const CircleBorder(),
            destinations: <NavigationRailDestination>[
              NavigationRailDestination(
                icon: _buildNavIcon(Icons.chat_bubble_outline, false),
                selectedIcon: _buildNavIcon(Icons.chat_bubble, true),
                label: const Text(''),
              ),
              NavigationRailDestination(
                icon: _buildNavIcon(Icons.bookmark_border, false),
                selectedIcon: _buildNavIcon(Icons.bookmark, true),
                label: const Text(''),
              ),
              NavigationRailDestination(
                icon: _buildNavIcon(Icons.video_call_outlined, false),
                selectedIcon: _buildNavIcon(Icons.video_call, true),
                label: const Text(''),
              ),
            ],
          ),
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            color: Color(0xFF4A4A4A),
                            fontFamily: 'InstrumentSans',
                            height: 3,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                                text:
                                '"Людина не може нічого іншого навчитися,\nокрім як переходячи від відомого до невідомого."\n\n'),
                            TextSpan(
                              text: 'Клод Бернар',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
                      icon: const Icon(
                        Icons.account_circle,
                        color: primaryColor,
                        size: 60,
                      ),
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
}

