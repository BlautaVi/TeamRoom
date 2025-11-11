# Відеоконференції - Інструкція реалізації

## Огляд

Реалізовано повну систему відеоконференцій з кастомним GUI та інтеграцією Jitsi Meet. Система включає:

- **ConferenceScreen** - основний екран для перегляду та управління конференціями
- **ConferenceDetailsScreen** - детальна інформація про конференцію та учасників
- **Conference Widgets** - набір готових компонентів для UI
- **ConferenceIntegration** - допоміжні методи для інтеграції

## Файли

### Основні екрани
- `/lib/screens/conference_screen.dart` - основний список конференцій
- `/lib/screens/conference_details_screen.dart` - деталі конференції

### Компоненти
- `/lib/widgets/conference_widgets.dart` - переиспользуемые Widget компоненти:
  - `ConferenceCard` - карточка конференції
  - `ConferenceBanner` - банер активної конференції
  - `ConferenceParticipantsList` - список учасників
  - `ConferenceEmptyState` - стан "без конференцій"

### Утиліти
- `/lib/utils/conference_integration.dart` - допоміжні функції:
  - Навігація
  - Діалоги
  - Форматування
  - Extension методи

### Сервіс
- `/lib/classes/conference_service.dart` - API сервіс (вже існує)

## Використання

### 1. Базовна навігація

```dart
import 'package:kurs/utils/conference_integration.dart';

// Перейти на екран конференцій
ConferenceIntegration.navigateToConferences(
  context,
  authToken: authToken,
  courseId: courseId,
  username: currentUser.username,
  courseName: 'Назва курсу',
);
```

### 2. Інтеграція в CoursesScreen

```dart
// Додати кнопку в AppBar курсу
AppBar(
  actions: [
    IconButton(
      icon: Icon(Icons.videocam),
      onPressed: () => ConferenceIntegration.navigateToConferences(
        context,
        authToken: authToken,
        courseId: courseId,
        username: username,
        courseName: courseName,
      ),
    ),
  ],
)
```

### 3. Інтеграція в ChatScreen (банер активної конференції)

```dart
// На верху чата показати активну конференцію
if (activeConference != null && activeConference.status == ConferenceStatus.ACTIVE)
  ConferenceIntegration.buildConferenceBannerForChat(
    conference: activeConference,
    onTap: () => ConferenceIntegration.navigateToConferenceDetails(
      context,
      authToken: authToken,
      courseId: courseId,
      conference: activeConference,
      username: username,
    ),
    onJoin: () => _joinConference(activeConference),
  ),
```

### 4. Користувацькі Widget компоненти

```dart
// Карточка конференції
ConferenceCard(
  conference: conference,
  onJoin: () => _joinConference(conference),
  onDetails: () => _showDetails(conference),
)

// Список учасників
ConferenceParticipantsList(
  participants: conference.participants,
  showRole: true,
)

// Стан "без конференцій"
ConferenceEmptyState(
  message: 'Немає конференцій',
  icon: Icons.videocam_off,
  onAction: () => _createConference(),
  actionLabel: 'Створити',
)
```

## API Сервісу

### ConferenceService методи

```dart
// Отримати конференції курсу
Future<List<Conference>> getCourseConferences(
  String authToken,
  int courseId,
)

// Створити нову конференцію
Future<ConferenceJoinResponse> createConference(
  String authToken,
  int courseId,
  String subject,
)

// Отримати деталі конференції
Future<Conference> getConferenceDetails(
  String authToken,
  int courseId,
  int conferenceId,
)

// Приєднатися до конференції
Future<ConferenceJoinResponse> joinConference(
  String authToken,
  int courseId,
  int conferenceId,
)

// Отримати список учасників
Future<List<ConferenceParticipant>> getConferenceParticipants(
  String authToken,
  int courseId,
  int conferenceId,
)

// Завершити конференцію (тільки для модератора)
Future<void> endConference(
  String authToken,
  int courseId,
  int conferenceId,
)
```

## Моделі даних

### Conference
```dart
Conference(
  id: int,
  courseId: int,
  subject: String,
  roomName: String,
  status: ConferenceStatus (ACTIVE, ENDED, UNKNOWN),
  createdAt: DateTime,
  endedAt: DateTime?,
  participants: List<ConferenceParticipant>,
)
```

### ConferenceParticipant
```dart
ConferenceParticipant(
  username: String,
  role: ConferenceRole (MODERATOR, MEMBER, VIEWER),
  joinedAt: DateTime,
  leftAt: DateTime?,
)
```

### ConferenceRole
- `MODERATOR` - модератор (повні права)
- `MEMBER` - учасник (може говорити й слухати)
- `VIEWER` - спостерігач (тільки дивиться)

## Кольорова схема

Ролі мають свої кольори:
- Модератор: червоний (Colors.red)
- Учасник: синій (Colors.blue)
- Спостерігач: помаранчевий (Colors.orange)

## Extension методи

```dart
// На Conference
conference.isActive         // bool
conference.isEnded          // bool
conference.statusString     // String
conference.durationMinutes  // int

// На ConferenceParticipant
participant.roleString      // String
participant.isActive        // bool (не вийшов)
participant.durationString  // String
```

## Jitsi Meet інтеграція

Для запуску відеоконференції використовується різні підходи в залежності від платформи:

### На мобільних платформах (Android/iOS)
Використовується embedded Jitsi через WebView:

1. Отримується JWT токен від сервера
2. Розраховується час затримки через `JwtTimingCalculator`
3. Генерується HTML сторінка з Jitsi Meet (через `generateJitsiHtml`)
4. Сторінка відкривається в `JitsiWebViewScreen` (повноекранний WebView)
5. Користувач взаємодіє з Jitsi через веб-інтерфейс

#### WebView Екран (мобільні)

`JitsiWebViewScreen` клас - це повноекранний WebView для відображення конференції:
- Показує назву кімнати в AppBar
- Кнопка виходу в AppBar
- Автоматичне завантаження HTML контенту
- Обробка помилок завантаження
- Індикатор завантаження під час ініціалізації

#### HTML Генерація

Метод `generateJitsiHtml` в `ConferenceService`:
- Генерує готовий HTML з embedded Jitsi Meet
- Підтримує конфігурацію на основі ролі користувача (VIEWER/MODERATOR/MEMBER)
- Настроєна для повного екрана (100% width/height)
- Обробляє события (video conference left, participant joined/left)

### На Desktop платформах (Windows/macOS/Linux)
Відкривається посилання на Jitsi в системному браузері:

1. Отримується JWT токен від сервера
2. Розраховується час затримки через `JwtTimingCalculator`
3. Будується URL з токеном як параметр (`?jwt=...`)
4. URL відкривається в браузері через `url_launcher`

Це дозволяє використовувати повний браузер з усіма його можливостями та плагінами для WebRTC

## Нотатки

- Конференції автоматично оновлюються кожні 5 секунд
- Список учасників показує тільки перших 3 з можливістю бачити кількість решти
- Модератор може завершити конференцію з екрана деталей
- Всі помилки виводяться через SnackBar
- Підтримуються украї UI компоненти

## Подальші удосконалення

Можна додати:
- Запис конференції
- Скрін-шеринг
- Чат в конференції
- Планування конференції на майбутній час
- Повідомлення учасникам про початок
- Статистика конференцій
