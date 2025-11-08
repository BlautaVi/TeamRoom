# Перевірка прав доступу для LEADER

## Проблема
LEADER отримує помилку "Access Denied: You do not have the required permissions" при спробі відправити відповідь на завдання.

## Що було зроблено
1. Додано логування до `CustomPermissionEvaluator` для відстеження перевірки прав
2. Створено юніт-тест для перевірки ієрархії ролей
3. Підтверджено, що `@PreAuthorize("hasPermission(#courseId, 'STUDENT')")` має дозволяти LEADER відправляти відповіді

## Перевірка в базі даних

Підключіться до вашої бази даних PostgreSQL та виконайте наступний SQL запит:

```sql
-- Перевірка ролі користувача в курсі
SELECT 
    u.username,
    c.name as course_name,
    cm.role,
    cm.created_at
FROM course_members cm
JOIN users u ON cm.user_id = u.id
JOIN courses c ON cm.course_id = c.id
WHERE u.username = 'ВАШ_USERNAME'  -- Замініть на ваш username
ORDER BY cm.created_at DESC;
```

## Що перевірити в логах backend

Після того, як ви спробуєте відправити відповідь, в логах backend буде повідомлення:
```
INFO  CustomPermissionEvaluator - Permission check: user=USERNAME, courseId=X, required=STUDENT, userRole=LEADER, result=true/false
```

Якщо `userRole` є `null` або `VIEWER`, це означає що:
- Користувач не є членом курсу
- Користувач має роль нижче ніж STUDENT

## Як виправити

### Якщо користувач не є членом курсу або має неправильну роль:

```sql
-- Видалити існуючий запис якщо є
DELETE FROM course_members 
WHERE user_id = (SELECT id FROM users WHERE username = 'ВАШ_USERNAME')
  AND course_id = COURSE_ID;

-- Додати користувача з роллю LEADER
INSERT INTO course_members (user_id, course_id, role, created_at)
SELECT 
    (SELECT id FROM users WHERE username = 'ВАШ_USERNAME'),
    COURSE_ID,  -- Замініть на ID курсу
    'LEADER',
    NOW();
```

### Або оновити існуючу роль:

```sql
UPDATE course_members
SET role = 'LEADER'
WHERE user_id = (SELECT id FROM users WHERE username = 'ВАШ_USERNAME')
  AND course_id = COURSE_ID;  -- Замініть на ID курсу
```

## Ієрархія ролей
```
OWNER (найвища)
  ↓
PROFESSOR
  ↓
LEADER ← Ваша роль (має доступ до всього що і STUDENT)
  ↓
STUDENT ← Мінімальна роль для відправки відповідей
  ↓
VIEWER (найнижча)
```

## Що далі

1. Перезапустіть backend після виконання SQL запитів
2. Перевірте логи backend при спробі відправити відповідь
3. Якщо `userRole=LEADER` і `result=true`, але все одно помилка - можливо є інша проблема
4. Надішліть скріншот логів для подальшої діагностики
