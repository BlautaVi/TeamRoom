import 'package:flutter/material.dart';

import '../classes/Chat.dart';
class ChatsMain extends StatefulWidget {
  final String authToken;
  const ChatsMain({super.key, required this.authToken, required void Function(int? index) onChatSelected});

  @override
  State<ChatsMain> createState() => _ChatsMainState();
}

class _ChatsMainState extends State<ChatsMain> {
  final List<Chat> _chats = [
    const Chat(name: 'Юзер', lastMessage: 'Повідомлення'),
    const Chat(name: 'Юзер', lastMessage: '********'),
    const Chat(name: 'Марія', lastMessage: 'Добре, домовились!'),
    const Chat(name: 'Робоча група', lastMessage: 'Колеги, важливе оновлення...'),
    const Chat(name: 'Техпідтримка', lastMessage: 'Ваш запит в обробці.'),
  ];

  int? _selectedChatIndex;

  Widget _buildChatListPanel() {
    const Color primaryColor = Color(0xFF62567E);
    const Color dividerColor = Color(0xFF7A6C9B);

    return Container(
      width: 300,
      color: primaryColor,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      color: primaryColor,
                    ),
                  ),
                  title: Text(
                    chat.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    chat.lastMessage,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedChatIndex = index;
                    });
                  },
                );
              },
              separatorBuilder: (context, index) => const Divider(
                color: dividerColor,
                height: 1,
                thickness: 1,
              ),
            ),
          ),
          // Кнопка "Додати новий чат"
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.bottomRight,
              child: FloatingActionButton(
                onPressed: () {
                  // Логіка для створення нового чату
                },
                backgroundColor: Colors.white,
                child: const Icon(
                  Icons.add,
                  color: primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Віджет для основного екрану чату з нижньою панеллю
  Widget _buildChatViewPanel() {
    const Color primaryColor = Color(0xFF62567E);
    const Color backgroundColor = Colors.white;
    const Color bottomNavBarColor = Color(0xFF7C6BA3);

    return Expanded(
      child: Column(
        children: [
          // Основна область для повідомлень
          Expanded(
            child: Container(
              color: backgroundColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Кнопка "Назад" для повернення до списку
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: primaryColor),
                    onPressed: () {
                      setState(() {
                        _selectedChatIndex = null;
                      });
                    },
                  ),
                  // Тут буде сам чат
                  Expanded(
                    child: Center(
                      child: Text(
                        'Повідомлення для "${_chats[_selectedChatIndex!].name}"',
                        style: const TextStyle(fontSize: 24, color: primaryColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Нижня панель інструментів
          Container(
            height: 60,
            color: bottomNavBarColor,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_border, color: Colors.white),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_box_outlined, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline, color: Colors.white),
                  onPressed: () {
                    // Можливо, перехід на профіль співрозмовника
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (_selectedChatIndex == null)
          _buildChatListPanel()
        else
          _buildChatViewPanel(),
        if (_selectedChatIndex == null)
          const Expanded(
            child: Center(
              child: Text(
                'Оберіть чат для початку спілкування',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }
}

