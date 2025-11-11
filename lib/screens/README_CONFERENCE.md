# Відеоконференції - Керівництво розробника

## Швидкий старт

### 1. Базова навігація
```dart
import 'package:kurs/utils/conference_integration.dart';

// Перейти на екран конференцій
ConferenceIntegration.navigateToConferences(
  context,
  authToken: authToken,
  courseId: courseId,
  username: 'user_name',
  courseName: 'Course Name',
);
```

### 2. Додати кнопку в AppBar
```dart
AppBar(
  actions: [
    IconButton(
      icon: Icon(Icons.videocam),
      onPressed: () => ConferenceIntegration.navigateToConferences(...),
    ),
  ],
)
```

### 3. Показати активну конференцію в чаті
```dart
if (activeConference?.isActive ?? false)
  ConferenceBanner(
    conference: activeConference!,
    onTap: () => _showDetails(),
    onJoin: () => _join(),
  )
```

## Структура файлів

```
lib/screens/
├── conference_screen.dart           ← Основний екран списку
├── conference_details_screen.dart   ← Деталі конференції
└── README_CONFERENCE.md            ← Цей файл

lib/widgets/
└── conference_widgets.dart         ← UI компоненти

lib/utils/
└── conference_integration.dart     ← Допоміжні функції

lib/classes/
└── conference_service.dart         ← API сервіс
```

## Компоненти й їхнє призначення

### ConferenceScreen
**Де:** `lib/screens/conference_screen.dart`

Основний екран для управління конференціями:
- Список всіх конференцій курсу
- Фільтрація по статусу (активна/завершена)
- Кнопка створення нової конференції
- Реал-тайм оновлення кожні 5 секунд
- Приєднання до активних конференцій

**Використання:**
```dart
ConferenceScreen(
  authToken: authToken,
  courseId: courseId,
  username: currentUsername,
  courseName: 'Курс 1',
)
```

### ConferenceDetailsScreen
**Де:** `lib/screens/conference_details_screen.dart`

Детальна інформація про конференцію:
- Інформація про конференцію
- Список учасників з ролями
- Часи приєднання/виходу
- Кнопка завершення (для модератора)

**Використання:**
```dart
ConferenceDetailsScreen(
  authToken: authToken,
  courseId: courseId,
  conference: conferenceObject,
  username: currentUsername,
)
```

### Widget компоненти
**Де:** `lib/widgets/conference_widgets.dart`

#### ConferenceCard
Карточка конференції з інформацією й кнопками:
```dart
ConferenceCard(
  conference: conference,
  onJoin: () => joinConference(),
  onDetails: () => showDetails(),
  isLoading: false,
)
```

#### ConferenceBanner
Банер активної конференції для ChatScreen:
```dart
ConferenceBanner(
  conference: activeConference,
  onTap: () => showDetails(),
  onJoin: () => joinConference(),
)
```

#### ConferenceParticipantsList
Список учасників конференції:
```dart
ConferenceParticipantsList(
  participants: conference.participants,
  showRole: true,
)
```

#### ConferenceEmptyState
Стан "без конференцій":
```dart
ConferenceEmptyState(
  message: 'Нема конференцій',
  icon: Icons.videocam_off,
  onAction: () => createConference(),
  actionLabel: 'Створити',
)
```

## API Сервіс

### ConferenceService методи

```dart
final service = ConferenceService();

// Отримати конференції
final conferences = await service.getCourseConferences(
  authToken,
  courseId,
);

// Створити конференцію
final response = await service.createConference(
  authToken,
  courseId,
  'Назва конференції',
);

// Приєднатися
final response = await service.joinConference(
  authToken,
  courseId,
  conferenceId,
);

// Деталі конференції
final conference = await service.getConferenceDetails(
  authToken,
  courseId,
  conferenceId,
);

// Учасники
final participants = await service.getConferenceParticipants(
  authToken,
  courseId,
  conferenceId,
);

// Завершити (модератор)
await service.endConference(
  authToken,
  courseId,
  conferenceId,
);
```

## Моделі даних

### Conference
```dart
Conference(
  id: 1,
  courseId: 1,
  subject: 'Лекція з Flutter',
  roomName: 'flutter_lecture_001',
  status: ConferenceStatus.ACTIVE,  // або ENDED
  createdAt: DateTime.now(),
  endedAt: null,
  participants: [...],
)
```

### ConferenceParticipant
```dart
ConferenceParticipant(
  username: 'john_doe',
  role: ConferenceRole.MODERATOR,  // або MEMBER, VIEWER
  joinedAt: DateTime.now(),
  leftAt: null,  // або час виходу
)
```

### ConferenceRole
- `MODERATOR` - повні права, може завершити
- `MEMBER` - учасник, може говорити й слухати
- `VIEWER` - спостерігач, тільки дивиться

### ConferenceStatus
- `ACTIVE` - конференція йде
- `ENDED` - конференція завершена
- `UNKNOWN` - невідомий статус

## ConferenceIntegration утиліти

**Навігація:**
```dart
ConferenceIntegration.navigateToConferences(context, ...);
ConferenceIntegration.navigateToConferenceDetails(context, ...);
```

**UI Builder:**
```dart
ConferenceIntegration.buildConferenceBannerForChat(...);
ConferenceIntegration.buildConferenceCard(...);
ConferenceIntegration.buildParticipantsList(...);
```

**Форматування:**
```dart
ConferenceIntegration.formatConferenceStatus(status);  // "Активна"
ConferenceIntegration.formatConferenceRole(role);      // "Модератор"
ConferenceIntegration.getRoleColor(role);              // Color
```

**Сповіщення:**
```dart
ConferenceIntegration.showNotification(context, message, isError: false);
```

## Extension методи

На `Conference`:
```dart
conference.isActive          // bool
conference.isEnded           // bool
conference.statusString      // String ("Активна" / "Завершена")
conference.durationMinutes   // int
```

На `ConferenceParticipant`:
```dart
participant.roleString       // String ("Модератор" / "Учасник" / "Спостерігач")
participant.isActive         // bool (у кімнаті?)
participant.durationString   // String ("5 хв")
```

## Приклади інтеграції

### Приклад 1: Кнопка в CoursesScreen
```dart
AppBar(
  title: Text(courseName),
  actions: [
    IconButton(
      icon: Icon(Icons.videocam),
      onPressed: () {
        ConferenceIntegration.navigateToConferences(
          context,
          authToken: authToken,
          courseId: courseId,
          username: username,
          courseName: courseName,
        );
      },
    ),
  ],
)
```

### Приклад 2: Вкладка конференцій
```dart
TabBar(
  tabs: [
    Tab(text: 'Матеріали'),
    Tab(text: 'Завдання'),
    Tab(icon: Icon(Icons.videocam), text: 'Конференції'),
  ],
)

// У TabBarView:
ConferenceScreen(
  authToken: authToken,
  courseId: courseId,
  username: username,
  courseName: courseName,
)
```

### Приклад 3: Банер в ChatScreen
```dart
// Завантажити активну конференцію
Conference? activeConference = ...;

// У body чату:
Column(
  children: [
    if (activeConference?.isActive ?? false)
      ConferenceBanner(
        conference: activeConference!,
        onTap: () => ConferenceIntegration.navigateToConferenceDetails(
          context,
          authToken: authToken,
          courseId: courseId,
          conference: activeConference!,
          username: username,
        ),
        onJoin: () => _joinConference(activeConference!),
      ),
    // Обнародована вміст чату
    Expanded(
      child: ChatMessages(),
    ),
  ],
)
```

## Обробка помилок

Всі помилки автоматично показуються через SnackBar:

```dart
try {
  await conferenceService.joinConference(...);
} catch (e) {
  // Автоматично показується SnackBar з помилкою
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.toString())),
  );
}
```

## Безпека

JWT токени:
1. Отримуються від сервера при приєднанні
2. Розраховується затримка через `JwtTimingCalculator`
3. Передаються Jitsi для автентифікації

## Дизайн й колори

- **Модератор:** Червоний (Colors.red)
- **Учасник:** Синій (Colors.blue)
- **Спостерігач:** Помаранчевий (Colors.orange)
- **Активна конф.:** Синій градієнт
- **Завершена конф.:** Сірий градієнт

## Тестування

1. **Unit тести:**
   ```dart
   test('Conference parsing', () {
     final json = {...};
     final conf = Conference.fromJson(json);
     expect(conf.isActive, true);
   });
   ```

2. **Widget тести:**
   ```dart
   testWidgets('Conference card shows status', (tester) async {
     await tester.pumpWidget(ConferenceCard(...));
     expect(find.text('Активна'), findsOneWidget);
   });
   ```

3. **Інтеграційні тести:**
   - Створення конференції
   - Приєднання користувача
   - Завершення конференції

## Удосконалення

Майбутні функції:
- [ ] Запис конференцій
- [ ] Скрін-шеринг
- [ ] Чат під час конференції
- [ ] Планування конференцій
- [ ] Напомни перед початком
- [ ] Експорт історії
- [ ] Аналітика (тривалість, учасники)

## Відладка

**Включити детальне логування:**
```dart
// В conference_service.dart додати:
print('API Call: GET $url');
print('Response: ${response.statusCode}');
```

**Перевірити JWT:**
```dart
final decoded = JwtTimingCalculator.calculateJwtWaitTime(jwt);
print('JWT valid, wait time: $decoded ms');
```

## Посилання

- [Jitsi Meet документація](https://jitsi.org/)
- [Flutter widgets каталог](https://flutter.dev/docs/development/ui/widgets)
- [Material Design](https://material.io/design/)

---

**Питання?** Дивіться `lib/examples/conference_integration_example.dart` для живих прикладів.
